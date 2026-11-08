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
  String? _currentCallId;

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
    await cleanCall(callId);

    // Initialize call document in idle state
    await _callRef(callId).set({
      'status': 'idle',
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _callSubscription = _callRef(callId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final status = data['status'] as String? ?? 'idle';

      // 1. Parent is initiating a connection call
      if (status == 'calling') {
        debugPrint('FirestoreSignaling: Parent is calling! Generating WebRTC offer...');

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
        _candidateSubscription?.cancel();
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
        });

        // Create and write Offer to Firestore
        if (webrtcService.localStream == null) {
          await webrtcService.openUserMedia(isBabyUnit: true);
        }
        final RTCSessionDescription offer = await webrtcService.createAndSendOfferRaw();

        await _callRef(callId).update({
          'status': 'offered',
          'offer': {'sdp': offer.sdp, 'type': offer.type},
        });
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

      // 3. Call ended
      if (status == 'ended') {
        onDisconnected();
      }
    });
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

    // Write "calling" status into call document
    await _callRef(callId).set({
      'status': 'calling',
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Listen for Offer from Baby Unit
    _callSubscription = _callRef(callId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final status = data['status'] as String? ?? 'idle';

      if (status == 'offered' && data.containsKey('offer')) {
        onStatusChanged('Negotiating secure WebRTC stream...');
        final offerData = data['offer'] as Map<String, dynamic>;

        // Listen for candidates from Baby Unit
        _candidateSubscription?.cancel();
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
        });

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
        await _callRef(callId).update({
          'status': 'answered',
          'answer': {'sdp': answer.sdp, 'type': answer.type},
        });

        onConnected();
      }

      if (status == 'ended') {
        onDisconnected();
      }
    });
  }

  /// Ends the active call and updates status to ended.
  Future<void> endCall(String? callId) async {
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
    await _callSubscription?.cancel();
    await _candidateSubscription?.cancel();
    _callSubscription = null;
    _candidateSubscription = null;
    _currentCallId = null;
  }
}
