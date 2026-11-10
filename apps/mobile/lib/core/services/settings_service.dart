import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

class MonitorSettings {
  final double noiseThreshold; // dB threshold for alert (40.0 - 85.0)
  final bool isCryAlertEnabled;
  final bool isVibrationEnabled;
  final bool isAudioChimeEnabled;
  final bool isBackgroundMonitoringEnabled;
  final bool keepScreenAwake;
  final bool lowBatteryAlertEnabled;
  final AppThemeMode appThemeMode;
  final String deviceRole; // 'parent', 'baby', or 'unset'

  const MonitorSettings({
    this.noiseThreshold = 65.0,
    this.isCryAlertEnabled = true,
    this.isVibrationEnabled = true,
    this.isAudioChimeEnabled = true,
    this.isBackgroundMonitoringEnabled = true,
    this.keepScreenAwake = true,
    this.lowBatteryAlertEnabled = true,
    this.appThemeMode = AppThemeMode.dark,
    this.deviceRole = 'unset',
  });

  MonitorSettings copyWith({
    double? noiseThreshold,
    bool? isCryAlertEnabled,
    bool? isVibrationEnabled,
    bool? isAudioChimeEnabled,
    bool? isBackgroundMonitoringEnabled,
    bool? keepScreenAwake,
    bool? lowBatteryAlertEnabled,
    AppThemeMode? appThemeMode,
    String? deviceRole,
  }) {
    return MonitorSettings(
      noiseThreshold: noiseThreshold ?? this.noiseThreshold,
      isCryAlertEnabled: isCryAlertEnabled ?? this.isCryAlertEnabled,
      isVibrationEnabled: isVibrationEnabled ?? this.isVibrationEnabled,
      isAudioChimeEnabled: isAudioChimeEnabled ?? this.isAudioChimeEnabled,
      isBackgroundMonitoringEnabled: isBackgroundMonitoringEnabled ?? this.isBackgroundMonitoringEnabled,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      lowBatteryAlertEnabled: lowBatteryAlertEnabled ?? this.lowBatteryAlertEnabled,
      appThemeMode: appThemeMode ?? this.appThemeMode,
      deviceRole: deviceRole ?? this.deviceRole,
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
  static const String _kAppTheme = 'setting_app_theme';
  static const String _kDeviceRole = 'setting_device_role';

  static SettingsService? _instance;
  factory SettingsService() => _instance ??= SettingsService._();
  SettingsService._();

  final ValueNotifier<MonitorSettings> settingsNotifier = ValueNotifier<MonitorSettings>(const MonitorSettings());

  MonitorSettings get current => settingsNotifier.value;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Parse theme
    final themeStr = prefs.getString(_kAppTheme) ?? 'dark';
    AppThemeMode theme = AppThemeMode.dark;
    if (themeStr == 'light') theme = AppThemeMode.light;
    if (themeStr == 'moderate') theme = AppThemeMode.moderate;

    final loaded = MonitorSettings(
      noiseThreshold: prefs.getDouble(_kNoiseThreshold) ?? 65.0,
      isCryAlertEnabled: prefs.getBool(_kCryAlert) ?? true,
      isVibrationEnabled: prefs.getBool(_kVibrate) ?? true,
      isAudioChimeEnabled: prefs.getBool(_kAudioChime) ?? true,
      isBackgroundMonitoringEnabled: prefs.getBool(_kBackground) ?? true,
      keepScreenAwake: prefs.getBool(_kWakelock) ?? true,
      lowBatteryAlertEnabled: prefs.getBool(_kLowBattery) ?? true,
      appThemeMode: theme,
      deviceRole: prefs.getString(_kDeviceRole) ?? 'unset',
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
    await prefs.setString(_kAppTheme, newSettings.appThemeMode.name);
    await prefs.setString(_kDeviceRole, newSettings.deviceRole);
  }

  Future<void> setTheme(AppThemeMode mode) async {
    await updateSettings(current.copyWith(appThemeMode: mode));
  }

  Future<void> setDeviceRole(String role) async {
    await updateSettings(current.copyWith(deviceRole: role));
  }
}
