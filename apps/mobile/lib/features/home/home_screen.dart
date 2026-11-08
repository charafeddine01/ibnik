import 'package:flutter/material.dart';
import '../../core/models/peer_role.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/device_registry_service.dart';
import '../auth/login_screen.dart';
import '../baby_unit/baby_unit_screen.dart';
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

  @override
  void dispose() {
    _registryService.dispose();
    super.dispose();
  }

  void _showSetupBabyDialog(String userId) {
    final controller = TextEditingController(text: 'Nursery Camera');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Set Up Baby Camera', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Give this nursery camera a name. It will be linked to your account forever.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'e.g. Baby Room, Nursery, Crib',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            onPressed: () {
              final name = controller.text.trim().isEmpty ? 'Nursery Camera' : controller.text.trim();
              Navigator.pop(ctx);
              const deviceId = 'baby_camera_1';
              final callId = '${userId}_$deviceId';
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => BabyUnitScreen(
                    roomId: callId,
                    userId: userId,
                    deviceId: deviceId,
                    deviceName: name,
                  ),
                ),
              );
            },
            child: const Text('Start Camera', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
                            user?.email ?? 'Logged In',
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Sign Out Button
                  IconButton(
                    style: IconButton.styleFrom(backgroundColor: Colors.white10),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white70, size: 20),
                    tooltip: 'Sign Out',
                    onPressed: () async {
                      await _authService.signOut();
                      if (mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                        );
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
                          await _authService.sendEmailVerification();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
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

              // Paired Baby Cameras Section (The "Add Baby Forever" Feature)
              if (user != null) ...[
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

                StreamBuilder<List<BabyDevice>>(
                  stream: _registryService.watchPairedBabyDevices(user.uid),
                  builder: (context, snapshot) {
                    final devices = snapshot.data ?? [];

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(color: Color(0xFF4F46E5), strokeWidth: 2),
                        ),
                      );
                    }

                    if (devices.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B).withOpacity(0.5),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.white38, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No baby cameras paired yet. Tap "Baby Unit" below on your second phone to add it permanently.',
                                style: TextStyle(color: Colors.white60, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return Column(
                      children: devices.map((device) {
                        final callId = '${user.uid}_${device.id}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: device.isOnline ? Colors.green.withOpacity(0.4) : Colors.white12,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: (device.isOnline ? Colors.green : Colors.grey).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.child_care_rounded,
                                  color: device.isOnline ? Colors.greenAccent : Colors.white38,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      device.name,
                                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          decoration: BoxDecoration(
                                            color: device.isOnline ? Colors.greenAccent : Colors.grey,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          device.isOnline ? 'Online • ${device.batteryLevel}%' : 'Offline',
                                          style: TextStyle(
                                            color: device.isOnline ? Colors.greenAccent : Colors.white38,
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
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => ParentUnitScreen(
                                        roomId: callId,
                                        deviceName: device.name,
                                        isCloudCall: true,
                                      ),
                                    ),
                                  );
                                },
                                child: const Text('Connect', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],

              const SizedBox(height: 36),

              const Text(
                'Add Or Set Up Device',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Configure this device as a nursery camera or pair a new monitor.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
              ),
              const SizedBox(height: 18),

              // 1. Baby Unit Card
              _buildRoleCard(
                context,
                title: 'Baby Unit (Nursery Camera)',
                subtitle: 'Streams HD video & audio, monitors sound/cries, and plays lullabies.',
                icon: Icons.videocam_rounded,
                color: const Color(0xFF4F46E5),
                onTap: () {
                  if (user != null) {
                    _showSetupBabyDialog(user.uid);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const PairingScreen(role: PeerRole.baby)),
                    );
                  }
                },
              ),

              const SizedBox(height: 16),

              // 2. Local Wi-Fi Pairing (Optional direct fallback)
              _buildRoleCard(
                context,
                title: 'Pair via QR / Local Wi-Fi',
                subtitle: 'Direct local pairing without cloud accounts.',
                icon: Icons.qr_code_scanner_rounded,
                color: const Color(0xFF06B6D4),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => const PairingScreen(role: PeerRole.parent)),
                  );
                },
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
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
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
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: color, size: 22),
          ],
        ),
      ),
    );
  }
}
