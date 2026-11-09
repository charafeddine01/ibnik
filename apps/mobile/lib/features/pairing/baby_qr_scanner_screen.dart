import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/services/device_registry_service.dart';
import '../baby_unit/baby_unit_screen.dart';

class BabyQrScannerScreen extends StatefulWidget {
  const BabyQrScannerScreen({super.key});

  @override
  State<BabyQrScannerScreen> createState() => _BabyQrScannerScreenState();
}

class _BabyQrScannerScreenState extends State<BabyQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );
  final DeviceRegistryService _registryService = DeviceRegistryService();
  bool _hasScanned = false;

  @override
  void dispose() {
    _controller.dispose();
    _registryService.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_hasScanned) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      String channelId = raw;
      String cameraName = 'Nursery Camera';

      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data.containsKey('channel_id')) {
          channelId = data['channel_id'] as String;
          if (data.containsKey('name')) {
            cameraName = data['name'] as String;
          }
        }
      } catch (_) {
        // Raw channelId string fallback
      }

      if (channelId.isNotEmpty) {
        setState(() => _hasScanned = true);
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);
        await _controller.stop();

        // 1. Save locally so this Baby Phone remembers its pairing forever
        await _registryService.saveMyBabyChannel(channelId: channelId, name: cameraName);

        // 2. Notify Parent over Firestore
        await _registryService.registerChannel(
          channelId: channelId,
          name: cameraName,
          batteryLevel: 100,
          isCharging: false,
        );

        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: Colors.green[800],
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Paired successfully! Starting Nursery Camera...'),
                ],
              ),
            ),
          );

          nav.pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => BabyUnitScreen(
                roomId: channelId,
                deviceName: cameraName,
              ),
            ),
          );
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Camera QR Scanner
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleBarcode,
            ),
          ),

          // 2. Translucent Framing Overlay
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.4),
              child: Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFF4F46E5), width: 3),
                    borderRadius: BorderRadius.circular(24),
                    color: Colors.transparent,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF4F46E5).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 3. Top Instructions & Back Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      IconButton(
                        style: IconButton.styleFrom(backgroundColor: Colors.black54),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Pair with Parent Phone',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.qr_code_scanner, color: Color(0xFF818CF8), size: 20),
                        SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Point camera at the QR code displayed on the Parent Phone',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontSize: 13),
                          ),
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
    );
  }
}
