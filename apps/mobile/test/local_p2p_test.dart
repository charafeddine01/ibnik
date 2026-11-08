import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:babymonitor/core/models/signaling_message.dart';
import 'package:babymonitor/core/services/local_p2p_server.dart';
import 'package:babymonitor/core/services/local_p2p_client.dart';
import 'package:babymonitor/core/utils/network_utils.dart';

void main() {
  group('Local P2P Signaling Server & Client Tests', () {
    test('NetworkUtils getSubnetPrefix returns 3 octets', () {
      expect(NetworkUtils.getSubnetPrefix('192.168.1.50'), '192.168.1.');
      expect(NetworkUtils.getSubnetPrefix('10.0.0.12'), '10.0.0.');
      expect(NetworkUtils.getSubnetPrefix('invalid'), isNull);
    });

    test('LocalP2PServer starts and responds to HTTP probe', () async {
      final server = LocalP2PServer();
      final started = await server.start(roomId: '999888', preferredPort: 0);
      expect(started, isTrue);
      expect(server.port, greaterThan(0));

      final client = HttpClient();
      final uri = Uri.parse('http://127.0.0.1:${server.port}/probe?room=999888');
      final request = await client.getUrl(uri);
      final response = await request.close();

      expect(response.statusCode, HttpStatus.ok);
      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      expect(json['status'], 'ok');
      expect(json['room'], '999888');

      client.close();
      await server.stop();
    });

    test('LocalP2PServer and LocalP2PClient WebSocket handshake and messaging', () async {
      final server = LocalP2PServer();
      await server.start(roomId: '112233', preferredPort: 0);

      SignalingMessage? serverReceivedMsg;
      SignalingMessage? clientReceivedMsg;

      server.onMessageReceived = (msg) {
        serverReceivedMsg = msg;
      };

      final client = LocalP2PClient();
      client.onMessageReceived = (msg) {
        clientReceivedMsg = msg;
      };

      final connected = await client.connectDirect(
        ip: '127.0.0.1',
        port: server.port,
        roomId: '112233',
      );
      expect(connected, isTrue);

      // Wait 100ms for connection
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Client sends message to server
      final testOffer = SignalingMessage(
        type: 'offer',
        roomId: '112233',
        senderId: 'client-1',
        payload: {'sdp': 'test-offer-sdp', 'type': 'offer'},
      );
      client.sendMessage(testOffer);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(serverReceivedMsg, isNotNull);
      expect(serverReceivedMsg!.type, 'offer');
      expect(serverReceivedMsg!.payload!['sdp'], 'test-offer-sdp');

      // Server sends message to client
      final testAnswer = SignalingMessage(
        type: 'answer',
        roomId: '112233',
        senderId: 'server-1',
        payload: {'sdp': 'test-answer-sdp', 'type': 'answer'},
      );
      server.sendMessage(testAnswer);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(clientReceivedMsg, isNotNull);
      expect(clientReceivedMsg!.type, 'answer');
      expect(clientReceivedMsg!.payload!['sdp'], 'test-answer-sdp');

      await client.disconnect();
      await server.stop();
    });
  });
}
