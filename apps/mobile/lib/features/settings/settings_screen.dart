import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/background_monitor_service.dart';

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
    if (db <= 48) return 'Sensitive (Whisper / Soft movement)';
    if (db <= 62) return 'Balanced (Crying / Babbling)';
    if (db <= 75) return 'Medium (Loud Cry)';
    return 'High (Very Loud / Screaming)';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Monitor Settings'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            // 1. Noise & Cry Detection Section
            _buildSectionHeader('NOISE & CRY ALERTS', Icons.notifications_active_rounded),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF4F46E5),
                    title: const Text(
                      'Baby Cry & High Noise Alerts',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: const Text(
                      'Alerts parent phone when nursery noise exceeds threshold',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    value: _settings.isCryAlertEnabled,
                    onChanged: (val) => _update(_settings.copyWith(isCryAlertEnabled: val)),
                  ),
                  if (_settings.isCryAlertEnabled) ...[
                    const Divider(color: Colors.white12, height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Noise Threshold',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withOpacity(0.25),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF818CF8)),
                          ),
                          child: Text(
                            '${_settings.noiseThreshold.toInt()} dB',
                            style: const TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getThresholdLabel(_settings.noiseThreshold),
                      style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                    ),
                    const SizedBox(height: 10),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        activeTrackColor: const Color(0xFF4F46E5),
                        inactiveTrackColor: Colors.white12,
                        thumbColor: const Color(0xFF818CF8),
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
                        _buildPresetButton('Sensitive', 45.0),
                        _buildPresetButton('Normal', 60.0),
                        _buildPresetButton('Loud', 75.0),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF4F46E5),
                      title: const Text('Sound Alert Chime', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Play gentle alert tone on cry', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      value: _settings.isAudioChimeEnabled,
                      onChanged: (val) => _update(_settings.copyWith(isAudioChimeEnabled: val)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeColor: const Color(0xFF4F46E5),
                      title: const Text('Vibration Alert', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Vibrate parent phone on cry', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                      value: _settings.isVibrationEnabled,
                      onChanged: (val) => _update(_settings.copyWith(isVibrationEnabled: val)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 2. Background Execution & Lock Screen Persistence
            _buildSectionHeader('BACKGROUND & BATTERY', Icons.battery_charging_full_rounded),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF10B981),
                    title: const Text(
                      'Continuous Background Streaming',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Keep streaming audio and connection active even when phone is locked or app is minimized',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    value: _settings.isBackgroundMonitoringEnabled,
                    onChanged: (val) => _update(_settings.copyWith(isBackgroundMonitoringEnabled: val)),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: const Color(0xFF10B981),
                    title: const Text(
                      'Keep Screen Awake',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    subtitle: const Text(
                      'Prevents the display from automatically sleeping during live monitoring',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                    value: _settings.keepScreenAwake,
                    onChanged: (val) => _update(_settings.copyWith(keepScreenAwake: val)),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF10B981),
                      side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    ),
                    icon: const Icon(Icons.security_rounded, size: 20),
                    label: const Text(
                      'Grant Background & Battery Exemptions',
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

            // 3. App Info & Security
            _buildSectionHeader('ABOUT IBNIK', Icons.info_outline_rounded),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text('🍼', style: TextStyle(fontSize: 22)),
                      SizedBox(width: 10),
                      Text(
                        'Ibnik Baby Monitor',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Spacer(),
                      Text('v1.0.7', style: TextStyle(color: Color(0xFF818CF8), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Sub-second latency • End-to-End Encrypted (DTLS-SRTP) • 100% Free & Open Source',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  const Divider(color: Colors.white12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Target Platform', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('Android 16 (API 36)', style: TextStyle(color: Colors.green[400], fontWeight: FontWeight.bold, fontSize: 13)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Encryption', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('P2P DTLS-SRTP', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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

  Widget _buildPresetButton(String label, double value) {
    final isSelected = (_settings.noiseThreshold - value).abs() < 3.0;
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: isSelected ? Colors.white : const Color(0xFF94A3B8),
        backgroundColor: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
        side: BorderSide(color: isSelected ? const Color(0xFF4F46E5) : Colors.white24),
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF818CF8), size: 16),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF818CF8),
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
