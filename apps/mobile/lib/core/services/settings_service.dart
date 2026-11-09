import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonitorSettings {
  final double noiseThreshold; // dB threshold for alert (40.0 - 85.0)
  final bool isCryAlertEnabled;
  final bool isVibrationEnabled;
  final bool isAudioChimeEnabled;
  final bool isBackgroundMonitoringEnabled;
  final bool keepScreenAwake;
  final bool lowBatteryAlertEnabled;

  const MonitorSettings({
    this.noiseThreshold = 65.0,
    this.isCryAlertEnabled = true,
    this.isVibrationEnabled = true,
    this.isAudioChimeEnabled = true,
    this.isBackgroundMonitoringEnabled = true,
    this.keepScreenAwake = true,
    this.lowBatteryAlertEnabled = true,
  });

  MonitorSettings copyWith({
    double? noiseThreshold,
    bool? isCryAlertEnabled,
    bool? isVibrationEnabled,
    bool? isAudioChimeEnabled,
    bool? isBackgroundMonitoringEnabled,
    bool? keepScreenAwake,
    bool? lowBatteryAlertEnabled,
  }) {
    return MonitorSettings(
      noiseThreshold: noiseThreshold ?? this.noiseThreshold,
      isCryAlertEnabled: isCryAlertEnabled ?? this.isCryAlertEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      isAudioChimeEnabled: isAudioChimeEnabled ?? this.isAudioChimeEnabled,
      isBackgroundMonitoringEnabled: isBackgroundMonitoringEnabled ?? this.isBackgroundMonitoringEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      lowBatteryAlertEnabled: lowBatteryAlertEnabled ?? this.lowBatteryAlertEnabled,
    );
  }
}

class SettingsService {
  static const String _kNoiseThreshold = 'setting_noise_threshold';
  static const String _kCryAlert = 'setting_cry_alert';
  static const String _kVibrate = 'setting_vibrate';
  static const String _kAudioChime = 'setting_audio_chime';
  static const String _kBackground = 'setting_background';
  static const String _kWakelock = 'setting_wakelock';
  static const String _kLowBattery = 'setting_low_battery';

  static SettingsService? _instance;
  factory SettingsService() => _instance ??= SettingsService._();
  SettingsService._();

  final ValueNotifier<MonitorSettings> settingsNotifier = ValueNotifier<MonitorSettings>(const MonitorSettings());

  MonitorSettings get current => settingsNotifier.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = MonitorSettings(
      noiseThreshold: prefs.getDouble(_kNoiseThreshold) ?? 65.0,
      isCryAlertEnabled: prefs.getBool(_kCryAlert) ?? true,
      isVibrationEnabled: prefs.getBool(_kVibrate) ?? true,
      isAudioChimeEnabled: prefs.getBool(_kAudioChime) ?? true,
      isBackgroundMonitoringEnabled: prefs.getBool(_kBackground) ?? true,
      keepScreenAwake: prefs.getBool(_kWakelock) ?? true,
      lowBatteryAlertEnabled: prefs.getBool(_kLowBattery) ?? true,
    );
    settingsNotifier.value = loaded;
  }

  Future<void> updateSettings(MonitorSettings newSettings) async {
    settingsNotifier.value = newSettings;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kNoiseThreshold, newSettings.noiseThreshold);
    await prefs.setBool(_kCryAlert, newSettings.isCryAlertEnabled);
    await prefs.setBool(_kVibrate, newSettings.isVibrationEnabled);
    await prefs.setBool(_kAudioChime, newSettings.isAudioChimeEnabled);
    await prefs.setBool(_kBackground, newSettings.isBackgroundMonitoringEnabled);
    await prefs.setBool(_kWakelock, newSettings.keepScreenAwake);
    await prefs.setBool(_kLowBattery, newSettings.lowBatteryAlertEnabled);
  }
}
