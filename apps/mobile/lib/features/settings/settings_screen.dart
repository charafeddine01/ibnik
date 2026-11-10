import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/background_monitor_service.dart';
import '../../core/theme/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsService _settingsService = SettingsService();
  late MonitorSettings _settings;

  @override
  void initState() {
    super.initState();
    _settings = _settingsService.current;
  }

  void _update(MonitorSettings updated) {
    setState(() => _settings = updated);
    _settingsService.updateSettings(updated);
  }

  String _getThresholdLabel(double db) {
    if (db <= 48) return 'Sensitive (Whisper / Soft Movement)';
    if (db <= 62) return 'Balanced (Babbling / Crying)';
    if (db <= 75) return 'Medium (Loud Cry)';
    return 'High (Very Loud / Screaming)';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppThemeColors.of(_settings.appThemeMode);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          'Monitor Settings',
          style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colors.background,
        foregroundColor: colors.textPrimary,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. Theme Selection Section (Task 6)
            _buildSectionHeader('APPEARANCE & THEME', Icons.palette_outlined, colors),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Theme',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose a visual theme that is easy on your eyes day or night',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildThemeTile(
                          mode: AppThemeMode.dark,
                          title: 'Dark',
                          subtitle: 'Midnight',
                          colors: colors,
                          previewBg: const Color(0xFF0B0F19),
                          previewCard: const Color(0xFF151E2E),
                          previewAccent: const Color(0xFF6366F1),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildThemeTile(
                          mode: AppThemeMode.moderate,
                          title: 'Moderate',
                          subtitle: 'Twilight',
                          colors: colors,
                          previewBg: const Color(0xFF1A1D24),
                          previewCard: const Color(0xFF252A36),
                          previewAccent: const Color(0xFF818CF8),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildThemeTile(
                          mode: AppThemeMode.light,
                          title: 'Light',
                          subtitle: 'Crisp',
                          colors: colors,
                          previewBg: const Color(0xFFF8FAFC),
                          previewCard: const Color(0xFFFFFFFF),
                          previewAccent: const Color(0xFF4F46E5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Noise & Cry Detection Section (Task 1)
            _buildSectionHeader('NOISE & CRY ALERTS', Icons.notifications_active_rounded, colors),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: colors.primary,
                    title: Text(
                      'Baby Cry & High Noise Alerts',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      'Alerts parent phone when nursery noise exceeds your threshold',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    value: _settings.isCryAlertEnabled,
                    onChanged: (val) => _update(_settings.copyWith(isCryAlertEnabled: val)),
                  ),
                  if (_settings.isCryAlertEnabled) ...[
                    Divider(color: colors.border, height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Sensitivity Threshold',
                          style: TextStyle(color: colors.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: colors.primary.withOpacity(0.5)),
                          ),
                          child: Text(
                            '${_settings.noiseThreshold.toInt()} dB',
                            style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getThresholdLabel(_settings.noiseThreshold),
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: colors.primary,
                        inactiveTrackColor: colors.border,
                        thumbColor: colors.primary,
                        trackHeight: 6,
                      ),
                      child: Slider(
                        value: _settings.noiseThreshold,
                        min: 40.0,
                        max: 85.0,
                        divisions: 9,
                        onChanged: (val) {
                          HapticFeedback.selectionClick();
                          _update(_settings.copyWith(noiseThreshold: val));
                        },
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPresetButton('Sensitive', 45.0, colors),
                        _buildPresetButton('Normal', 60.0, colors),
                        _buildPresetButton('Loud', 75.0, colors),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: colors.border),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: colors.primary,
                      title: Text('Sound Alert Chime', style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                      subtitle: Text('Play gentle alert chime when baby cries', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      value: _settings.isAudioChimeEnabled,
                      onChanged: (val) => _update(_settings.copyWith(isAudioChimeEnabled: val)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: colors.primary,
                      title: Text('Vibration Alert', style: TextStyle(color: colors.textPrimary, fontSize: 14)),
                      subtitle: Text('Vibrate parent phone when baby cries', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                      value: _settings.isVibrationEnabled,
                      onChanged: (val) => _update(_settings.copyWith(isVibrationEnabled: val)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 3. Background Streaming & Battery (Task 1)
            _buildSectionHeader('BACKGROUND & LOCK SCREEN', Icons.battery_charging_full_rounded, colors),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: colors.secondary,
                    title: Text(
                      'Continuous Background Streaming',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Keep streaming audio & noise monitoring alive even when phone is locked or app is minimized',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    value: _settings.isBackgroundMonitoringEnabled,
                    onChanged: (val) => _update(_settings.copyWith(isBackgroundMonitoringEnabled: val)),
                  ),
                  Divider(color: colors.border, height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: colors.secondary,
                    title: Text(
                      'Keep Screen Awake',
                      style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: Text(
                      'Prevents the display from automatically sleeping during live video monitoring',
                      style: TextStyle(color: colors.textSecondary, fontSize: 12),
                    ),
                    value: _settings.keepScreenAwake,
                    onChanged: (val) => _update(_settings.copyWith(keepScreenAwake: val)),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colors.secondary,
                      side: BorderSide(color: colors.secondary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    icon: const Icon(Icons.security_rounded, size: 20),
                    label: const Text(
                      'Grant Battery Optimization Exemption',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    onPressed: () async {
                      await BackgroundMonitorService.requestPermissions();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Battery optimization exemptions requested!')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 4. About App
            _buildSectionHeader('ABOUT IBNIK', Icons.info_outline_rounded, colors),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: colors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('🍼', style: TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Text(
                        'Ibnik Baby Monitor',
                        style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'v1.0.10',
                          style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Real-time streaming • End-to-End Encrypted (DTLS-SRTP) • 100% Free',
                    style: TextStyle(color: colors.textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Divider(color: colors.border),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Target Platform', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      Text('Android 16 (API 36)', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Page Alignment', style: TextStyle(color: colors.textSecondary, fontSize: 13)),
                      Text('16 KB Compliant', style: TextStyle(color: colors.secondary, fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required AppThemeMode mode,
    required String title,
    required String subtitle,
    required AppThemeColors colors,
    required Color previewBg,
    required Color previewCard,
    required Color previewAccent,
  }) {
    final isSelected = _settings.appThemeMode == mode;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        _update(_settings.copyWith(appThemeMode: mode));
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? colors.primary : colors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Theme preview swatch
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: previewBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white24, width: 0.5),
              ),
              child: Center(
                child: Container(
                  width: 32,
                  height: 24,
                  decoration: BoxDecoration(
                    color: previewCard,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: previewAccent, width: 1.5),
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: previewAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isSelected)
                  Icon(Icons.check_circle_rounded, color: colors.primary, size: 14)
                else
                  const SizedBox(width: 14),
                const SizedBox(width: 4),
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? colors.primary : colors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            Text(
              subtitle,
              style: TextStyle(color: colors.textSecondary, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetButton(String label, double value, AppThemeColors colors) {
    final isSelected = (_settings.noiseThreshold - value).abs() < 3.0;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : colors.textSecondary,
        backgroundColor: isSelected ? colors.primary : Colors.transparent,
        side: BorderSide(color: isSelected ? colors.primary : colors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      onPressed: () {
        HapticFeedback.selectionClick();
        _update(_settings.copyWith(noiseThreshold: value));
      },
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: colors.primary, size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: colors.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
