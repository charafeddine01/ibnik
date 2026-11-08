import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

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
      name: (data['name'] as String?) ?? 'Baby Nursery',
      role: (data['role'] as String?) ?? 'baby',
      isOnline: (data['is_online'] as bool?) ?? false,
      batteryLevel: (data['battery_level'] as int?) ?? 100,
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

  CollectionReference _userDevicesRef(String userId) =>
      _firestore.collection('users').doc(userId).collection('devices');

  /// Registers or updates the Baby Unit in the cloud database under the user's account.
  Future<void> registerBabyDevice({
    required String userId,
    required String deviceId,
    required String deviceName,
    int batteryLevel = 100,
    bool isCharging = false,
  }) async {
    if (!isFirebaseAvailable) return;
    try {
      await _userDevicesRef(userId).doc(deviceId).set({
        'name': deviceName,
        'role': 'baby',
        'is_online': true,
        'battery_level': batteryLevel,
        'is_charging': isCharging,
        'last_seen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Registered Baby Unit $deviceId in cloud registry');
    } catch (e) {
      debugPrint('Error registering baby device: $e');
    }
  }

  /// Starts a periodic heartbeat to keep the Baby Unit marked as online.
  void startHeartbeat({
    required String userId,
    required String deviceId,
    required int Function() getBatteryLevel,
    required bool Function() getIsCharging,
  }) {
    if (!isFirebaseAvailable) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      try {
        await _userDevicesRef(userId).doc(deviceId).update({
          'is_online': true,
          'battery_level': getBatteryLevel(),
          'is_charging': getIsCharging(),
          'last_seen': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('Heartbeat sync error: $e');
      }
    });
  }

  /// Sets the device status to offline when nursery camera is stopped.
  Future<void> setDeviceOffline({
    required String userId,
    required String deviceId,
  }) async {
    _heartbeatTimer?.cancel();
    if (!isFirebaseAvailable) return;
    try {
      await _userDevicesRef(userId).doc(deviceId).update({
        'is_online': false,
        'last_seen': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Listens to all paired Baby Units saved in the parent's account in real-time.
  Stream<List<BabyDevice>> watchPairedBabyDevices(String userId) {
    if (!isFirebaseAvailable) return const Stream.empty();
    try {
      return _userDevicesRef(userId)
          .where('role', isEqualTo: 'baby')
          .snapshots()
          .map((snapshot) {
        return snapshot.docs.map((doc) => BabyDevice.fromFirestore(doc)).toList();
      });
    } catch (_) {
      return const Stream.empty();
    }
  }

  /// Deletes a device from the account.
  Future<void> deleteDevice(String userId, String deviceId) async {
    if (!isFirebaseAvailable) return;
    await _userDevicesRef(userId).doc(deviceId).delete();
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }
}
