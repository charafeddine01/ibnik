import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/signaling_message.dart';
import 'webrtc_service.dart';

class FirestoreSignalingService {
  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot>? _callSubscription;
  StreamSubscription<QuerySnapshot>? _candidateSubscription;
  Timer? _retryTimer;
  String? _currentCallId;
  bool _hasReceivedOffer = false;
  bool _isHandlingCall = false;

  DocumentReference _callRef(String callId) => _firestore.collection('calls').doc(callId);

  CollectionReference _babyCandidatesRef(String callId) =>
      _callRef(callId).collection('babyCandidates');

  CollectionReference _parentCandidatesRef(String callId) =>
      _callRef(callId).collection('parentCandidates');

  /// Starts listening as the Baby Unit for incoming connection calls from the Parent Unit.
  Future<void> listenForParentCalls({
    required String callId,
    required WebRTCService webrtcService,
    required VoidCallback onConnected,
    required VoidCallback onDisconnected,
  }) async {
    _currentCallId = callId;
    _isHandlingCall = false;

    // Check if Parent has already initiated a call before wiping state
    try {
      final doc = await _callRef(callId).get().timeout(const Duration(seconds: 3));
      final status = (doc.data() as Map<String, dynamic>?)?['status'];
      if (status != 'calling') {
        await cleanCall(callId);
        await _callRef(callId).set({
          'status': 'idle',
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      }
    } catch (_) {
      try {
        await _callRef(callId).set({
          'status': 'idle',
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
      } catch (_) {}
    }

    await _callSubscription?.cancel();
    _callSubscription = _callRef(callId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final status = data['status'] as String? ?? 'idle';

      // 1. Parent is initiating a connection call
      if (status == 'calling') {
        if (_isHandlingCall) {
          debugPrint('FirestoreSignaling: Already processing call, ignoring ping');
          return;
        }
        _isHandlingCall = true;
        debugPrint('FirestoreSignaling: Parent is calling! Generating WebRTC offer...');

        // Ensure camera & mic are opened BEFORE creating PeerConnection so tracks are added
        if (webrtcService.localStream == null) {
          await webrtcService.openUserMedia(isBabyUnit: true);
        }

        // Setup candidate sending callback from WebRTC to Firestore
        webrtcService.onSignalingMessage = (msg) async {
          if (msg.type == 'candidate' && msg.payload != null) {
            try {
              await _babyCandidatesRef(callId).add({
                'candidate': msg.payload!['candidate'],
                'sdpMid': msg.payload!['sdpMid'],
                'sdpMLineIndex': msg.payload!['sdpMLineIndex'],
                'created_at': FieldValue.serverTimestamp(),
              });
            } catch (e) {
              debugPrint('Error sending baby candidate: $e');
            }
          }
        };

        // Create PeerConnection & send offer
        await webrtcService.createPeerConnectionInstance(
          roomId: callId,
          myPeerId: 'baby',
          targetPeerId: 'parent',
          isBabyUnit: true,
        );

        // Listen for candidates from parent
        await _candidateSubscription?.cancel();
        _candidateSubscription = _parentCandidatesRef(callId).snapshots().listen((candSnap) {
          for (final change in candSnap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final candData = change.doc.data() as Map<String, dynamic>? ?? {};
              unawaited(webrtcService.addCandidate(SignalingMessage(
                type: 'candidate',
                roomId: callId,
                senderId: 'parent',
                payload: candData,
              )));
            }
          }
        }, onError: (Object e) => debugPrint('Error in parent candidates stream: $e'));

        final RTCSessionDescription offer = await webrtcService.createAndSendOfferRaw();

        try {
          await _callRef(callId).update({
            'status': 'offered',
            'offer': {'sdp': offer.sdp, 'type': offer.type},
          });
        } catch (e) {
          debugPrint('Error writing offer: $e');
        }
      }

      // 2. Parent has answered the offer
      if (status == 'answered' && data.containsKey('answer')) {
        debugPrint('FirestoreSignaling: Received answer from Parent! Completing handshake...');
        final answerData = data['answer'] as Map<String, dynamic>;
        await webrtcService.handleAnswer(SignalingMessage(
          type: 'answer',
          roomId: callId,
          senderId: 'parent',
          payload: answerData,
        ));
        onConnected();
      }

      // 3. Call ended or reset to idle
      if (status == 'ended' || status == 'idle') {
        _isHandlingCall = false;
        if (status == 'ended') {
          onDisconnected();
        }
      }
    }, onError: (Object e) => debugPrint('Error in call listener: $e'));
  }

  /// Initiates a connection call from the Parent Unit to the Baby Unit.
  Future<void> callBabyUnit({
    required String callId,
    required WebRTCService webrtcService,
    required void Function(String status) onStatusChanged,
    required VoidCallback onConnected,
    required VoidCallback onDisconnected,
  }) async {
    _currentCallId = callId;
    _hasReceivedOffer = false;
    onStatusChanged('Requesting stream from Baby Unit...');

    // Clean old candidate subcollections
    await cleanCall(callId);

    // Setup candidate sending callback from Parent to Firestore
    webrtcService.onSignalingMessage = (msg) async {
      if (msg.type == 'candidate' && msg.payload != null) {
        try {
          await _parentCandidatesRef(callId).add({
            'candidate': msg.payload!['candidate'],
            'sdpMid': msg.payload!['sdpMid'],
            'sdpMLineIndex': msg.payload!['sdpMLineIndex'],
            'created_at': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error sending parent candidate: $e');
        }
      }
    };

    // Initialize Parent PeerConnection
    await webrtcService.createPeerConnectionInstance(
      roomId: callId,
      myPeerId: 'parent',
      targetPeerId: 'baby',
      isBabyUnit: false,
    );

    // Write "calling" status into call document (with 4-second timeout)
    try {
      await _callRef(callId).set({
        'status': 'calling',
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Firestore set call error: $e');
      rethrow;
    }

    // Periodic heartbeat to re-assert "calling" status until Baby Unit responds
    _retryTimer?.cancel();
    int retryCount = 0;
    _retryTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_hasReceivedOffer || _currentCallId != callId) {
        timer.cancel();
        return;
      }
      retryCount++;
      if (retryCount == 3) {
        onStatusChanged('Waiting for Baby Unit to respond... (Waking camera)');
      } else if (retryCount == 6) {
        onStatusChanged('Baby camera is not answering yet. Ensure Baby Unit is running & connected.');
      }
      try {
        final currentSnap = await _callRef(callId).get();
        if (!currentSnap.exists) return;
        final curData = currentSnap.data() as Map<String, dynamic>?;
        final curStatus = curData?['status'] as String?;
        if (curStatus != 'calling') {
          // Status has moved to offered or answered or ended! Do not overwrite!
          if (curStatus == 'offered' || curStatus == 'answered') {
            _hasReceivedOffer = true;
            timer.cancel();
          }
          return;
        }
        await _callRef(callId).update({
          'ping': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    });

    // Listen for Offer from Baby Unit
    await _callSubscription?.cancel();
    _callSubscription = _callRef(callId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final status = data['status'] as String? ?? 'idle';

      if (status == 'offered' && data.containsKey('offer')) {
        _hasReceivedOffer = true;
        _retryTimer?.cancel();
        onStatusChanged('Negotiating secure stream with Baby Unit...');
        final offerData = data['offer'] as Map<String, dynamic>;

        // Listen for candidates from Baby Unit
        await _candidateSubscription?.cancel();
        _candidateSubscription = _babyCandidatesRef(callId).snapshots().listen((candSnap) {
          for (final change in candSnap.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final candData = change.doc.data() as Map<String, dynamic>? ?? {};
              unawaited(webrtcService.addCandidate(SignalingMessage(
                type: 'candidate',
                roomId: callId,
                senderId: 'baby',
                payload: candData,
              )));
            }
          }
        }, onError: (Object e) => debugPrint('Error in baby candidates stream: $e'));

        // Answer Offer
        final answer = await webrtcService.handleOfferAndReturnAnswer(
          offerMsg: SignalingMessage(
            type: 'offer',
            roomId: callId,
            senderId: 'baby',
            payload: offerData,
          ),
          myPeerId: 'parent',
        );

        // Write Answer to Firestore
        try {
          await _callRef(callId).update({
            'status': 'answered',
            'answer': {'sdp': answer.sdp, 'type': answer.type},
          });
        } catch (e) {
          debugPrint('Error updating answer: $e');
        }

        onStatusChanged('Connecting peer-to-peer WebRTC stream...');
        onConnected();
      }

      if (status == 'ended') {
        _retryTimer?.cancel();
        onDisconnected();
      }
    }, onError: (Object e) => debugPrint('Error in parent call listener: $e'));
  }

  /// Ends the active call and updates status to ended.
  Future<void> endCall(String? callId) async {
    _retryTimer?.cancel();
    final id = callId ?? _currentCallId;
    if (id != null) {
      try {
        await _callRef(id).update({'status': 'ended'});
      } catch (_) {}
    }
    await dispose();
  }

  /// Cleans candidate subcollections for a fresh call.
  Future<void> cleanCall(String callId) async {
    try {
      final babyCands = await _babyCandidatesRef(callId).get();
      for (final doc in babyCands.docs) {
        await doc.reference.delete();
      }
      final parentCands = await _parentCandidatesRef(callId).get();
      for (final doc in parentCands.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint('Error cleaning call candidates: $e');
    }
  }

  Future<void> dispose() async {
    _retryTimer?.cancel();
    _retryTimer = null;
    await _callSubscription?.cancel();
    await _candidateSubscription?.cancel();
    _callSubscription = null;
    _candidateSubscription = null;
    _currentCallId = null;
    _isHandlingCall = false;
    _hasReceivedOffer = false;
  }
}
