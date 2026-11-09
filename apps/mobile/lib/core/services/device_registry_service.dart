import 'dart:async';
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BabyDevice {
  final String id;
  final String name;
  final String role;
  final bool isOnline;
  final int batteryLevel;
  final bool isCharging;
  final DateTime lastSeen;

  BabyDevice({
    required this.id,
    required this.name,
    required this.role,
    required this.isOnline,
    required this.batteryLevel,
    required this.isCharging,
    required this.lastSeen,
  });

  factory BabyDevice.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final timestamp = data['last_seen'] as Timestamp?;

    return BabyDevice(
      id: doc.id,
      name: (data['name'] as String?) ?? 'Nursery Camera',
      role: (data['role'] as String?) ?? 'baby',
      isOnline: (data['is_online'] as bool?) ?? false,
      batteryLevel: (data['battery_level'] as num?)?.toInt() ?? 100,
      isCharging: (data['is_charging'] as bool?) ?? false,
      lastSeen: timestamp?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'role': role,
      'is_online': isOnline,
      'battery_level': batteryLevel,
      'is_charging': isCharging,
      'last_seen': FieldValue.serverTimestamp(),
    };
  }
}

class DeviceRegistryService {
  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  Timer? _heartbeatTimer;

  static const String _kPairedChannelsKey = 'ibnik_paired_channels_v2';
  static const String _kMyBabyChannelKey = 'ibnik_my_baby_channel_v2';
  static const String _kMyBabyNameKey = 'ibnik_my_baby_name_v2';

  CollectionReference _channelsRef() => _firestore.collection('channels');

  // --- Channel-based Cloud Registry (Works across distinct accounts) ---

  /// Registers a channel as online with battery telemetry
  Future<void> registerChannel({
    required String channelId,
    required String name,
    int batteryLevel = 100,
    bool isCharging = false,
  }) async {
    if (!isFirebaseAvailable) return;
    try {
      await _channelsRef().doc(channelId).set({
        'name': name,
        'role': 'baby',
        'is_online': true,
        'is_paired': true,
        'battery_level': batteryLevel,
        'is_charging': isCharging,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Registered channel $channelId in cloud registry');
    } catch (e) {
      debugPrint('Error registering channel: $e');
    }
  }

  /// Starts heartbeat for the active channel
  void startChannelHeartbeat({
    required String channelId,
    required int Function() getBatteryLevel,
    required bool Function() getIsCharging,
  }) {
    if (!isFirebaseAvailable) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      try {
        await _channelsRef().doc(channelId).set({
          'is_online': true,
          'battery_level': getBatteryLevel(),
          'is_charging': getIsCharging(),
          'last_seen': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Channel heartbeat sync error: $e');
      }
    });
  }

  /// Sets the channel status to offline
  Future<void> setChannelOffline(String channelId) async {
    _heartbeatTimer?.cancel();
    if (!isFirebaseAvailable) return;
    try {
      await _channelsRef().doc(channelId).update({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Listens to a single channel's real-time presence and battery
  Stream<BabyDevice?> watchChannel(String channelId) {
    if (!isFirebaseAvailable) return const Stream.empty();
    return _channelsRef().doc(channelId).snapshots().map((snapshot) {
      if (!snapshot.exists) return null;
      return BabyDevice.fromFirestore(snapshot);
    }).handleError((Object e) {
      debugPrint('watchChannel error notice: $e');
      return null;
    });
  }

  // --- Local SharedPreferences Storage for Permanent Pairing ---

  /// Saves a newly paired baby camera to the parent's phone permanently
  Future<void> savePairedCameraLocal({
    required String channelId,
    required String name,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getPairedCamerasLocal();
    // Avoid duplicate channel
    list.removeWhere((item) => item['id'] == channelId);
    list.add({'id': channelId, 'name': name});
    await prefs.setString(_kPairedChannelsKey, jsonEncode(list));
  }

  /// Gets all permanently paired cameras saved on this device
  Future<List<Map<String, String>>> getPairedCamerasLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPairedChannelsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List;
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Removes a camera from this phone's paired list
  Future<void> removePairedCameraLocal(String channelId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = await getPairedCamerasLocal();
    list.removeWhere((item) => item['id'] == channelId);
    await prefs.setString(_kPairedChannelsKey, jsonEncode(list));
  }

  /// Saves this phone's assigned baby channel (Baby Unit side)
  Future<void> saveMyBabyChannel({required String channelId, required String name}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kMyBabyChannelKey, channelId);
    await prefs.setString(_kMyBabyNameKey, name);
  }

  /// Gets this phone's assigned baby channel (Baby Unit side)
  Future<String?> getMyBabyChannel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMyBabyChannelKey);
  }

  /// Gets this phone's assigned baby name
  Future<String> getMyBabyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kMyBabyNameKey) ?? 'Nursery Camera';
  }

  /// Clears assigned baby channel to allow re-pairing
  Future<void> clearMyBabyChannel() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kMyBabyChannelKey);
    await prefs.remove(_kMyBabyNameKey);
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }
}
