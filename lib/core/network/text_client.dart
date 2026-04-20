import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/peer.dart';
import '../services/message_store.dart';
import 'text_protocol.dart';

/// Envoie un message texte à un pair via une connexion TCP éphémère.
class TextClient {
  static const Duration connectTimeout = Duration(seconds: 5);
  static const _uuid = Uuid();

  final String selfId;
  final MessageStore store;

  TextClient({required this.selfId, required this.store});

  /// Envoie [content] à [peer]. Le message est ajouté au store en local
  /// dès l'envoi réussi. Lance une exception si la connexion échoue.
  Future<void> send(Peer peer, String content) async {
    if (peer.textPort == 0) {
      throw StateError('Pair ${peer.hostname} sans port texte');
    }

    final message = TextMessage(
      id: _uuid.v4(),
      from: selfId,
      ts: DateTime.now().millisecondsSinceEpoch,
      content: content,
    );

    final socket = await Socket.connect(
      peer.ip,
      peer.textPort,
      timeout: connectTimeout,
    );

    try {
      socket.write(TextProtocol.encode(message));
      await socket.flush();
    } finally {
      await socket.close();
    }

    store.add(
      ChatMessage(
        id: message.id,
        peerId: peer.id,
        isMine: true,
        content: content,
        sentAt: DateTime.fromMillisecondsSinceEpoch(message.ts),
      ),
    );

    debugPrint('[TEXT] → ${peer.hostname}: "$content"');
  }
}
