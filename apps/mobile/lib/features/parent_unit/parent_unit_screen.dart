import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/services/webrtc_service.dart';
import '../../core/services/lullaby_service.dart';
import '../../core/services/local_p2p_client.dart';
import '../../core/services/firestore_signaling_service.dart';
import 'widgets/decibel_meter.dart';
import '../lullaby/lullaby_sheet.dart';

class ParentUnitScreen extends StatefulWidget {
  final String roomId;
  final String? deviceName;
  final bool isCloudCall;
  final String? targetIp;
  final int targetPort;

  const ParentUnitScreen({
    super.key,
    required this.roomId,
    this.deviceName,
    this.isCloudCall = false,
    this.targetIp,
    this.targetPort = 8888,
  });

  @override
  State<ParentUnitScreen> createState() => _ParentUnitScreenState();
}

class _ParentUnitScreenState extends State<ParentUnitScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final LocalP2PClient _p2pClient = LocalP2PClient();
  final FirestoreSignalingService _firestoreSignaling = FirestoreSignalingService();

  bool _isConnected = false;
  bool _isTalking = false;
  bool _isHandsFreeMic = false;
  bool _isNurseryAudioMuted = false;
  bool _isBabyCameraEnabled = true;
  bool _isBabyMicEnabled = true;
  String _statusText = 'Initializing WebRTC...';
  double _babyDb = 35.0;
  int _babyBattery = 100;
  bool _babyIsCharging = false;
  bool _babyTorchOn = false;
  bool _isLullabyPlaying = false;
  LullabyTrack? _activeTrack;

  @override
  void initState() {
    super.initState();
    _initWebRTC();
  }

  Future<void> _initWebRTC() async {
    await _webrtcService.initializeRenderers();

    // 1. Open parent microphone only (for talkback)
    await _webrtcService.openUserMedia(isBabyUnit: false);
    _webrtcService.setMicrophoneMute(true); // muted until push-to-talk is pressed

    // 2. Setup telemetry callback from baby
    _webrtcService.onTelemetryReceived = (data) {
      if (!mounted) return;
      if (data['type'] == 'telemetry' || data['type'] == 'audio_level') {
        setState(() {
          if (data.containsKey('db')) {
            _babyDb = (data['db'] as num).toDouble();
          }
          if (data.containsKey('battery_level')) {
            _babyBattery = data['battery_level'] as int;
          }
          if (data.containsKey('is_charging')) {
            _babyIsCharging = data['is_charging'] as bool;
          }
        });
      } else if (data['type'] == 'torch_state') {
        setState(() {
          _babyTorchOn = data['is_on'] as bool;
        });
      }
    };

    _webrtcService.onConnectionConnected = () {
      debugPrint('ParentUnit: WebRTC stream fully connected!');
      if (mounted) {
        setState(() {
          _isConnected = true;
          _statusText = 'Connected';
        });
      }
    };

    _webrtcService.onConnectionDisconnected = () {
      debugPrint('ParentUnit: WebRTC stream disconnected');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _statusText = 'Connection lost. Reconnecting...';
        });
      }
    };

    // Setup Local P2P Client (Direct LAN / Wi-Fi)
    _p2pClient.onDiscoveryProgress = (status) {
      if (mounted && !_isConnected) {
        setState(() => _statusText = status);
      }
    };

    _p2pClient.onConnected = () {
      debugPrint('ParentUnit: Connected to Baby Unit via local Wi-Fi');
    };

    _p2pClient.onMessageReceived = (msg) async {
      debugPrint('ParentUnit: Received local signaling message: ${msg.type}');
      if (msg.type == 'offer') {
        await _webrtcService.createPeerConnectionInstance(
          roomId: widget.roomId,
          myPeerId: 'parent',
          targetPeerId: 'baby',
          isBabyUnit: false,
        );

        _webrtcService.onSignalingMessage = (outMsg) {
          _p2pClient.sendMessage(outMsg);
        };

        await _webrtcService.handleOfferAndSendAnswer(
          offerMsg: msg,
          myPeerId: 'parent',
        );
      } else if (msg.type == 'candidate') {
        await _webrtcService.addCandidate(msg);
      }
    };

    _p2pClient.onDisconnected = () {
      if (mounted && !_isConnected) {
        setState(() {
          _isConnected = false;
          _statusText = 'Disconnected from Baby Unit';
        });
      }
    };

    // Attempt Hybrid Connection (Local Wi-Fi + Cloud Signaling concurrently)
    unawaited(_connectHybrid());
  }

  Future<void> _connectHybrid() async {
    setState(() => _statusText = 'Connecting to ${widget.deviceName ?? "Baby Unit"}...');

    // 1. Always attempt local Wi-Fi discovery & direct connection (fastest!)
    unawaited(_connectLocal());

    // 2. Concurrently attempt cloud signaling over Firestore if available
    if (widget.isCloudCall && _firestoreSignaling.isFirebaseAvailable) {
      unawaited(_connectCloud());
    }
  }

  Future<void> _connectCloud() async {
    try {
      await _firestoreSignaling.callBabyUnit(
        callId: widget.roomId,
        webrtcService: _webrtcService,
        onStatusChanged: (status) {
          if (mounted && !_isConnected) setState(() => _statusText = status);
        },
        onConnected: () {
          debugPrint('ParentUnit: Cloud WebRTC stream fully connected!');
          if (mounted) {
            setState(() {
              _isConnected = true;
              _statusText = 'Connected (Cloud)';
            });
          }
        },
        onDisconnected: () {
          debugPrint('ParentUnit: Cloud WebRTC stream disconnected');
          if (mounted) {
            setState(() {
              _isConnected = false;
              _statusText = 'Connection lost. Reconnecting...';
            });
          }
        },
      );
    } catch (e) {
      debugPrint('ParentUnit: Cloud connection notice: $e');
      if (mounted && !_isConnected) {
        final errStr = e.toString().toLowerCase();
        if (errStr.contains('permission-denied') || errStr.contains('disabled')) {
          setState(() {
            _statusText = 'Scanning local Wi-Fi for nursery camera...';
          });
        }
      }
    }
  }

  Future<void> _connectLocal() async {
    if (widget.targetIp != null && widget.targetIp!.isNotEmpty) {
      setState(() => _statusText = 'Connecting to Baby Unit at ${widget.targetIp}:${widget.targetPort}...');
      final success = await _p2pClient.connectDirect(
        ip: widget.targetIp!,
        port: widget.targetPort,
        roomId: widget.roomId,
      );
      if (!success && mounted) {
        setState(() => _statusText = 'Failed to connect to ${widget.targetIp}. Retrying auto-discovery...');
        await _p2pClient.discoverAndConnect(roomId: widget.roomId, port: widget.targetPort);
      }
    } else {
      await _p2pClient.discoverAndConnect(roomId: widget.roomId, port: widget.targetPort);
    }
  }

  void _onRetry() {
    unawaited(_connectHybrid());
  }

  void _showManualIpDialog() {
    final ipController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Enter Nursery IP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the Wi-Fi IP address shown on the Baby Unit screen (e.g. 192.168.1.15):',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ipController,
              keyboardType: TextInputType.text,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: '192.168.1.xxx',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                prefixIcon: const Icon(Icons.wifi, color: Color(0xFF818CF8)),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () {
              final ip = ipController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _statusText = 'Connecting directly to $ip...');
                unawaited(_p2pClient.connectDirect(ip: ip, port: 8888, roomId: widget.roomId));
              }
            },
            child: const Text('Connect Direct', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _onStartTalking() {
    if (_isHandsFreeMic) return;
    setState(() => _isTalking = true);
    _webrtcService.setMicrophoneMute(false);
  }

  void _onStopTalking() {
    if (_isHandsFreeMic) return;
    setState(() => _isTalking = false);
    _webrtcService.setMicrophoneMute(true);
  }

  void _toggleBabyTorch() {
    _webrtcService.sendTelemetry({'command': 'toggle_torch'});
  }

  void _flipBabyCamera() {
    _webrtcService.sendTelemetry({'command': 'flip_camera'});
  }

  void _toggleBabyCamera() {
    setState(() => _isBabyCameraEnabled = !_isBabyCameraEnabled);
    _webrtcService.sendTelemetry({
      'command': 'toggle_baby_camera',
      'enabled': _isBabyCameraEnabled,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(_isBabyCameraEnabled ? 'Nursery camera enabled' : 'Nursery camera paused (Audio only)'),
      ),
    );
  }

  void _toggleBabyMic() {
    setState(() => _isBabyMicEnabled = !_isBabyMicEnabled);
    _webrtcService.sendTelemetry({
      'command': 'toggle_baby_mic',
      'enabled': _isBabyMicEnabled,
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1500),
        content: Text(_isBabyMicEnabled ? 'Nursery microphone active' : 'Nursery microphone muted'),
      ),
    );
  }

  void _toggleNurseryAudio() {
    setState(() => _isNurseryAudioMuted = !_isNurseryAudioMuted);
    _webrtcService.setRemoteAudioMuted(_isNurseryAudioMuted);
  }

  void _toggleHandsFreeMic() {
    setState(() {
      _isHandsFreeMic = !_isHandsFreeMic;
      _isTalking = _isHandsFreeMic;
    });
    _webrtcService.setMicrophoneMute(!_isHandsFreeMic);
  }

  void _showLullabySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LullabySheet(
        isPlaying: _isLullabyPlaying,
        activeTrack: _activeTrack,
        onPlayTrack: (LullabyTrack track, int timerMinutes) {
          setState(() {
            _isLullabyPlaying = true;
            _activeTrack = track;
          });
          _webrtcService.sendTelemetry({
            'command': 'play_lullaby',
            'track_index': track.index,
            'duration_minutes': timerMinutes,
          });
        },
        onStop: () {
          setState(() {
            _isLullabyPlaying = false;
            _activeTrack = null;
          });
          _webrtcService.sendTelemetry({'command': 'stop_lullaby'});
        },
      ),
    );
  }

  @override
  void dispose() {
    if (widget.isCloudCall) {
      unawaited(_firestoreSignaling.endCall(widget.roomId));
      unawaited(_firestoreSignaling.dispose());
    } else {
      unawaited(_p2pClient.disconnect());
    }
    unawaited(_webrtcService.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              // 1. Video Stream Player inside rounded frame (Prevent shift/notch jump)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _isConnected
                      ? RTCVideoView(
                          _webrtcService.remoteRenderer,
                          objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                      : Container(
                          color: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: CircularProgressIndicator(
                                    color: Color(0xFF4F46E5),
                                    strokeWidth: 3,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Text(
                                  _statusText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white, fontSize: 16),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  widget.isCloudCall
                                      ? 'Streaming encrypted peer-to-peer over WebRTC.'
                                      : 'Ensure both phones are on the same Wi-Fi network.',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                                ),
                                const SizedBox(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF4F46E5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.refresh, color: Colors.white, size: 18),
                                      label: const Text('Retry', style: TextStyle(color: Colors.white)),
                                      onPressed: _onRetry,
                                    ),
                                    const SizedBox(width: 12),
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        side: const BorderSide(color: Colors.white24),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      ),
                                      icon: const Icon(Icons.wifi, color: Color(0xFF818CF8), size: 18),
                                      label: const Text('Direct IP', style: TextStyle(color: Colors.white)),
                                      onPressed: _showManualIpDialog,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),

              // 2. Top Bar (Telemetries & Room Info)
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: Colors.black45),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),

                    // Connection & Room Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isConnected ? Colors.green.withOpacity(0.85) : Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isConnected ? Icons.cloud_done : Icons.cloud_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _isConnected
                                ? (widget.isCloudCall ? 'Live Cloud HD • ${widget.deviceName ?? "Baby"}' : 'Connected • Local P2P')
                                : (widget.isCloudCall ? (widget.deviceName ?? 'Connecting...') : 'Room: ${widget.roomId}'),
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),

                    // Baby Battery Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _babyIsCharging ? Icons.battery_charging_full : Icons.battery_std,
                            color: _babyBattery < 20 ? Colors.redAccent : Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_babyBattery%',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Audio & Cry Decibel Meter
              if (_isConnected)
                Positioned(
                  top: 70,
                  left: 16,
                  right: 16,
                  child: DecibelMeter(currentDb: _babyDb),
                ),

              // 4. Remote Controls & Walkie-Talkie Button
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Top Secondary Controls
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // 1. Remote Baby Camera Toggle
                          IconButton(
                            icon: Icon(
                              _isBabyCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                              color: _isBabyCameraEnabled ? const Color(0xFF10B981) : Colors.redAccent,
                            ),
                            tooltip: _isBabyCameraEnabled ? 'Pause Nursery Video' : 'Enable Nursery Video',
                            onPressed: _toggleBabyCamera,
                          ),

                          // 2. Remote Baby Mic Toggle
                          IconButton(
                            icon: Icon(
                              _isBabyMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                              color: _isBabyMicEnabled ? const Color(0xFF10B981) : Colors.redAccent,
                            ),
                            tooltip: _isBabyMicEnabled ? 'Mute Nursery Mic' : 'Enable Nursery Mic',
                            onPressed: _toggleBabyMic,
                          ),

                          // 3. Room Speaker / Audio Mute
                          IconButton(
                            icon: Icon(
                              _isNurseryAudioMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                              color: _isNurseryAudioMuted ? Colors.redAccent : Colors.white70,
                            ),
                            tooltip: _isNurseryAudioMuted ? 'Unmute Room Audio' : 'Mute Room Audio',
                            onPressed: _toggleNurseryAudio,
                          ),

                          // 4. Flip Nursery Camera
                          IconButton(
                            icon: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white70),
                            tooltip: 'Flip Nursery Camera',
                            onPressed: _flipBabyCamera,
                          ),

                          // 5. Nursery Nightlight Torch
                          IconButton(
                            icon: Icon(
                              _babyTorchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                              color: _babyTorchOn ? Colors.amber : Colors.white70,
                            ),
                            tooltip: 'Toggle Nursery Flashlight',
                            onPressed: _toggleBabyTorch,
                          ),

                          // 6. Lullabies Sheet
                          IconButton(
                            icon: Icon(
                              Icons.music_note_rounded,
                              color: _isLullabyPlaying ? const Color(0xFF818CF8) : Colors.white70,
                            ),
                            tooltip: 'Lullabies & White Noise',
                            onPressed: _showLullabySheet,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bottom Row: Hands-Free Mic Toggle + Push-To-Talk Button
                    Row(
                      children: [
                        // Hands-Free Mic Toggle Button
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: _toggleHandsFreeMic,
                          child: Container(
                            height: 54,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: _isHandsFreeMic ? Colors.redAccent : const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: _isHandsFreeMic ? Colors.redAccent : Colors.white24,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _isHandsFreeMic ? Icons.mic_rounded : Icons.mic_none_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _isHandsFreeMic ? 'MIC ON' : 'AUTO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Push-To-Talk Walkie-Talkie Button
                        Expanded(
                          child: GestureDetector(
                            onTapDown: (_) => _onStartTalking(),
                            onTapUp: (_) => _onStopTalking(),
                            onTapCancel: () => _onStopTalking(),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 54,
                              decoration: BoxDecoration(
                                color: _isTalking ? Colors.redAccent : const Color(0xFF4F46E5),
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: (_isTalking ? Colors.redAccent : const Color(0xFF4F46E5)).withOpacity(0.4),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isTalking ? Icons.mic : Icons.mic_none,
                                    color: Colors.white,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isHandsFreeMic
                                        ? 'TALKING (HANDS-FREE ON)'
                                        : (_isTalking ? 'TALKING (RELEASE TO STOP)' : 'HOLD TO TALK TO BABY'),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
