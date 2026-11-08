import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../models/signaling_message.dart';

typedef OnMessageCallback = void Function(SignalingMessage message);
typedef OnTelemetryCallback = void Function(Map<String, dynamic> data);

class WebRTCService {
  RTCPeerConnection? _peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  RTCDataChannel? _dataChannel;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();

  OnMessageCallback? onSignalingMessage;
  OnTelemetryCallback? onTelemetryReceived;
  VoidCallback? onConnectionConnected;
  VoidCallback? onConnectionDisconnected;

  bool _isDisposed = false;
  bool _hasRemoteDescription = false;
  final List<RTCIceCandidate> _candidateQueue = [];

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ]
  };

  Future<void> initializeRenderers() async {
    await localRenderer.initialize();
    await remoteRenderer.initialize();
  }

  void updateIceServers(List<Map<String, dynamic>> turnServers) {
    _iceServers['iceServers'] = [
      {'urls': 'stun:stun.l.google.com:19302'},
      ...turnServers,
    ];
  }

  Future<MediaStream> openUserMedia({required bool isBabyUnit}) async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': isBabyUnit
          ? {
              'mandatory': {
                'minWidth': '1280',
                'minHeight': '720',
                'minFrameRate': '30',
              },
              'facingMode': 'environment',
              'optional': <Map<String, dynamic>>[],
            }
          : false,
    };

    localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    if (isBabyUnit) {
      localRenderer.srcObject = localStream;
    }
    return localStream!;
  }

  Future<void> createPeerConnectionInstance({
    required String roomId,
    required String myPeerId,
    required String targetPeerId,
    required bool isBabyUnit,
  }) async {
    _hasRemoteDescription = false;
    _candidateQueue.clear();

    final Map<String, dynamic> configuration = {
      ..._iceServers,
      'sdpSemantics': 'unified-plan',
      'bundlePolicy': 'max-bundle',
    };

    _peerConnection = await createPeerConnection(configuration);

    // Register ICE candidate callbacks
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate != null) {
        onSignalingMessage?.call(SignalingMessage(
          type: 'candidate',
          roomId: roomId,
          senderId: myPeerId,
          targetId: targetPeerId,
          payload: {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          },
        ));
      }
    };

    _peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
      debugPrint('WebRTC Connection state: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        onConnectionConnected?.call();
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        onConnectionDisconnected?.call();
      }
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('WebRTC ICE Connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        onConnectionConnected?.call();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateDisconnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        onConnectionDisconnected?.call();
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      debugPrint('WebRTC onTrack received: ${event.track.kind}');
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
        remoteRenderer.srcObject = remoteStream;
      }
    };

    // Add local tracks to peer connection
    if (localStream != null) {
      for (var track in localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, localStream!);
      }
    }

    if (isBabyUnit) {
      // Create DataChannel on baby unit
      final RTCDataChannelInit dcInit = RTCDataChannelInit()..ordered = true;
      _dataChannel = await _peerConnection!.createDataChannel('telemetry', dcInit);
      _setupDataChannel(_dataChannel!);
    } else {
      _peerConnection!.onDataChannel = (RTCDataChannel channel) {
        _dataChannel = channel;
        _setupDataChannel(_dataChannel!);
      };
    }
  }

  void _setupDataChannel(RTCDataChannel channel) {
    channel.onMessage = (RTCDataChannelMessage message) {
      if (message.isBinary) return;
      try {
        final decoded = jsonDecode(message.text) as Map<String, dynamic>;
        onTelemetryReceived?.call(decoded);
      } catch (e) {
        debugPrint('Failed to parse telemetry: $e');
      }
    };
  }

  void sendTelemetry(Map<String, dynamic> data) {
    if (_dataChannel != null && _dataChannel!.state == RTCDataChannelState.RTCDataChannelOpen) {
      _dataChannel!.send(RTCDataChannelMessage(jsonEncode(data)));
    }
  }

  Future<RTCSessionDescription> createAndSendOfferRaw() async {
    final RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0,
    });
    await _peerConnection!.setLocalDescription(offer);
    return offer;
  }

  Future<RTCSessionDescription> handleOfferAndReturnAnswer({
    required SignalingMessage offerMsg,
    required String myPeerId,
  }) async {
    final payload = offerMsg.payload!;
    final sdp = payload['sdp'] as String;
    final type = payload['type'] as String;

    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _hasRemoteDescription = true;
    await _drainCandidateQueue();

    final RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1,
    });
    await _peerConnection!.setLocalDescription(answer);
    return answer;
  }

  Future<void> createAndSendOffer({
    required String roomId,
    required String myPeerId,
    required String targetPeerId,
  }) async {
    if (_peerConnection == null) return;
    final RTCSessionDescription offer = await _peerConnection!.createOffer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 0, // Baby receives parent voice only
    });
    await _peerConnection!.setLocalDescription(offer);

    onSignalingMessage?.call(SignalingMessage(
      type: 'offer',
      roomId: roomId,
      senderId: myPeerId,
      targetId: targetPeerId,
      payload: {'sdp': offer.sdp, 'type': offer.type},
    ));
  }

  Future<void> handleOfferAndSendAnswer({
    required SignalingMessage offerMsg,
    required String myPeerId,
  }) async {
    if (_peerConnection == null) return;
    final payload = offerMsg.payload!;
    final sdp = payload['sdp'] as String;
    final type = payload['type'] as String;

    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _hasRemoteDescription = true;
    await _drainCandidateQueue();

    final RTCSessionDescription answer = await _peerConnection!.createAnswer({
      'offerToReceiveAudio': 1,
      'offerToReceiveVideo': 1, // Parent receives both audio and video
    });
    await _peerConnection!.setLocalDescription(answer);

    onSignalingMessage?.call(SignalingMessage(
      type: 'answer',
      roomId: offerMsg.roomId,
      senderId: myPeerId,
      targetId: offerMsg.senderId,
      payload: {'sdp': answer.sdp, 'type': answer.type},
    ));
  }

  Future<void> handleAnswer(SignalingMessage answerMsg) async {
    if (_peerConnection == null) return;
    final payload = answerMsg.payload!;
    final sdp = payload['sdp'] as String;
    final type = payload['type'] as String;

    await _peerConnection!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _hasRemoteDescription = true;
    await _drainCandidateQueue();
  }

  Future<void> addCandidate(SignalingMessage candidateMsg) async {
    final payload = candidateMsg.payload;
    if (payload == null) return;
    final candidateStr = payload['candidate'] as String?;
    if (candidateStr == null) return;
    final sdpMid = payload['sdpMid'] as String?;
    final sdpMLineIndex = payload['sdpMLineIndex'] as int?;

    final candidate = RTCIceCandidate(candidateStr, sdpMid, sdpMLineIndex);

    if (_peerConnection != null && _hasRemoteDescription) {
      await _peerConnection!.addCandidate(candidate);
    } else {
      _candidateQueue.add(candidate);
    }
  }

  Future<void> _drainCandidateQueue() async {
    if (_peerConnection != null && _hasRemoteDescription) {
      for (final candidate in _candidateQueue) {
        try {
          await _peerConnection!.addCandidate(candidate);
        } catch (e) {
          debugPrint('Error draining candidate: $e');
        }
      }
      _candidateQueue.clear();
    }
  }

  void setMicrophoneMute(bool muted) {
    if (localStream != null) {
      final audioTracks = localStream!.getAudioTracks();
      for (var track in audioTracks) {
        track.enabled = !muted;
      }
    }
  }

  Future<void> switchCamera() async {
    if (localStream != null) {
      final videoTrack = localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await Helper.switchCamera(videoTrack);
      }
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    try {
      await _dataChannel?.close();
      await localStream?.dispose();
      await remoteStream?.dispose();
      await _peerConnection?.close();
      await localRenderer.dispose();
      await remoteRenderer.dispose();
    } catch (e) {
      debugPrint('Error disposing WebRTC service: $e');
    }
  }
}
