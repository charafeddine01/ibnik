import 'dart:async';
import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';

class LocalDiscoveryService {
  static const String serviceType = '_babymonitor._tcp';

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;

  void Function(String roomId, String ip, int port)? onServiceDiscovered;

  Future<void> startAdvertising({required String roomId, required int port}) async {
    try {
      final BonsoirService service = BonsoirService(
        name: 'BabyMonitor-$roomId',
        type: serviceType,
        port: port,
        attributes: {'room_id': roomId},
      );

      _broadcast = BonsoirBroadcast(service: service);
      await _broadcast!.ready;
      await _broadcast!.start();
      debugPrint('Local mDNS advertising started for room: $roomId');
    } catch (e) {
      debugPrint('mDNS broadcast not supported or failed: $e');
    }
  }

  Future<void> startDiscovery() async {
    try {
      _discovery = BonsoirDiscovery(type: serviceType);
      await _discovery!.ready;

      _discovery!.eventStream?.listen((event) {
        if (event.type == BonsoirDiscoveryEventType.discoveryServiceResolved) {
          final service = event.service;
          if (service != null && service.attributes.containsKey('room_id')) {
            final roomId = service.attributes['room_id']!;
            String ip = '';
            if (service is ResolvedBonsoirService) {
              ip = service.host ?? '';
            }
            final port = service.port;
            onServiceDiscovered?.call(roomId, ip, port);
          }
        }
      });

      await _discovery!.start();
      debugPrint('Local mDNS discovery started');
    } catch (e) {
      debugPrint('mDNS discovery not supported or failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _broadcast?.stop();
      await _discovery?.stop();
    } catch (e) {
      debugPrint('Error stopping local discovery: $e');
    }
  }
}
