class ChatMessage {
  final String id;
  final String peerId;
  final bool isMine;
  final String content;
  final DateTime sentAt;

  ChatMessage({
    required this.id,
    required this.peerId,
    required this.isMine,
    required this.content,
    required this.sentAt,
  });
}
