import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/signaling_message.dart';
import '../utils/network_utils.dart';

class LocalP2PServer {
  HttpServer? _server;
  WebSocket? _clientSocket;
  String? _localIp;
  int _port = 8888;
  String? _roomId;

  void Function(SignalingMessage message)? onMessageReceived;
  VoidCallback? onClientConnected;
  VoidCallback? onClientDisconnected;

  String? get localIp => _localIp;
  int get port => _port;
  bool get isRunning => _server != null;
  bool get hasConnectedClient => _clientSocket != null;

  /// Starts the embedded local signaling server for the Baby Unit.
  Future<bool> start({required String roomId, int preferredPort = 8888}) async {
    _roomId = roomId;
    _localIp = await NetworkUtils.getLocalIpAddress();

    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, preferredPort);
      _port = _server!.port;
    } catch (_) {
      try {
        // Fallback to automatic ephemeral port if preferred port is in use
        _server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
        _port = _server!.port;
      } catch (e) {
        debugPrint('Failed to bind local P2P server: $e');
        return false;
      }
    }

    debugPrint('Local P2P signaling server running at http://$_localIp:$_port for room $roomId');

    _server!.listen(_handleHttpRequest);
    return true;
  }

  void _handleHttpRequest(HttpRequest request) async {
    // Add CORS headers for local network requests
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');

    final uri = request.uri;

    if (uri.path == '/probe') {
      final probeRoom = uri.queryParameters['room'];
      final isMatch = probeRoom == null || probeRoom == _roomId;

      request.response.statusCode = isMatch ? HttpStatus.ok : HttpStatus.notFound;
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode({
        'status': isMatch ? 'ok' : 'mismatch',
        'room': _roomId,
        'role': 'baby',
      }));
      await request.response.close();
      return;
    }

    if (uri.path == '/ws') {
      try {
        final socket = await WebSocketTransformer.upgrade(request);
        _clientSocket = socket;
        debugPrint('Parent Unit WebSocket connected to local Baby Unit server!');

        onClientConnected?.call();

        socket.listen(
          (dynamic data) {
            try {
              final json = jsonDecode(data.toString()) as Map<String, dynamic>;
              final msg = SignalingMessage.fromJson(json);
              onMessageReceived?.call(msg);
            } catch (e) {
              debugPrint('Error parsing message from Parent: $e');
            }
          },
          onDone: () {
            debugPrint('Parent Unit WebSocket disconnected');
            _clientSocket = null;
            onClientDisconnected?.call();
          },
          onError: (Object error) {
            debugPrint('Parent Unit WebSocket error: $error');
            _clientSocket = null;
            onClientDisconnected?.call();
          },
        );
      } catch (e) {
        debugPrint('WebSocket upgrade failed: $e');
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
      return;
    }

    // Default response
    request.response.statusCode = HttpStatus.ok;
    request.response.write('Ibnik Baby Unit Signaling Server');
    await request.response.close();
  }

  /// Sends a signaling message to the connected Parent Unit.
  void sendMessage(SignalingMessage message) {
    if (_clientSocket != null && _clientSocket!.readyState == WebSocket.open) {
      _clientSocket!.add(message.toRawJson());
    }
  }

  Future<void> stop() async {
    try {
      await _clientSocket?.close();
      _clientSocket = null;
      await _server?.close(force: true);
      _server = null;
    } catch (e) {
      debugPrint('Error stopping local P2P server: $e');
    }
  }
}
