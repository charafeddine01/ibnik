import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_registry_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_theme.dart';
import '../auth/login_screen.dart';
import '../baby_unit/baby_unit_screen.dart';
import '../pairing/baby_qr_scanner_screen.dart';
import '../pairing/parent_pairing_screen.dart';
import '../parent_unit/parent_unit_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DeviceRegistryService _registryService = DeviceRegistryService();
  final SettingsService _settingsService = SettingsService();

  List<Map<String, String>> _pairedCameras = [];
  String? _myBabyChannel;
  String? _myBabyName;
  StreamSubscription<DocumentSnapshot>? _incomingCallSubscription;
  bool _isLoadingCameras = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPairedCameras());
  }

  Future<void> _loadPairedCameras() async {
    final list = await _registryService.getPairedCamerasLocal();
    final myChannel = await _registryService.getMyBabyChannel();
    final myName = await _registryService.getMyBabyName();

    if (myChannel != null) {
      unawaited(_registryService.registerChannel(
        channelId: myChannel,
        name: myName,
      ));
      _registryService.startChannelHeartbeat(
        channelId: myChannel,
        getBatteryLevel: () => 100,
        getIsCharging: () => false,
      );

      _listenForIncomingParentCall(myChannel, myName);
    }

    if (mounted) {
      setState(() {
        _pairedCameras = list;
        _myBabyChannel = myChannel;
        _myBabyName = myName;
        _isLoadingCameras = false;
      });
    }
  }

  void _listenForIncomingParentCall(String channelId, String cameraName) {
    if (!_registryService.isFirebaseAvailable) return;
    _incomingCallSubscription?.cancel();
    _incomingCallSubscription = FirebaseFirestore.instance
        .collection('calls')
        .doc(channelId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      final status = data?['status'] as String?;
      if (status == 'calling') {
        debugPrint('HomeScreen: Incoming call from Parent Unit! Auto-launching Nursery Camera...');
        _incomingCallSubscription?.cancel();
        if (!mounted) return;
        final nav = Navigator.of(context);
        unawaited(nav.push(
          MaterialPageRoute<void>(
            builder: (_) => BabyUnitScreen(
              roomId: channelId,
              deviceName: cameraName,
            ),
          ),
        ).then((_) {
          unawaited(_loadPairedCameras());
        }));
      }
    }, onError: (Object e) {
      debugPrint('HomeScreen: Incoming call listener notice: $e');
    });
  }

  @override
  void dispose() {
    _incomingCallSubscription?.cancel();
    _registryService.dispose();
    super.dispose();
  }

  Future<void> _onStartBabyUnit() async {
    final savedChannel = await _registryService.getMyBabyChannel();
    if (!mounted) return;

    if (savedChannel == null) {
      final nav = Navigator.of(context);
      unawaited(
        nav.push(
          MaterialPageRoute<void>(builder: (_) => const BabyQrScannerScreen()),
        ).then((_) {
          unawaited(_loadPairedCameras());
        }),
      );
    } else {
      final name = await _registryService.getMyBabyName();
      if (!mounted) return;
      final nav = Navigator.of(context);
      unawaited(
        nav.push(
          MaterialPageRoute<void>(
            builder: (_) => BabyUnitScreen(
              roomId: savedChannel,
              deviceName: name,
            ),
          ),
        ).then((_) {
          unawaited(_loadPairedCameras());
        }),
      );
    }
  }

  Future<void> _confirmSignOut(BuildContext context, AppThemeColors colors) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.border),
        ),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 24),
            const SizedBox(width: 10),
            Text(
              'Log Out',
              style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out of your Ibnik account?',
          style: TextStyle(color: colors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: colors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      final nav = Navigator.of(context);
      await _authService.signOut();
      if (mounted) {
        unawaited(nav.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        ));
      }
    }
  }

  void _showRoleSelectorDialog(AppThemeColors colors) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: colors.border),
        ),
        title: Center(
          child: Text(
            'Select Device Role',
            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'How are you using this phone?',
              style: TextStyle(color: colors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await _settingsService.setDeviceRole('parent');
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.primary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.family_restroom_rounded, color: colors.primary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Parent Phone (Monitor)',
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Watch baby, receive noise & cry alerts, and talk back.',
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                Navigator.pop(ctx);
                await _settingsService.setDeviceRole('baby');
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors.secondary.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colors.secondary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.videocam_rounded, color: colors.secondary, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Baby Phone (Camera)',
                            style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Place in nursery room to stream HD video & audio.',
                            style: TextStyle(color: colors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isEmailVerified = _authService.isEmailVerified;

    return ValueListenableBuilder<MonitorSettings>(
      valueListenable: _settingsService.settingsNotifier,
      builder: (context, settings, _) {
        final colors = AppThemeColors.of(settings.appThemeMode);
        final isBabyRole = settings.deviceRole == 'baby';

        return Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Account Header & Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: colors.primary.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: colors.primary.withOpacity(0.3)),
                            ),
                            child: const Text('🍼', style: TextStyle(fontSize: 24)),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Ibnik',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                user?.email ?? 'Baby Monitor',
                                style: TextStyle(color: colors.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // Top Quick Action Icons: Settings & Sign Out
                      Row(
                        children: [
                          IconButton(
                            style: IconButton.styleFrom(backgroundColor: colors.surfaceVariant),
                            icon: Icon(Icons.settings_outlined, color: colors.primary, size: 20),
                            tooltip: 'Settings (Noise Alert, Background, Theme)',
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
                              );
                            },
                          ),
                          if (user != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              style: IconButton.styleFrom(backgroundColor: colors.surfaceVariant),
                              icon: Icon(Icons.logout_rounded, color: colors.textSecondary, size: 20),
                              tooltip: 'Sign Out',
                              onPressed: () => _confirmSignOut(context, colors),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),

                  // Email Verification Warning Banner
                  if (user != null && user.email != null && !isEmailVerified) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_email_unread_outlined, color: Colors.amber, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Email not verified. Check your inbox.',
                              style: TextStyle(color: Colors.amber, fontSize: 12),
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await _authService.sendEmailVerification();
                              if (mounted) {
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Verification email resent! Check your inbox.')),
                                );
                              }
                            },
                            child: const Text('Resend', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 20),

                  // 2. Clear Role Switcher: Parent Phone vs Baby Phone (Task 3)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.surfaceVariant,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: colors.border),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _settingsService.setDeviceRole('parent');
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isBabyRole ? colors.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: !isBabyRole
                                    ? [
                                        BoxShadow(
                                          color: colors.primary.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.family_restroom_rounded,
                                    size: 18,
                                    color: !isBabyRole ? Colors.white : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Parent Phone',
                                    style: TextStyle(
                                      color: !isBabyRole ? Colors.white : colors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _settingsService.setDeviceRole('baby');
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isBabyRole ? colors.secondary : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: isBabyRole
                                    ? [
                                        BoxShadow(
                                          color: colors.secondary.withOpacity(0.35),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.videocam_rounded,
                                    size: 18,
                                    color: isBabyRole ? Colors.white : colors.textSecondary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Baby Phone',
                                    style: TextStyle(
                                      color: isBabyRole ? Colors.white : colors.textSecondary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // 3. Conditional Content Based on Selected Role (Task 3)
                  if (!isBabyRole)
                    // ==========================================
                    // PARENT PHONE MODE
                    // ==========================================
                    _buildParentPhoneView(context, colors, settings)
                  else
                    // ==========================================
                    // BABY PHONE MODE
                    // ==========================================
                    _buildBabyPhoneView(context, colors),

                  const SizedBox(height: 32),

                  // Footer Note
                  Center(
                    child: Text(
                      'End-to-End Encrypted (DTLS-SRTP)\ncharafeddine01.github.io/ibnik',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.textSecondary.withOpacity(0.5), fontSize: 11, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // =========================================================================
  // PARENT PHONE VIEW
  // =========================================================================
  Widget _buildParentPhoneView(BuildContext context, AppThemeColors colors, MonitorSettings settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Quick Settings Banner (Task 1: Ensures settings & noise threshold are instantly accessible)
        InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.border),
            ),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, color: colors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Cry Alert: ',
                            style: TextStyle(color: colors.textSecondary, fontSize: 12),
                          ),
                          Text(
                            settings.isCryAlertEnabled ? '${settings.noiseThreshold.toInt()} dB' : 'OFF',
                            style: TextStyle(
                              color: settings.isCryAlertEnabled ? colors.primary : colors.textSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '• Background: Active',
                            style: TextStyle(color: colors.secondary, fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap to adjust sensitivity threshold, alarms & battery settings',
                        style: TextStyle(color: colors.textSecondary.withOpacity(0.8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: colors.textSecondary, size: 20),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        // Paired Baby Cameras Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paired Baby Cameras',
              style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              icon: Icon(Icons.add, size: 16, color: colors.primary),
              label: Text('Pair New', style: TextStyle(color: colors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
              onPressed: () {
                final nav = Navigator.of(context);
                unawaited(
                  nav.push(
                    MaterialPageRoute<void>(builder: (_) => const ParentPairingScreen()),
                  ).then((_) {
                    unawaited(_loadPairedCameras());
                  }),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Connect anytime to watch live video and hear your baby.',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 14),

        if (_isLoadingCameras)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: CircularProgressIndicator(color: colors.primary, strokeWidth: 2),
            ),
          )
        else if (_pairedCameras.isEmpty)
          // Empty State: No Cameras Paired
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: colors.border),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colors.primary.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.qr_code_2_rounded, color: colors.primary, size: 36),
                ),
                const SizedBox(height: 14),
                Text(
                  'No Baby Cameras Paired',
                  style: TextStyle(color: colors.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Pair with your baby phone to start streaming. Tap below to show the pairing QR code.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.qr_code_rounded, size: 20),
                    label: const Text('Pair Baby Camera (Show QR)', style: TextStyle(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final nav = Navigator.of(context);
                      unawaited(
                        nav.push(
                          MaterialPageRoute<void>(builder: (_) => const ParentPairingScreen()),
                        ).then((_) {
                          unawaited(_loadPairedCameras());
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          )
        else
          // Cameras List
          Column(
            children: _pairedCameras.map((camera) {
              final channelId = camera['id']!;
              final fallbackName = camera['name'] ?? 'Nursery Camera';

              return StreamBuilder<BabyDevice?>(
                stream: _registryService.watchChannel(channelId),
                builder: (context, snapshot) {
                  final device = snapshot.data;
                  final isOnline = device?.isOnline ?? false;
                  final battery = device?.batteryLevel ?? 100;
                  final displayName = device?.name ?? fallbackName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isOnline ? colors.secondary.withOpacity(0.5) : colors.border,
                        width: isOnline ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (isOnline ? colors.secondary : colors.textSecondary).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.child_care_rounded,
                            color: isOnline ? colors.secondary : colors.textSecondary,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isOnline ? colors.secondary : colors.primary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    isOnline ? 'Online • $battery%' : 'Standby / Sleep',
                                    style: TextStyle(
                                      color: isOnline ? colors.secondary : colors.textSecondary,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            elevation: 0,
                          ),
                          onPressed: () {
                            unawaited(Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => ParentUnitScreen(
                                  roomId: channelId,
                                  deviceName: displayName,
                                  isCloudCall: true,
                                ),
                              ),
                            ));
                          },
                          child: const Text('Connect', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: colors.textSecondary.withOpacity(0.6), size: 20),
                          tooltip: 'Unpair Camera',
                          onPressed: () async {
                            final shouldDelete = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: colors.surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                title: Text('Unpair $displayName?', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold)),
                                content: Text('This camera will be removed from this phone.', style: TextStyle(color: colors.textSecondary)),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Unpair'),
                                  ),
                                ],
                              ),
                            );
                            if (shouldDelete == true) {
                              await _registryService.removePairedCameraLocal(channelId);
                              await _loadPairedCameras();
                            }
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            }).toList(),
          ),
      ],
    );
  }

  // =========================================================================
  // BABY PHONE VIEW
  // =========================================================================
  Widget _buildBabyPhoneView(BuildContext context, AppThemeColors colors) {
    final isConfigured = _myBabyChannel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Nursery Camera Unit',
          style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Keep this phone in the nursery room facing your baby.',
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 16),

        // Main Baby Unit Card
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isConfigured ? colors.secondary.withOpacity(0.5) : colors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors.secondary.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.videocam_rounded, color: colors.secondary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _myBabyName ?? 'Nursery Camera',
                          style: TextStyle(color: colors.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isConfigured ? 'Standby • Ready to stream' : 'Not paired yet',
                          style: TextStyle(
                            color: isConfigured ? colors.secondary : colors.textSecondary,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isConfigured)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: colors.secondary.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: colors.secondary, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('Ready', style: TextStyle(color: colors.secondary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                isConfigured
                    ? 'When the Parent Phone connects, this device will automatically stream HD video & audio.'
                    : 'To link this phone as the nursery camera, tap below and scan the QR code displayed on the Parent Phone.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.secondary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  icon: Icon(isConfigured ? Icons.play_arrow_rounded : Icons.qr_code_scanner_rounded, size: 22),
                  label: Text(
                    isConfigured ? 'Open Camera Feed Now' : 'Scan Parent QR Code',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  onPressed: () => _onStartBabyUnit(),
                ),
              ),
              if (isConfigured) ...[
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      await _registryService.clearMyBabyChannel();
                      await _loadPairedCameras();
                    },
                    child: Text('Reset Pairing / Re-pair', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Helpful Nursery Tips
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: colors.surfaceVariant,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💡 Nursery Camera Tips',
                style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              _buildTipRow('🔌', 'Keep phone connected to charger during monitoring', colors),
              const SizedBox(height: 8),
              _buildTipRow('🔒', 'Streaming stays active in the background even if screen locks', colors),
              const SizedBox(height: 8),
              _buildTipRow('📐', 'Position phone 1–2 meters from baby\'s crib', colors),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTipRow(String emoji, String text, AppThemeColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: colors.textSecondary, fontSize: 12, height: 1.3)),
        ),
      ],
    );
  }
}
