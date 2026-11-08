import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../core/services/webrtc_service.dart';
import '../../core/services/lullaby_service.dart';
import 'widgets/decibel_meter.dart';
import '../lullaby/lullaby_sheet.dart';

class ParentUnitScreen extends StatefulWidget {
  final String roomId;

  const ParentUnitScreen({super.key, required this.roomId});

  @override
  State<ParentUnitScreen> createState() => _ParentUnitScreenState();
}

class _ParentUnitScreenState extends State<ParentUnitScreen> {
  final WebRTCService _webrtcService = WebRTCService();

  bool _isConnected = false;
  bool _isTalking = false;
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

    // 2. Setup telemetry callback
    _webrtcService.onTelemetryReceived = (data) {
      if (data['type'] == 'telemetry' || data['type'] == 'audio_level') {
        setState(() {
          if (data.containsKey('db')) _babyDb = (data['db'] as num).toDouble();
          if (data.containsKey('battery_level')) _babyBattery = data['battery_level'] as int;
          if (data.containsKey('is_charging')) _babyIsCharging = data['is_charging'] as bool;
        });
      } else if (data['type'] == 'torch_state') {
        setState(() {
          _babyTorchOn = data['is_on'] as bool;
        });
      }
    };

    _webrtcService.onConnectionConnected = () {
      setState(() => _isConnected = true);
    };

    _webrtcService.onConnectionDisconnected = () {
      setState(() => _isConnected = false);
    };

    setState(() {});
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LullabySheet(
        isPlaying: _isLullabyPlaying,
        activeTrack: _activeTrack,
        onPlayTrack: (track, duration) {
          setState(() {
            _isLullabyPlaying = true;
            _activeTrack = track;
          });
          _webrtcService.sendTelemetry({
            'command': 'play_lullaby',
            'track_index': track.index,
            'duration_minutes': duration,
          });
          Navigator.of(context).pop();
        },
        onStop: () {
          setState(() {
            _isLullabyPlaying = false;
            _activeTrack = null;
          });
          _webrtcService.sendTelemetry({'command': 'stop_lullaby'});
          Navigator.of(context).pop();
        },
      ),
    );
  }

  @override
  void dispose() {
    _webrtcService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Remote Video Feed from Baby Unit
          Positioned.fill(
            child: _webrtcService.remoteRenderer.srcObject != null
                ? RTCVideoView(
                    _webrtcService.remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                : Container(
                    color: const Color(0xFF0F172A),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Color(0xFF4F46E5)),
                          const SizedBox(height: 20),
                          Text(
                            _isConnected ? 'Waiting for video stream...' : 'Connecting to Baby Unit...',
                            style: const TextStyle(color: Colors.white70, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Room PIN: ${widget.roomId}',
                            style: const TextStyle(color: Color(0xFF818CF8), fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),

          // 2. Top Status Bar (Decibel Meter & Telemetry)
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          style: IconButton.styleFrom(backgroundColor: Colors.black54),
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
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
                                _babyIsCharging ? Icons.battery_charging_full_rounded : Icons.battery_std_rounded,
                                color: _babyBattery < 20 ? Colors.redAccent : Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '$_babyBattery%',
                                style: TextStyle(
                                  color: _babyBattery < 20 ? Colors.redAccent : Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DecibelMeter(currentDb: _babyDb),
                  ],
                ),
              ),
            ),
          ),

          // 3. Bottom Controls & Push-to-Talk Button
          SafeArea(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Remote quick controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        FloatingActionButton.small(
                          heroTag: 'p_torch',
                          backgroundColor: _babyTorchOn ? Colors.amberAccent : Colors.black54,
                          onPressed: _toggleBabyTorch,
                          child: Icon(Icons.flashlight_on_rounded, color: _babyTorchOn ? Colors.black : Colors.white),
                        ),
                        const SizedBox(width: 16),
                        FloatingActionButton.small(
                          heroTag: 'p_flip',
                          backgroundColor: Colors.black54,
                          onPressed: _flipBabyCamera,
                          child: const Icon(Icons.flip_camera_ios_rounded, color: Colors.white),
                        ),
                        const SizedBox(width: 16),
                        FloatingActionButton.small(
                          heroTag: 'p_music',
                          backgroundColor: _isLullabyPlaying ? const Color(0xFF4F46E5) : Colors.black54,
                          onPressed: _showLullabySheet,
                          child: const Icon(Icons.music_note_rounded, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Hold to Talk (Walkie-Talkie)
                    GestureDetector(
                      onTapDown: (_) => _onStartTalking(),
                      onTapUp: (_) => _onStopTalking(),
                      onTapCancel: () => _onStopTalking(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        decoration: BoxDecoration(
                          color: _isTalking ? Colors.redAccent : const Color(0xFF4F46E5),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: (_isTalking ? Colors.redAccent : const Color(0xFF4F46E5)).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_isTalking ? Icons.mic : Icons.mic_none, color: Colors.white, size: 24),
                            const SizedBox(width: 10),
                            Text(
                              _isTalking ? 'TALKING TO BABY...' : 'HOLD TO TALK',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ],
                        ),
                      ),
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
