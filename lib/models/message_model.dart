class MessageModel {
  final String senderId;
  final String content;
  final DateTime timestamp;

  MessageModel({
    required this.senderId,
    required this.content,
    required this.timestamp,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      senderId: json['senderId'] ?? '',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(json['timestamp']),
    );
  }

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'content': content,
        'timestamp': timestamp.toIso8601String(),
      };
}
