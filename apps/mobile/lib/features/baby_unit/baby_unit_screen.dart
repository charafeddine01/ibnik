import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:torch_light/torch_light.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../core/services/webrtc_service.dart';
import '../../core/services/battery_service.dart';
import '../../core/services/lullaby_service.dart';
import '../../core/services/local_discovery_service.dart';
import '../../core/services/local_p2p_server.dart';
import '../../core/services/device_registry_service.dart';
import '../../core/services/firestore_signaling_service.dart';
import '../pairing/baby_qr_scanner_screen.dart';

class BabyUnitScreen extends StatefulWidget {
  final String roomId;
  final String? userId;
  final String? deviceId;
  final String? deviceName;
  final bool isCloudCall;

  const BabyUnitScreen({
    super.key,
    required this.roomId,
    this.userId,
    this.deviceId,
    this.deviceName,
    this.isCloudCall = false,
  });

  @override
  State<BabyUnitScreen> createState() => _BabyUnitScreenState();
}

class _BabyUnitScreenState extends State<BabyUnitScreen> {
  final WebRTCService _webrtcService = WebRTCService();
  final BatteryService _batteryService = BatteryService();
  final LullabyService _lullabyService = LullabyService();
  final LocalDiscoveryService _discoveryService = LocalDiscoveryService();
  final LocalP2PServer _p2pServer = LocalP2PServer();
  final DeviceRegistryService _registryService = DeviceRegistryService();
  final FirestoreSignalingService _cloudSignaling = FirestoreSignalingService();

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
    unawaited(WakelockPlus.enable());
    _initServices();
  }

  Future<void> _initServices() async {
    await _webrtcService.initializeRenderers();
    await _lullabyService.init();

    // 1. Open nursery camera and microphone
    await _webrtcService.openUserMedia(isBabyUnit: true);
    if (mounted) setState(() {});

    // 2. Cloud Signaling & Channel Registry Mode
    await _registryService.registerChannel(
      channelId: widget.roomId,
      name: widget.deviceName ?? 'Nursery Camera',
      batteryLevel: _batteryLevel,
      isCharging: _isCharging,
    );

    _registryService.startChannelHeartbeat(
      channelId: widget.roomId,
      getBatteryLevel: () => _batteryLevel,
      getIsCharging: () => _isCharging,
    );

    await _cloudSignaling.listenForParentCalls(
      callId: widget.roomId,
      webrtcService: _webrtcService,
      onConnected: () {
        debugPrint('BabyUnit: Cloud WebRTC call connected with Parent Unit!');
        if (mounted) setState(() => _isParentConnected = true);
      },
      onDisconnected: () {
        debugPrint('BabyUnit: Cloud WebRTC call disconnected');
        if (mounted) setState(() => _isParentConnected = false);
      },
    );

    // 3. Embedded Local P2P Server Backup
    final serverStarted = await _p2pServer.start(roomId: widget.roomId);
    if (serverStarted) {
      if (mounted) setState(() {});

      await _discoveryService.startAdvertising(
        roomId: widget.roomId,
        port: _p2pServer.port,
      );

      _p2pServer.onClientConnected = () async {
        debugPrint('BabyUnit: Local Parent connected! Initializing WebRTC Offer...');
        await _webrtcService.createPeerConnectionInstance(
          roomId: widget.roomId,
          myPeerId: 'baby',
          targetPeerId: 'parent',
          isBabyUnit: true,
        );

        _webrtcService.onSignalingMessage = (msg) {
          _p2pServer.sendMessage(msg);
        };

        await _webrtcService.createAndSendOffer(
          roomId: widget.roomId,
          myPeerId: 'baby',
          targetPeerId: 'parent',
        );

        if (mounted) setState(() => _isParentConnected = true);
      };

      _p2pServer.onMessageReceived = (msg) async {
        if (msg.type == 'answer') {
          await _webrtcService.handleAnswer(msg);
        } else if (msg.type == 'candidate') {
          await _webrtcService.addCandidate(msg);
        }
      };

      _p2pServer.onClientDisconnected = () {
        if (mounted) setState(() => _isParentConnected = false);
      };
    }

    // 4. Monitor battery level
    _batteryService.startMonitoring();
    _batteryService.onTelemetryChanged = (telemetry) {
      if (!mounted) return;
      setState(() {
        _batteryLevel = telemetry.batteryLevel;
        _isCharging = telemetry.toMap()['is_charging'] as bool;
      });
      _webrtcService.sendTelemetry({
        'type': 'telemetry',
        'battery_level': _batteryLevel,
        'is_charging': _isCharging,
        'db': _currentDb,
      });
    };

    // 5. Remote controls callback
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
      debugPrint('BabyUnit: WebRTC stream connected!');
      if (mounted) setState(() => _isParentConnected = true);
    };

    _webrtcService.onConnectionDisconnected = () {
      debugPrint('BabyUnit: WebRTC stream disconnected');
      if (mounted) setState(() => _isParentConnected = false);
    };

    // 6. Audio level polling
    _dbSimulatorTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      final simulated = 32.0 + (DateTime.now().millisecond % 15);
      setState(() => _currentDb = simulated);
      _webrtcService.sendTelemetry({
        'type': 'audio_level',
        'db': _currentDb,
      });
    });
  }

  Future<void> _toggleTorch() async {
    try {
      if (_isTorchOn) {
        await TorchLight.disableTorch();
      } else {
        await TorchLight.enableTorch();
      }
      setState(() => _isTorchOn = !_isTorchOn);
      _webrtcService.sendTelemetry({
        'type': 'torch_state',
        'is_on': _isTorchOn,
      });
    } catch (e) {
      debugPrint('Failed to toggle torch: $e');
    }
  }

  void _showRePairDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Re-Pair Baby Unit?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Do you want to scan a new QR code from a Parent phone?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () async {
              final nav = Navigator.of(context);
              Navigator.pop(ctx);
              await _registryService.clearMyBabyChannel();
              if (mounted) {
                nav.pushReplacement(
                  MaterialPageRoute<void>(builder: (_) => const BabyQrScannerScreen()),
                );
              }
            },
            child: const Text('Scan QR Code', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _dbSimulatorTimer?.cancel();
    _batteryService.dispose();
    unawaited(_discoveryService.stop());
    unawaited(_p2pServer.stop());
    unawaited(_registryService.setChannelOffline(widget.roomId));
    unawaited(_cloudSignaling.endCall(widget.roomId));
    _registryService.dispose();
    _cloudSignaling.dispose();
    _lullabyService.dispose();
    unawaited(_webrtcService.dispose());
    unawaited(WakelockPlus.disable());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isDimMode) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: () => setState(() => _isDimMode = false),
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.nightlight_round, color: Colors.amber, size: 40),
                const SizedBox(height: 12),
                Text(
                  'Night Dim Mode Active',
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap screen to restore preview',
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Stack(
            children: [
              // 1. Camera View inside rounded frame (Prevent shift/notch jump)
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RTCVideoView(
                    _webrtcService.localRenderer,
                    mirror: false,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

              // 2. Top Info Header
              Positioned(
                top: 10,
                left: 10,
                right: 10,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          icon: const Icon(Icons.arrow_back, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _isParentConnected ? Colors.green.withOpacity(0.85) : Colors.black54,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _isParentConnected ? Icons.check_circle : Icons.wifi_tethering,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isParentConnected
                                    ? 'Parent Connected • Live'
                                    : (widget.deviceName ?? 'Nursery Camera (Ready)'),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Battery Telemetry Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _isCharging ? Icons.battery_charging_full : Icons.battery_std,
                            color: _batteryLevel < 20 ? Colors.redAccent : Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_batteryLevel%',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 3. Quick Action Controls (Flashlight, Flip, Re-pair QR, Dim Mode)
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isTorchOn ? Icons.flash_on : Icons.flash_off,
                          color: _isTorchOn ? Colors.amber : Colors.white70,
                        ),
                        tooltip: 'Flashlight',
                        onPressed: _toggleTorch,
                      ),
                      IconButton(
                        icon: const Icon(Icons.flip_camera_ios, color: Colors.white70),
                        tooltip: 'Flip Camera',
                        onPressed: () => _webrtcService.switchCamera(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner, color: Colors.white70),
                        tooltip: 'Pair with new Parent QR',
                        onPressed: _showRePairDialog,
                      ),
                      IconButton(
                        icon: const Icon(Icons.dark_mode_outlined, color: Colors.white70),
                        tooltip: 'Night Dim Mode',
                        onPressed: () => setState(() => _isDimMode = true),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
