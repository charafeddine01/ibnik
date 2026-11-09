import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/models/peer_role.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_registry_service.dart';
import '../auth/login_screen.dart';
import '../baby_unit/baby_unit_screen.dart';
import '../pairing/baby_qr_scanner_screen.dart';
import '../pairing/parent_pairing_screen.dart';
import '../pairing/pairing_screen.dart';
import '../parent_unit/parent_unit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final DeviceRegistryService _registryService = DeviceRegistryService();
  List<Map<String, String>> _pairedCameras = [];
  bool _isLoadingCameras = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadPairedCameras());
  }

  Future<void> _loadPairedCameras() async {
    final list = await _registryService.getPairedCamerasLocal();
    if (mounted) {
      setState(() {
        _pairedCameras = list;
        _isLoadingCameras = false;
      });
    }
  }

  @override
  void dispose() {
    _registryService.dispose();
    super.dispose();
  }

  Future<void> _onStartBabyUnit() async {
    final savedChannel = await _registryService.getMyBabyChannel();
    if (!mounted) return;

    if (savedChannel == null) {
      // First time: Baby phone scans the QR code from Parent phone
      final nav = Navigator.of(context);
      unawaited(
        nav
            .push(
              MaterialPageRoute<void>(builder: (_) => const BabyQrScannerScreen()),
            )
            .then((_) {
              unawaited(_loadPairedCameras());
            }),
      );
    } else {
      // Already paired: Start nursery camera immediately
      final name = await _registryService.getMyBabyName();
      if (!mounted) return;
      final nav = Navigator.of(context);
      unawaited(
        nav
            .push(
              MaterialPageRoute<void>(
                builder: (_) => BabyUnitScreen(
                  roomId: savedChannel,
                  deviceName: name,
                ),
              ),
            )
            .then((_) {
              unawaited(_loadPairedCameras());
            }),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final isEmailVerified = _authService.isEmailVerified;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Account Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Text('🍼', style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ibnik',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                          ),
                          Text(
                            user?.email ?? 'Free Baby Monitor',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Sign Out Button (if logged in)
                  if (user != null)
                    IconButton(
                      style: IconButton.styleFrom(backgroundColor: Colors.white10),
                      icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                      tooltip: 'Sign Out',
                      onPressed: () async {
                        final nav = Navigator.of(context);
                        await _authService.signOut();
                        if (mounted) {
                          unawaited(nav.pushReplacement(
                            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                          ));
                        }
                      },
                    ),
                ],
              ),

              // Email Verification Alert Banner (if unverified)
              if (user != null && user.email != null && !isEmailVerified) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.mark_email_unread_outlined, color: Colors.amber, size: 20),
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

              const SizedBox(height: 32),

              // Paired Baby Cameras Section (Permanent Pairing)
              const Text(
                'Paired Baby Cameras',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Your permanently linked nursery cameras. Connect anytime from any network.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 16),

              if (_isLoadingCameras)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
                  ),
                )
              else if (_pairedCameras.isEmpty)
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B).withOpacity(0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.qr_code_scanner, color: Color(0xFF818CF8), size: 24),
                      SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'No cameras paired yet. Tap "Pair Baby Camera (Show QR)" below, then scan with your baby phone.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              else
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
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isOnline ? Colors.green.withOpacity(0.4) : Colors.white12,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.child_care_rounded,
                                  color: isOnline ? Colors.greenAccent : Colors.white38,
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
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: isOnline ? Colors.greenAccent : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          isOnline ? 'Online • $battery%' : 'Offline',
                                          style: TextStyle(
                                            color: isOnline ? Colors.greenAccent : Colors.white38,
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
                                  backgroundColor: const Color(0xFF4F46E5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                                child: const Text('Connect', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                                tooltip: 'Unpair Camera',
                                onPressed: () async {
                                  await _registryService.removePairedCameraLocal(channelId);
                                  await _loadPairedCameras();
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 36),

              const Text(
                'Set Up Devices',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Pair a new baby camera or configure this phone as the nursery unit.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 18),

              // 1. Pair Baby Camera (Show QR on Parent Phone)
              _buildRoleCard(
                context,
                title: 'Pair Baby Camera (Show QR)',
                subtitle: 'Display pairing QR code for the baby phone to scan and link forever.',
                icon: Icons.qr_code_2_rounded,
                color: const Color(0xFF4F46E5),
                onTap: () {
                  final nav = Navigator.of(context);
                  unawaited(
                    nav
                        .push(
                          MaterialPageRoute<void>(builder: (_) => const ParentPairingScreen()),
                        )
                        .then((_) {
                          unawaited(_loadPairedCameras());
                        }),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 2. Baby Unit (Nursery Camera)
              _buildRoleCard(
                context,
                title: 'Baby Unit (Nursery Camera)',
                subtitle: 'Streams HD video & audio, detects sound/cries, and plays lullabies.',
                icon: Icons.videocam_rounded,
                color: const Color(0xFF10B981),
                onTap: () {
                  unawaited(_onStartBabyUnit());
                },
              ),

              const SizedBox(height: 16),

              // 3. Local Wi-Fi Pairing (Direct offline LAN fallback)
              _buildRoleCard(
                context,
                title: 'Local Wi-Fi Mode (Offline)',
                subtitle: 'Direct local pairing without cloud servers.',
                icon: Icons.wifi_rounded,
                color: const Color(0xFF06B6D4),
                onTap: () => _showLocalWifiDialog(context),
              ),

              const SizedBox(height: 32),

              Center(
                child: Text(
                  'End-to-End Encrypted (DTLS-SRTP)\nibnik.charafeddine.xyz',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }

  void _showLocalWifiDialog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Local Wi-Fi Mode (Offline)',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select this phone\'s role for direct offline Wi-Fi streaming.',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Option 1: Baby Unit (Nursery Camera)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PairingScreen(role: PeerRole.baby),
                      ),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.videocam_rounded, color: Color(0xFF10B981), size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Nursery Camera (Baby Unit)',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Displays 6-digit PIN & QR code for the Parent Phone to connect.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white38),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Option 2: Parent Unit (Monitor)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    unawaited(Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const PairingScreen(role: PeerRole.parent),
                      ),
                    ));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF06B6D4).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.smartphone_rounded, color: Color(0xFF06B6D4), size: 28),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Parent Unit (Monitor)',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Enter the 6-digit PIN or scan the QR code from the Baby Phone.',
                                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.white38),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        );
      },
    );
  }
}
