import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/signaling_message.dart';
import '../utils/network_utils.dart';

class LocalP2PClient {
  WebSocket? _socket;
  bool _isConnected = false;
  String? _connectedIp;

  void Function(SignalingMessage message)? onMessageReceived;
  VoidCallback? onConnected;
  VoidCallback? onDisconnected;
  void Function(String status)? onDiscoveryProgress;

  bool get isConnected => _isConnected;
  String? get connectedIp => _connectedIp;

  /// Connects directly to the Baby Unit WebSocket at [ip]:[port].
  Future<bool> connectDirect({
    required String ip,
    required int port,
    required String roomId,
  }) async {
    await disconnect();

    try {
      final wsUrl = 'ws://$ip:$port/ws?room=$roomId&role=parent';
      debugPrint('Connecting to Baby Unit at $wsUrl...');
      onDiscoveryProgress?.call('Connecting to Baby Unit at $ip:$port...');

      final socket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 4),
      );

      _socket = socket;
      _isConnected = true;
      _connectedIp = ip;

      onConnected?.call();
      debugPrint('Connected to Baby Unit at $ip:$port successfully!');

      socket.listen(
        (dynamic data) {
          try {
            final json = jsonDecode(data.toString()) as Map<String, dynamic>;
            final msg = SignalingMessage.fromJson(json);
            onMessageReceived?.call(msg);
          } catch (e) {
            debugPrint('Error parsing message from Baby Unit: $e');
          }
        },
        onDone: () {
          debugPrint('Disconnected from Baby Unit WebSocket');
          _cleanup();
          onDisconnected?.call();
        },
        onError: (Object error) {
          debugPrint('Baby Unit WebSocket error: $error');
          _cleanup();
          onDisconnected?.call();
        },
      );

      return true;
    } catch (e) {
      debugPrint('Failed to connect directly to $ip:$port: $e');
      _cleanup();
      return false;
    }
  }

  /// Automatically discovers Baby Unit on the local subnet and connects.
  Future<bool> discoverAndConnect({
    required String roomId,
    int port = 8888,
  }) async {
    onDiscoveryProgress?.call('Scanning local Wi-Fi for Baby Unit (PIN: $roomId)...');

    final localIp = await NetworkUtils.getLocalIpAddress();
    if (localIp == null) {
      onDiscoveryProgress?.call('No local Wi-Fi connection detected');
      return false;
    }

    final subnetPrefix = NetworkUtils.getSubnetPrefix(localIp);
    if (subnetPrefix == null) {
      onDiscoveryProgress?.call('Invalid Wi-Fi subnet');
      return false;
    }

    debugPrint('Scanning subnet $subnetPrefix* for Baby Unit room $roomId...');

    final Completer<String?> foundIpCompleter = Completer<String?>();
    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 1200);

    // Launch parallel probes across the 254 subnet hosts
    int activeProbes = 0;
    const int totalHosts = 254;

    for (int host = 1; host <= totalHosts; host++) {
      final targetIp = '$subnetPrefix$host';

      // Skip probing own IP
      if (targetIp == localIp) continue;

      activeProbes++;
      _probeHost(client, targetIp, port, roomId).then((isMatch) {
        if (isMatch && !foundIpCompleter.isCompleted) {
          foundIpCompleter.complete(targetIp);
        }
      }).catchError((_) {
        // ignore probe errors
      }).whenComplete(() {
        activeProbes--;
        if (activeProbes == 0 && !foundIpCompleter.isCompleted) {
          foundIpCompleter.complete(null);
        }
      });
    }

    // Wait up to 3.5 seconds for probe to return
    final discoveredIp = await foundIpCompleter.future.timeout(
      const Duration(seconds: 4),
      onTimeout: () => null,
    );

    client.close();

    if (discoveredIp != null) {
      onDiscoveryProgress?.call('Baby Unit found at $discoveredIp! Establishing stream...');
      return await connectDirect(ip: discoveredIp, port: port, roomId: roomId);
    } else {
      onDiscoveryProgress?.call('Baby Unit not found on local Wi-Fi. Try scanning QR code.');
      return false;
    }
  }

  Future<bool> _probeHost(HttpClient client, String ip, int port, String roomId) async {
    try {
      final uri = Uri.parse('http://$ip:$port/probe?room=$roomId');
      final request = await client.getUrl(uri);
      final response = await request.close().timeout(const Duration(milliseconds: 1200));

      if (response.statusCode == HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (json['status'] == 'ok' && json['room'] == roomId) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }

  /// Sends a signaling message to the Baby Unit.
  void sendMessage(SignalingMessage message) {
    if (_socket != null && _socket!.readyState == WebSocket.open) {
      _socket!.add(message.toRawJson());
    }
  }

  void _cleanup() {
    _isConnected = false;
    _connectedIp = null;
    _socket = null;
  }

  Future<void> disconnect() async {
    try {
      await _socket?.close();
    } catch (_) {}
    _cleanup();
  }
}
