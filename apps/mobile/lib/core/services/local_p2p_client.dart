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
    onDiscoveryProgress?.call('Scanning local Wi-Fi for Baby Unit...');

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

    // Prioritize neighboring IPs first (since DHCP issues consecutive IPs)
    final myHostNum = int.tryParse(localIp.split('.').last) ?? 100;
    final List<int> sortedHosts = [];

    // 1. Check +/- 15 nearest neighbors first
    for (int delta = 1; delta <= 15; delta++) {
      if (myHostNum + delta <= 254) sortedHosts.add(myHostNum + delta);
      if (myHostNum - delta >= 1) sortedHosts.add(myHostNum - delta);
    }
    // 2. Check common DHCP bases
    for (final h in [2, 3, 4, 5, 10, 20, 50, 100, 101, 102, 150, 200]) {
      if (!sortedHosts.contains(h) && h != myHostNum) sortedHosts.add(h);
    }
    // 3. Append remaining hosts
    for (int h = 1; h <= 254; h++) {
      if (!sortedHosts.contains(h) && h != myHostNum) sortedHosts.add(h);
    }

    final client = HttpClient()..connectionTimeout = const Duration(milliseconds: 600);
    String? discoveredIp;

    // Scan in bounded batches of 16 to prevent socket descriptor exhaustion
    const int batchSize = 16;
    for (int i = 0; i < sortedHosts.length; i += batchSize) {
      if (_isConnected) break;
      final batch = sortedHosts.sublist(i, (i + batchSize > sortedHosts.length) ? sortedHosts.length : i + batchSize);
      final futures = batch.map((h) async {
        final ip = '$subnetPrefix$h';
        final isMatch = await _probeHost(client, ip, port, roomId);
        if (isMatch) return ip;
        return null;
      });

      final results = await Future.wait(futures);
      final match = results.firstWhere((ip) => ip != null, orElse: () => null);
      if (match != null) {
        discoveredIp = match;
        break;
      }
    }

    client.close(force: true);

    if (discoveredIp != null) {
      onDiscoveryProgress?.call('Baby Unit found at $discoveredIp! Establishing stream...');
      return await connectDirect(ip: discoveredIp, port: port, roomId: roomId);
    } else {
      onDiscoveryProgress?.call('Baby Unit not found on local Wi-Fi.');
      return false;
    }
  }

  Future<bool> _probeHost(HttpClient client, String ip, int port, String roomId) async {
    try {
      final uri = Uri.parse('http://$ip:$port/probe?room=$roomId');
      final request = await client.getUrl(uri).timeout(const Duration(milliseconds: 600));
      final response = await request.close().timeout(const Duration(milliseconds: 600));

      if (response.statusCode == HttpStatus.ok) {
        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        if (json['status'] == 'ok' && (json['room'] == roomId || roomId.isEmpty)) {
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
