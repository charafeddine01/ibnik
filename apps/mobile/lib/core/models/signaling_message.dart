import 'dart:convert';

class SignalingMessage {
  final String type;
  final String roomId;
  final String senderId;
  final String? targetId;
  final String? role;
  final Map<String, dynamic>? payload;

  SignalingMessage({
    required this.type,
    required this.roomId,
    required this.senderId,
    this.targetId,
    this.role,
    this.payload,
  });

  factory SignalingMessage.fromJson(Map<String, dynamic> json) {
    return SignalingMessage(
      type: json['type'] as String,
      roomId: json['room_id'] as String,
      senderId: json['sender_id'] as String,
      targetId: json['target_id'] as String?,
      role: json['role'] as String?,
      payload: json['payload'] != null
          ? (json['payload'] is String
              ? jsonDecode(json['payload'] as String) as Map<String, dynamic>
              : json['payload'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'room_id': roomId,
      'sender_id': senderId,
      if (targetId != null) 'target_id': targetId,
      if (role != null) 'role': role,
      if (payload != null) 'payload': payload,
    };
  }

  String toRawJson() => jsonEncode(toJson());
}
