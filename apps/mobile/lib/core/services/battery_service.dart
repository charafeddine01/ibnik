import 'dart:async';
import 'package:battery_plus/battery_plus.dart';

class BatteryTelemetry {
  final int batteryLevel;
  final BatteryState batteryState;

  BatteryTelemetry({required this.batteryLevel, required this.batteryState});

  Map<String, dynamic> toMap() {
    return {
      'battery_level': batteryLevel,
      'is_charging': batteryState == BatteryState.charging || batteryState == BatteryState.full,
    };
  }
}

class BatteryService {
  final Battery _battery = Battery();
  StreamSubscription<BatteryState>? _stateSubscription;
  Timer? _pollingTimer;

  Function(BatteryTelemetry telemetry)? onTelemetryChanged;

  void startMonitoring() {
    _sendTelemetry();

    // Listen to charging state changes
    _stateSubscription = _battery.onBatteryStateChanged.listen((_) {
      _sendTelemetry();
    });

    // Poll battery level every 60 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _sendTelemetry();
    });
  }

  Future<void> _sendTelemetry() async {
    try {
      final level = await _battery.batteryLevel;
      final state = await _battery.batteryState;
      onTelemetryChanged?.call(BatteryTelemetry(batteryLevel: level, batteryState: state));
    } catch (_) {
      // Hardware might not support battery API (e.g. some emulators)
    }
  }

  void stop() {
    _stateSubscription?.cancel();
    _pollingTimer?.cancel();
  }
}
