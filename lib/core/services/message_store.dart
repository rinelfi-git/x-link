import 'dart:async';

import '../models/chat_message.dart';

/// Stocke l'historique des messages par peer id et expose un flux de mises à jour.
class MessageStore {
  final Map<String, List<ChatMessage>> _byPeer = {};
  final _controller = StreamController<String>.broadcast();

  /// Émet l'id du pair dont la conversation vient de changer.
  Stream<String> get updates => _controller.stream;

  List<ChatMessage> messagesFor(String peerId) =>
      List.unmodifiable(_byPeer[peerId] ?? const []);

  void add(ChatMessage message) {
    final list = _byPeer.putIfAbsent(message.peerId, () => []);
    list.add(message);
    _controller.add(message.peerId);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
