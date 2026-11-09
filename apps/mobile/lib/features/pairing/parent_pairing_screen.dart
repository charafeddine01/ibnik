import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/device_registry_service.dart';
import '../../core/utils/network_utils.dart';
import '../parent_unit/parent_unit_screen.dart';

class ParentPairingScreen extends StatefulWidget {
  const ParentPairingScreen({super.key});

  @override
  State<ParentPairingScreen> createState() => _ParentPairingScreenState();
}

class _ParentPairingScreenState extends State<ParentPairingScreen> {
  final DeviceRegistryService _registryService = DeviceRegistryService();
  late final String _channelId;
  final TextEditingController _nameController = TextEditingController(text: 'Nursery Camera');
  StreamSubscription<DocumentSnapshot>? _subscription;
  HttpServer? _localPairingServer;
  String? _localIp;
  bool _isPaired = false;

  @override
  void initState() {
    super.initState();
    final randomPin = 100000 + Random().nextInt(900000);
    _channelId = randomPin.toString();

    _startLocalPairingServer();
    _initChannelListener();
  }

  Future<void> _startLocalPairingServer() async {
    try {
      _localIp = await NetworkUtils.getLocalIpAddress();
      if (mounted) setState(() {});

      _localPairingServer = await HttpServer.bind(InternetAddress.anyIPv4, 8899);
      _localPairingServer!.listen((HttpRequest request) async {
        final uri = request.uri;
        if (uri.path == '/pair' || uri.path == '/scanned') {
          final qChannel = uri.queryParameters['channel_id'] ?? _channelId;
          final qName = uri.queryParameters['name'] ?? _nameController.text.trim();

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'status': 'ok'}));
          await request.response.close();

          debugPrint('Local HTTP pairing signal received for channel: $qChannel');
          await _onDevicePaired(qChannel, qName);
        }
      });
    } catch (e) {
      debugPrint('Local pairing server notice: $e');
    }
  }

  void _initChannelListener() {
    if (!_registryService.isFirebaseAvailable) return;
    final docRef = FirebaseFirestore.instance.collection('channels').doc(_channelId);

    // Initialize channel waiting for baby scan (with 3-second timeout)
    unawaited(docRef.set({
      'channel_id': _channelId,
      'is_paired': false,
      'is_online': false,
      'name': _nameController.text.trim(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)).timeout(const Duration(seconds: 3)).catchError((Object e) {
      debugPrint('docRef.set notice: $e');
    }));

    _subscription = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data();
      if (data == null) return;
      final paired = data['is_paired'] == true;
      final online = data['is_online'] == true;

      if ((paired || online) && !_isPaired && mounted) {
        final rawName = data['name']?.toString();
        final cameraName = (rawName != null && rawName.isNotEmpty) ? rawName : _nameController.text.trim();
        await _onDevicePaired(_channelId, cameraName);
      }
    }, onError: (Object e) {
      debugPrint('Channel subscription error: $e');
    });
  }

  Future<void> _onDevicePaired(String channelId, String cameraName) async {
    if (_isPaired || !mounted) return;
    _isPaired = true;
    await _subscription?.cancel();
    try {
      await _localPairingServer?.close(force: true);
    } catch (_) {}

    await _registryService.savePairedCameraLocal(
      channelId: channelId,
      name: cameraName,
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    messenger.showSnackBar(
      SnackBar(
        backgroundColor: Colors.green[800],
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Paired with $cameraName successfully!')),
          ],
        ),
      ),
    );

    unawaited(nav.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ParentUnitScreen(
          roomId: channelId,
          deviceName: cameraName,
          isCloudCall: true,
        ),
      ),
    ));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    try {
      _localPairingServer?.close(force: true);
    } catch (_) {}
    _nameController.dispose();
    _registryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = jsonEncode({
      'app': 'ibnik',
      'channel_id': _channelId,
      'pin': _channelId,
      'name': _nameController.text.trim(),
      'ip': _localIp ?? '',
      'port': 8899,
    });

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Pair Baby Camera'),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 4),
              const Text(
                'Scan QR or Enter 6-Digit PIN',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'On your Baby Phone, open Ibnik, tap "Baby Unit", and scan this code or enter the 6-digit PIN.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              ),
              const SizedBox(height: 20),

              // QR Code Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.35),
                      blurRadius: 28,
                      spreadRadius: 3,
                    )
                  ],
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 220,
                ),
              ),
              const SizedBox(height: 18),

              // 6-Digit PIN Display Pill
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _channelId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('PIN $_channelId copied to clipboard!')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'PIN: ',
                        style: TextStyle(color: Color(0xFF94A3B8), fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _channelId,
                        style: const TextStyle(
                          color: Color(0xFF818CF8),
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.copy_rounded, color: Colors.white54, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // PRIMARY ACTION: Start Monitoring Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 4,
                  ),
                  icon: const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 24),
                  label: const Text(
                    'Baby Phone Scanned? Start Monitoring',
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _onDevicePaired(_channelId, _nameController.text.trim()),
                ),
              ),
              const SizedBox(height: 14),

              // Auto-Waiting Status Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF818CF8),
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Waiting for nursery camera to scan...',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Camera Name Field
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Camera Name',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  hintText: 'e.g., Nursery Camera, Crib, Playroom',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.videocam_outlined, color: Color(0xFF818CF8)),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) {
                  unawaited(_registryService.savePairedCameraLocal(
                    channelId: _channelId,
                    name: _nameController.text.trim(),
                  ));
                  setState(() {});
                },
              ),
              const SizedBox(height: 12),
              if (_localIp != null)
                Text(
                  'Local Network IP: $_localIp',
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
