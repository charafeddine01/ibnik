import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/peer_role.dart';
import '../../core/utils/network_utils.dart';
import '../baby_unit/baby_unit_screen.dart';
import '../parent_unit/parent_unit_screen.dart';

class PairingScreen extends StatefulWidget {
  final PeerRole role;

  const PairingScreen({super.key, required this.role});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  late final String _roomId;
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _ipController = TextEditingController();
  bool _isScanning = false;
  bool _showAdvancedIp = false;
  String? _localIp;

  @override
  void initState() {
    super.initState();
    _roomId = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
    _fetchLocalIp();
  }

  Future<void> _fetchLocalIp() async {
    final ip = await NetworkUtils.getLocalIpAddress();
    if (mounted) {
      setState(() => _localIp = ip);
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  void _connectAsParent({
    required String targetRoomId,
    String? targetIp,
    int targetPort = 8888,
  }) {
    if (targetRoomId.trim().isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ParentUnitScreen(
          roomId: targetRoomId.trim(),
          targetIp: targetIp?.trim().isEmpty ?? true ? null : targetIp!.trim(),
          targetPort: targetPort,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBaby = widget.role == PeerRole.baby;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(isBaby ? 'Set Up Baby Unit' : 'Connect Parent Unit'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: isBaby ? _buildBabyPairing() : _buildParentPairing(),
        ),
      ),
    );
  }

  Widget _buildBabyPairing() {
    final qrPayload = jsonEncode({
      'app': 'ibnik',
      'room_id': _roomId,
      'ip': _localIp ?? '',
      'port': 8888,
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Pair with Parent Device',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scan this QR code with the Parent Phone for instant sub-second connection.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              )
            ],
          ),
          child: QrImageView(
            data: qrPayload,
            version: QrVersions.auto,
            size: 220,
          ),
        ),
        const SizedBox(height: 24),

        // Room PIN Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
          ),
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Room PIN: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
                  Text(
                    _roomId,
                    style: const TextStyle(
                      color: Color(0xFF818CF8),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                ],
              ),
              if (_localIp != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Wi-Fi IP: $_localIp:8888',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => BabyUnitScreen(roomId: _roomId),
                ),
              );
            },
            child: const Text(
              'Start Baby Camera',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParentPairing() {
    if (_isScanning) {
      return SizedBox(
        height: 400,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              MobileScanner(
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  for (final barcode in barcodes) {
                    if (barcode.rawValue != null) {
                      try {
                        final data = jsonDecode(barcode.rawValue!) as Map<String, dynamic>;
                        if (data.containsKey('room_id')) {
                          setState(() => _isScanning = false);
                          final scannedRoom = data['room_id'] as String;
                          final scannedIp = data['ip'] as String?;
                          final scannedPort = (data['port'] as int?) ?? 8888;
                          _connectAsParent(
                            targetRoomId: scannedRoom,
                            targetIp: scannedIp,
                            targetPort: scannedPort,
                          );
                          break;
                        }
                      } catch (_) {
                        // Raw PIN string fallback
                        setState(() => _isScanning = false);
                        _connectAsParent(targetRoomId: barcode.rawValue!);
                        break;
                      }
                    }
                  }
                },
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  style: IconButton.styleFrom(backgroundColor: Colors.black54),
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => setState(() => _isScanning = false),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 10),
        const Text(
          'Connect to Baby Unit',
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Scan the QR code displayed on the baby device or enter the room code.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 32),

        // 1. Scan QR Button (Recommended)
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
            label: const Text(
              'Scan QR Code (Instant Connect)',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            onPressed: () => setState(() => _isScanning = true),
          ),
        ),

        const SizedBox(height: 28),
        Row(
          children: [
            const Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR CONNECT BY PIN', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
            ),
            const Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 28),

        // 2. Room Code Input
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 4,
          ),
          decoration: InputDecoration(
            counterText: '',
            hintText: 'Enter 6-Digit PIN',
            hintStyle: const TextStyle(color: Colors.white38, fontSize: 16, letterSpacing: 1),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Advanced Direct IP Toggle
        GestureDetector(
          onTap: () => setState(() => _showAdvancedIp = !_showAdvancedIp),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _showAdvancedIp ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  color: Colors.white54,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Text(
                  _showAdvancedIp ? 'Hide Direct IP' : 'Enter Baby IP Directly (Optional)',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ),
          ),
        ),

        if (_showAdvancedIp) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _ipController,
            keyboardType: TextInputType.datetime,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'e.g. 192.168.1.50',
              hintStyle: const TextStyle(color: Colors.white38, fontSize: 14),
              prefixIcon: const Icon(Icons.settings_ethernet, color: Colors.white38, size: 20),
              filled: true,
              fillColor: const Color(0xFF1E293B),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              final pin = _pinController.text.trim();
              if (pin.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter the 6-digit room PIN')),
                );
                return;
              }
              final directIp = _ipController.text.trim();
              _connectAsParent(
                targetRoomId: pin,
                targetIp: directIp.isEmpty ? null : directIp,
              );
            },
            child: const Text(
              'Connect with Room Code',
              style: TextStyle(color: Color(0xFF818CF8), fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}
