import 'dart:async';
import 'dart:convert';
import 'dart:io';
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

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasScanned) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw == null || raw.isEmpty) continue;

      String channelId = raw.trim();
      String cameraName = 'Nursery Camera';
      String targetIp = '';
      int targetPort = 8899;

      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data.containsKey('pin')) {
          channelId = data['pin'].toString();
        } else if (data.containsKey('channel_id')) {
          channelId = data['channel_id'].toString();
        } else if (data.containsKey('room_id')) {
          channelId = data['room_id'].toString();
        }
        if (data.containsKey('name')) {
          cameraName = data['name'].toString();
        }
        if (data.containsKey('ip') && data['ip'] is String) {
          targetIp = data['ip'] as String;
        }
        if (data.containsKey('port') && data['port'] is num) {
          targetPort = (data['port'] as num).toInt();
        }
      } catch (_) {
        // Raw channelId / PIN string fallback
      }

      if (channelId.isNotEmpty) {
        _hasScanned = true;
        setState(() {});

        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_completePairing(channelId, cameraName, targetIp, targetPort));
        });
        break;
      }
    }
  }

  void _showManualPinDialog() {
    final pinController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Enter 6-Digit PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the PIN code displayed on the Parent Phone screen:',
              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 4, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              maxLength: 6,
              decoration: InputDecoration(
                hintText: '123456',
                hintStyle: const TextStyle(color: Colors.white24),
                filled: true,
                fillColor: const Color(0xFF0F172A),
                counterText: '',
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
              final pin = pinController.text.trim();
              if (pin.isNotEmpty) {
                Navigator.pop(ctx);
                _hasScanned = true;
                setState(() {});
                unawaited(_completePairing(pin, 'Nursery Camera', '', 8899));
              }
            },
            child: const Text('Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _completePairing(String channelId, String cameraName, String targetIp, int targetPort) async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. Direct local Wi-Fi handshake (if Parent phone is on the same local network)
      if (targetIp.isNotEmpty) {
        try {
          final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
          final uri = Uri.parse('http://$targetIp:$targetPort/pair?channel_id=$channelId&name=${Uri.encodeComponent(cameraName)}');
          final req = await client.getUrl(uri);
          final resp = await req.close();
          debugPrint('Direct local Wi-Fi pair notification response: ${resp.statusCode}');
        } catch (e) {
          debugPrint('Direct local Wi-Fi pair notice: $e');
        }
      }

      // 2. Save locally so this Baby Phone remembers its pairing forever
      await _registryService.saveMyBabyChannel(channelId: channelId, name: cameraName);

      // 3. Notify Parent over Firestore (with 4-second timeout for cloud fallback)
      try {
        await _registryService.registerChannel(
          channelId: channelId,
          name: cameraName,
          batteryLevel: 100,
          isCharging: false,
        ).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('registerChannel notice: $e');
      }

      // 4. Stop scanner cleanly before opening WebRTC camera
      try {
        await _controller.stop();
      } catch (e) {
        debugPrint('MobileScanner stop error: $e');
      }

      // 5. Short pause to ensure Android CameraX fully releases hardware camera
      await Future<void>.delayed(const Duration(milliseconds: 250));

      if (!mounted) return;
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

      unawaited(nav.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => BabyUnitScreen(
            roomId: channelId,
            deviceName: cameraName,
          ),
        ),
      ));
    } catch (e) {
      debugPrint('Error handling scanned barcode: $e');
      if (mounted) {
        unawaited(nav.pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => BabyUnitScreen(
              roomId: channelId,
              deviceName: cameraName,
            ),
          ),
        ));
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

          // 4. Manual PIN Button at Bottom
          if (!_hasScanned)
            Positioned(
              bottom: 36,
              left: 24,
              right: 24,
              child: SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF818CF8)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.pin, color: Color(0xFF818CF8)),
                  label: const Text(
                    'Enter 6-Digit PIN Manually',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  onPressed: _showManualPinDialog,
                ),
              ),
            ),

          // 5. Verification & Transition Loading Overlay
          if (_hasScanned)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.85),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: Color(0xFF10B981)),
                      SizedBox(height: 20),
                      Text(
                        'Device Linked!',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Starting Nursery Camera stream...',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
