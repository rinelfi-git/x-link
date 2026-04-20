import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/message_store.dart';
import 'text_protocol.dart';

/// Serveur TCP qui reçoit les messages texte entrants et les pousse dans le MessageStore.
class TextServer {
  final MessageStore store;

  ServerSocket? _server;

  TextServer({required this.store});

  int get port => _server?.port ?? 0;

  /// Démarre l'écoute sur un port éphémère (0 = OS-assigned).
  Future<int> start({int preferredPort = 0}) async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, preferredPort);
    _server!.listen(_handleClient);
    debugPrint('[TEXT] Serveur démarré sur port ${_server!.port}');
    return _server!.port;
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
    debugPrint('[TEXT] Serveur arrêté');
  }

  void _handleClient(Socket socket) {
    final remote = '${socket.remoteAddress.address}:${socket.remotePort}';
    debugPrint('[TEXT] Connexion entrante de $remote');

    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
      (line) {
        if (line.isEmpty) return;
        final msg = TextProtocol.decode(line);
        if (msg == null) {
          debugPrint('[TEXT] Message invalide de $remote: $line');
          return;
        }
        store.add(
          ChatMessage(
            id: msg.id,
            peerId: msg.from,
            isMine: false,
            content: msg.content,
            sentAt: DateTime.fromMillisecondsSinceEpoch(msg.ts),
          ),
        );
      },
      onError: (e) {
        debugPrint('[TEXT] Erreur de $remote: $e');
        socket.destroy();
      },
      onDone: () => socket.destroy(),
      cancelOnError: true,
    );
  }
}
