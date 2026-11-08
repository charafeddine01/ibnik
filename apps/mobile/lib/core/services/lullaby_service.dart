import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum LullabyTrack {
  whiteNoise,
  heartbeat,
  gentleRain,
  classicalLullaby,
  oceanWaves,
}

extension LullabyTrackExtension on LullabyTrack {
  String get title {
    switch (this) {
      case LullabyTrack.whiteNoise:
        return 'White Noise';
      case LullabyTrack.heartbeat:
        return 'Womb Heartbeat';
      case LullabyTrack.gentleRain:
        return 'Gentle Rain';
      case LullabyTrack.classicalLullaby:
        return 'Brahms Lullaby';
      case LullabyTrack.oceanWaves:
        return 'Ocean Waves';
    }
  }

  String get assetPath {
    switch (this) {
      case LullabyTrack.whiteNoise:
        return 'assets/lullabies/white_noise.mp3';
      case LullabyTrack.heartbeat:
        return 'assets/lullabies/heartbeat.mp3';
      case LullabyTrack.gentleRain:
        return 'assets/lullabies/rain.mp3';
      case LullabyTrack.classicalLullaby:
        return 'assets/lullabies/brahms.mp3';
      case LullabyTrack.oceanWaves:
        return 'assets/lullabies/waves.mp3';
    }
  }
}

class LullabyService {
  final AudioPlayer _player = AudioPlayer();
  Timer? _sleepTimer;
  bool _isPlaying = false;
  LullabyTrack? _currentTrack;
  double _volume = 0.7;

  bool get isPlaying => _isPlaying;
  LullabyTrack? get currentTrack => _currentTrack;
  double get volume => _volume;

  Future<void> init() async {
    await _player.setReleaseMode(ReleaseMode.loop);
    await _player.setVolume(_volume);
  }

  Future<void> playTrack(LullabyTrack track, {int? timerMinutes}) async {
    _sleepTimer?.cancel();
    _currentTrack = track;
    _isPlaying = true;

    try {
      await _player.play(AssetSource(track.assetPath.replaceFirst('assets/', '')));
      await _player.setVolume(_volume);

      if (timerMinutes != null && timerMinutes > 0) {
        _sleepTimer = Timer(Duration(minutes: timerMinutes), () async {
          await stop();
        });
      }
    } catch (e) {
      debugPrint('Error playing lullaby track: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _player.setVolume(_volume);
  }

  Future<void> stop() async {
    _sleepTimer?.cancel();
    _isPlaying = false;
    _currentTrack = null;
    await _player.stop();
  }

  void dispose() {
    _sleepTimer?.cancel();
    _player.dispose();
  }
}
