import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/services/webrtc_service.dart';
import '../../core/services/lullaby_service.dart';
import '../../core/services/local_p2p_client.dart';
import 'widgets/decibel_meter.dart';
import '../lullaby/lullaby_sheet.dart';

class ParentUnitScreen extends StatefulWidget {
  final String roomId;
  final String? targetIp;
  final int targetPort;

  const ParentUnitScreen({
    super.key,
    required this.roomId,
    this.targetIp,
    this.targetPort = 8888,
  });

  @override
  State<ParentUnitScreen> createState() => _ParentUnitScreenState();
}

class _ParentUnitScreenState extends State<ParentUnitScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final LocalP2PClient _p2pClient = LocalP2PClient();

  bool _isConnected = false;
  bool _isTalking = false;
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

    // 3. Setup Local P2P Client
    _p2pClient.onDiscoveryProgress = (status) {
      if (mounted) setState(() => _statusText = status);
    };

    _p2pClient.onConnected = () {
      if (mounted) setState(() => _statusText = 'Connected to Baby Unit socket');
    };

    _p2pClient.onMessageReceived = (msg) async {
      debugPrint('ParentUnit: Received signaling message: ${msg.type}');
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
      if (mounted) {
        setState(() {
          _isConnected = false;
          _statusText = 'Disconnected from Baby Unit';
        });
      }
    };

    // 4. Initiate connection
    _connect();
  }

  Future<void> _connect() async {
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

  void _onStartTalking() {
    setState(() => _isTalking = true);
    _webrtcService.setMicrophoneMute(false);
  }

  void _onStopTalking() {
    setState(() => _isTalking = false);
    _webrtcService.setMicrophoneMute(true);
  }

  void _toggleBabyTorch() {
    _webrtcService.sendTelemetry({'command': 'toggle_torch'});
  }

  void _flipBabyCamera() {
    _webrtcService.sendTelemetry({'command': 'flip_camera'});
  }

  void _showLullabySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LullabySheet(
        isPlaying: _isLullabyPlaying,
        activeTrack: _activeTrack,
        onPlay: (track, timerMinutes) {
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
    _p2pClient.disconnect();
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        children: [
          // 1. Video Stream Player
          Positioned.fill(
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
                          const Text(
                            'Ensure both phones are on the same Wi-Fi network.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white54, fontSize: 13),
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4F46E5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.refresh, color: Colors.white),
                            label: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
                            onPressed: _connect,
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Top Bar (Telemetries & Room Info)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                          _isConnected ? Icons.wifi : Icons.wifi_off,
                          color: Colors.white,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? 'Connected • Local P2P' : 'Room: ${widget.roomId}',
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
          ),

          // 3. Audio & Cry Decibel Meter
          if (_isConnected)
            Positioned(
              top: 80,
              left: 20,
              right: 20,
              child: DecibelMeter(currentDb: _babyDb),
            ),

          // 4. Remote Controls & Walkie-Talkie Button
          Positioned(
            bottom: 24,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Secondary Controls
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: Icon(
                          _babyTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: _babyTorchOn ? Colors.amber : Colors.white70,
                        ),
                        tooltip: 'Toggle Nursery Flashlight',
                        onPressed: _toggleBabyTorch,
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
                        tooltip: 'Flip Nursery Camera',
                        onPressed: _flipBabyCamera,
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.music_note,
                          color: _isLullabyPlaying ? const Color(0xFF818CF8) : Colors.white70,
                        ),
                        tooltip: 'Lullabies & White Noise',
                        onPressed: _showLullabySheet,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Push-To-Talk Walkie-Talkie Button
                GestureDetector(
                  onTapDown: (_) => _onStartTalking(),
                  onTapUp: (_) => _onStopTalking(),
                  onTapCancel: () => _onStopTalking(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    height: 56,
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
                          _isTalking ? 'TALKING TO BABY... (RELEASE TO STOP)' : 'HOLD TO TALK TO BABY',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
