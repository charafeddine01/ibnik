import 'package:flutter_test/flutter_test.dart';
import 'package:babymonitor/core/models/peer_role.dart';
import 'package:babymonitor/core/models/signaling_message.dart';

void main() {
  group('SignalingMessage & PeerRole Tests', () {
    test('PeerRole serialization and deserialization', () {
      expect(PeerRole.baby.value, 'baby');
      expect(PeerRole.parent.value, 'parent');
      expect(PeerRoleExtension.fromString('baby'), PeerRole.baby);
      expect(PeerRoleExtension.fromString('parent'), PeerRole.parent);
    });

    test('SignalingMessage serialization roundtrip', () {
      final msg = SignalingMessage(
        type: 'offer',
        roomId: '123456',
        senderId: 'peer-baby',
        targetId: 'peer-parent',
        role: 'baby',
        payload: {'sdp': 'v=0...', 'type': 'offer'},
      );

      final json = msg.toJson();
      expect(json['type'], 'offer');
      expect(json['room_id'], '123456');
      expect(json['sender_id'], 'peer-baby');
      expect(json['target_id'], 'peer-parent');
      expect(json['role'], 'baby');
      expect(json['payload']['sdp'], 'v=0...');

      final decoded = SignalingMessage.fromJson(json);
      expect(decoded.type, 'offer');
      expect(decoded.roomId, '123456');
      expect(decoded.senderId, 'peer-baby');
      expect(decoded.targetId, 'peer-parent');
      expect(decoded.payload!['sdp'], 'v=0...');
    });
  });
}
