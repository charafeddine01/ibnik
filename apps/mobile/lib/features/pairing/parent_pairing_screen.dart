import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/services/device_registry_service.dart';
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
  bool _isPaired = false;

  @override
  void initState() {
    super.initState();
    final randomSuffix = 1000 + Random().nextInt(9000);
    _channelId = 'ch_${DateTime.now().millisecondsSinceEpoch}_$randomSuffix';
    _initChannelListener();
  }

  void _initChannelListener() {
    if (!_registryService.isFirebaseAvailable) return;
    final docRef = FirebaseFirestore.instance.collection('channels').doc(_channelId);

    // Initialize channel waiting for baby scan
    unawaited(docRef.set({
      'channel_id': _channelId,
      'is_paired': false,
      'is_online': false,
      'name': _nameController.text.trim(),
      'created_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)));

    _subscription = docRef.snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final paired = data['is_paired'] as bool? ?? false;
      final online = data['is_online'] as bool? ?? false;

      if ((paired || online) && !_isPaired && mounted) {
        _isPaired = true;
        await _subscription?.cancel();

        final String? rawName = data['name'] as String?;
        final cameraName = (rawName != null && rawName.isNotEmpty) ? rawName : _nameController.text.trim();

        if (!mounted) return;
        final messenger = ScaffoldMessenger.of(context);
        final nav = Navigator.of(context);

        await _registryService.savePairedCameraLocal(
          channelId: _channelId,
          name: cameraName,
        );

        if (mounted) {
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

          nav.pushReplacement(
            MaterialPageRoute<void>(
              builder: (_) => ParentUnitScreen(
                roomId: _channelId,
                deviceName: cameraName,
                isCloudCall: true,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _nameController.dispose();
    _registryService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrPayload = jsonEncode({
      'app': 'ibnik',
      'channel_id': _channelId,
      'name': _nameController.text.trim(),
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
              const SizedBox(height: 8),
              const Text(
                'Scan this QR from Baby Phone',
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Open Ibnik on your nursery phone, tap "Baby Unit", and point its camera at this screen.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
              ),
              const SizedBox(height: 28),

              // QR Code Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withOpacity(0.35),
                      blurRadius: 30,
                      spreadRadius: 4,
                    )
                  ],
                ),
                child: QrImageView(
                  data: qrPayload,
                  version: QrVersions.auto,
                  size: 240,
                ),
              ),
              const SizedBox(height: 24),

              // Waiting Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.5)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: Color(0xFF818CF8),
                        strokeWidth: 2,
                      ),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Waiting for Baby Phone to scan...',
                      style: TextStyle(color: Color(0xFF818CF8), fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Camera Name Input
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Camera Name',
                  labelStyle: const TextStyle(color: Color(0xFF818CF8)),
                  hintText: 'e.g. Nursery, Crib, Baby Room',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF1E293B),
                  prefixIcon: const Icon(Icons.videocam_outlined, color: Color(0xFF818CF8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),
              const Text(
                'Once scanned, this baby camera will be linked to your phone permanently. You can reconnect anytime with 1 tap.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
