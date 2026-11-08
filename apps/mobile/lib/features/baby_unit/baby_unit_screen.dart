import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/services/webrtc_service.dart';
import '../../core/services/battery_service.dart';
import '../../core/services/lullaby_service.dart';
import '../../core/services/local_discovery_service.dart';

class BabyUnitScreen extends StatefulWidget {
  final String roomId;

  const BabyUnitScreen({super.key, required this.roomId});

  @override
  State<BabyUnitScreen> createState() => _BabyUnitScreenState();
}

class _BabyUnitScreenState extends State<BabyUnitScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final BatteryService _batteryService = BatteryService();
  final LullabyService _lullabyService = LullabyService();
  final LocalDiscoveryService _discoveryService = LocalDiscoveryService();

  bool _isTorchOn = false;
  bool _isDimMode = false;
  double _currentDb = 35.0;
  Timer? _dbSimulatorTimer;
  int _batteryLevel = 100;
  bool _isCharging = false;
  bool _isParentConnected = false;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _initServices();
  }

  Future<void> _initServices() async {
    await _webrtcService.initializeRenderers();
    await _lullabyService.init();

    // 1. Open nursery camera and microphone
    await _webrtcService.openUserMedia(isBabyUnit: true);

    // 2. Start local mDNS discovery advertisement
    await _discoveryService.startAdvertising(roomId: widget.roomId, port: 8080);

    // 3. Monitor battery level
    _batteryService.startMonitoring();
    _batteryService.onTelemetryChanged = (telemetry) {
      setState(() {
        _batteryLevel = telemetry.batteryLevel;
        _isCharging = telemetry.toMap()['is_charging'] as bool;
      });
      // Send live battery telemetry over WebRTC DataChannel
      _webrtcService.sendTelemetry({
        'type': 'telemetry',
        'battery_level': _batteryLevel,
        'is_charging': _isCharging,
        'db': _currentDb,
      });
    };

    // 4. Handle remote commands from parent unit
    _webrtcService.onTelemetryReceived = (data) {
      final cmd = data['command'] as String?;
      if (cmd == 'toggle_torch') {
        _toggleTorch();
      } else if (cmd == 'flip_camera') {
        _webrtcService.switchCamera();
      } else if (cmd == 'play_lullaby') {
        final trackIndex = data['track_index'] as int? ?? 0;
        final duration = data['duration_minutes'] as int? ?? 30;
        _lullabyService.playTrack(LullabyTrack.values[trackIndex], timerMinutes: duration);
      } else if (cmd == 'stop_lullaby') {
        _lullabyService.stop();
      }
    };

    _webrtcService.onConnectionConnected = () {
      setState(() => _isParentConnected = true);
    };

    _webrtcService.onConnectionDisconnected = () {
      setState(() => _isParentConnected = false);
    };

    // Simulate ambient microphone level polling
    _dbSimulatorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      // Fluctuate around realistic background nursery levels (30 - 45 dB)
      final simulated = 32.0 + (DateTime.now().millisecond % 15);
      setState(() => _currentDb = simulated);
      _webrtcService.sendTelemetry({
        'type': 'audio_level',
        'db': _currentDb,
      });
    });

    setState(() {});
  }

  Future<void> _toggleTorch() async {
    try {
      if (_isTorchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() => _isTorchOn = !_isTorchOn);
      _webrtcService.sendTelemetry({'type': 'torch_state', 'is_on': _isTorchOn});
    } catch (_) {}
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _dbSimulatorTimer?.cancel();
    _batteryService.stop();
    _lullabyService.dispose();
    _discoveryService.stop();
    _webrtcService.dispose();
    if (_isTorchOn) {
      TorchLight.disableTorch().catchError((_) {});
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDimMode) {
      return GestureDetector(
        onTap: () => setState(() => _isDimMode = false),
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.nightlight_round, color: Colors.amberAccent, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Night Dim Mode Active',
                  style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap screen to awaken controls',
                  style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera Viewfinder
          Positioned.fill(
            child: _webrtcService.localRenderer.srcObject != null
                ? RTCVideoView(
                    _webrtcService.localRenderer,
                    mirror: false,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),
          ),

          // 2. Header Info Bar
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.circle,
                            color: _isParentConnected ? Colors.greenAccent : Colors.orangeAccent,
                            size: 10,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isParentConnected ? 'Parent Connected' : 'Waiting for Parent...',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_batteryLevel%',
                            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Bottom Controls
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'flip_cam',
                      backgroundColor: Colors.black54,
                      onPressed: () => _webrtcService.switchCamera(),
                      child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'torch',
                      backgroundColor: _isTorchOn ? Colors.amberAccent : Colors.black54,
                      onPressed: _toggleTorch,
                      child: Icon(Icons.flashlight_on_rounded, color: _isTorchOn ? Colors.black : Colors.white),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'dim',
                      backgroundColor: Colors.black54,
                      onPressed: () => setState(() => _isDimMode = true),
                      child: const Icon(Icons.nightlight_round, color: Colors.white),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'exit',
                      backgroundColor: Colors.redAccent.withOpacity(0.8),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
