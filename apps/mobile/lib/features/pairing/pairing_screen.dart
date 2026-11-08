import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/models/peer_role.dart';
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
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    // Generate a clean 6-digit room PIN
    _roomId = (100000 + (DateTime.now().millisecondsSinceEpoch % 900000)).toString();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _connectAsParent(String targetRoomId) {
    if (targetRoomId.trim().isEmpty) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ParentUnitScreen(roomId: targetRoomId.trim()),
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
      'room_id': _roomId,
      'app': 'babymonitor',
      'host': 'signal.charafeddine.xyz',
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
          'Scan this QR code with your parent phone, or enter the 6-digit code below.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 32),
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
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Room Code: ', style: TextStyle(color: Colors.white70, fontSize: 16)),
              Text(
                _roomId,
                style: const TextStyle(
                  color: Color(0xFF818CF8),
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 40),
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
                MaterialPageRoute(
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
                          _connectAsParent(data['room_id'] as String);
                          break;
                        }
                      } catch (_) {
                        // Raw PIN string
                        setState(() => _isScanning = false);
                        _connectAsParent(barcode.rawValue!);
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
          'Scan the QR code displayed on the baby device or enter the 6-digit room PIN.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Color(0xFF818CF8)),
            label: const Text('Scan QR Code with Camera', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            onPressed: () => setState(() => _isScanning = true),
          ),
        ),
        const SizedBox(height: 30),
        const Row(
          children: [
            Expanded(child: Divider(color: Colors.white24)),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR ENTER PIN', style: TextStyle(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider(color: Colors.white24)),
          ],
        ),
        const SizedBox(height: 30),
        TextField(
          controller: _pinController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 28, letterSpacing: 8, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            counterText: '',
            hintText: '000000',
            hintStyle: const TextStyle(color: Colors.white24, fontSize: 28, letterSpacing: 8),
            filled: true,
            fillColor: const Color(0xFF1E293B),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 2),
            ),
          ),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => _connectAsParent(_pinController.text),
            child: const Text('Connect to Monitor', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
