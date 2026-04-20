import 'dart:convert';

/// Protocole TCP texte : chaque message est un JSON terminé par `\n`.
///
/// Format :
/// { "id": "<uuid>", "from": "<peer_id>", "ts": <epoch_ms>, "content": "..." }
class TextProtocol {
  static const int version = 1;

  static String encode(TextMessage msg) {
    return '${jsonEncode(msg.toJson())}\n';
  }

  static TextMessage? decode(String raw) {
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TextMessage.fromJson(map);
    } catch (_) {
      return null;
    }
  }
}

class TextMessage {
  final String id;
  final String from;
  final int ts;
  final String content;

  TextMessage({
    required this.id,
    required this.from,
    required this.ts,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'from': from,
        'ts': ts,
        'content': content,
      };

  factory TextMessage.fromJson(Map<String, dynamic> json) => TextMessage(
        id: json['id'] as String,
        from: json['from'] as String,
        ts: json['ts'] as int,
        content: json['content'] as String,
      );
}
