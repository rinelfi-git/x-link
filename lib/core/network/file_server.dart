import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../models/transfer_state.dart';
import '../services/transfer_store.dart';
import 'file_protocol.dart';

/// Marge d'espace disque exigée en plus de la taille du fichier (10 Mo).
const int _diskSafetyMargin = 10 * 1024 * 1024;

/// Serveur TCP pour la réception de fichiers.
///
/// Ouvre un pool de N ServerSockets (un par slot). Chaque slot traite
/// au plus un transfert à la fois, avec backlog = 0 pour que les
/// connexions vers un slot occupé soient refusées immédiatement
/// (l'expéditeur fera un fallback sur un autre port).
class FileServer {
  final TransferStore store;

  /// Fonction appelée pour obtenir le dossier de téléchargement actuel.
  /// Lue à chaque handshake pour refléter les changements dans Settings.
  final String Function() downloadPathProvider;

  FileServer({
    required this.store,
    required this.downloadPathProvider,
  });

  final List<ServerSocket> _slots = [];

  List<int> get ports => _slots.map((s) => s.port).toList(growable: false);
  int get slotCount => _slots.length;

  /// Démarre [count] slots. Retourne la liste des ports assignés par l'OS.
  Future<List<int>> start(int count) async {
    await _openSlots(count);
    return ports;
  }

  /// Ajoute ou retire des slots pour correspondre à [count].
  /// Retourne la liste des ports après reconfiguration.
  Future<List<int>> resize(int count) async {
    if (count == _slots.length) return ports;
    if (count > _slots.length) {
      await _openSlots(count - _slots.length);
    } else {
      await _closeSlots(_slots.length - count);
    }
    return ports;
  }

  Future<void> stop() async {
    for (final slot in _slots) {
      await slot.close();
    }
    _slots.clear();
  }

  Future<void> _openSlots(int count) async {
    for (var i = 0; i < count; i++) {
      final socket = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        0,
        backlog: 0,
      );
      socket.listen(_handleConnection);
      _slots.add(socket);
      debugPrint('[FILE] Slot ouvert sur port ${socket.port}');
    }
  }

  Future<void> _closeSlots(int count) async {
    for (var i = 0; i < count; i++) {
      if (_slots.isEmpty) break;
      final slot = _slots.removeLast();
      await slot.close();
      debugPrint('[FILE] Slot fermé (port ${slot.port})');
    }
  }

  void _handleConnection(Socket client) {
    // Chaque connexion est gérée indépendamment.
    _FileReceiver(
      socket: client,
      store: store,
      downloadPathProvider: downloadPathProvider,
    ).run();
  }
}

/// Gère une connexion entrante : lit le handshake, vérifie, puis reçoit
/// les chunks.
class _FileReceiver {
  final Socket socket;
  final TransferStore store;
  final String Function() downloadPathProvider;

  _FileReceiver({
    required this.socket,
    required this.store,
    required this.downloadPathProvider,
  });

  final _buffer = BytesBuilder(copy: false);
  String? _transferId;
  IOSink? _sink;
  String? _partPath;
  String? _finalPath;
  int _totalBytes = 0;
  int _writtenBytes = 0;
  bool _done = false;

  Future<void> run() async {
    try {
      await for (final data in socket) {
        _buffer.add(data);
        await _processBuffer();
        if (_done) break;
      }
    } catch (e) {
      debugPrint('[FILE] Erreur connexion : $e');
      _abortPartial();
    } finally {
      await _sink?.close();
      _sink = null;
      await socket.close();
    }
  }

  Future<void> _processBuffer() async {
    while (true) {
      final buf = _buffer.toBytes();
      if (buf.length < FileProtocol.headerLengthSize) return;

      final headerLen = FileProtocol.decodeUint32BE(buf);
      if (headerLen <= 0 || headerLen > FileProtocol.maxHeaderSize) {
        throw StateError('Header length invalide : $headerLen');
      }

      final need = FileProtocol.headerLengthSize + headerLen;
      if (buf.length < need) return;

      final headerBytes = Uint8List.sublistView(
        buf,
        FileProtocol.headerLengthSize,
        need,
      );
      final header = FileProtocol.decodeHeader(headerBytes);
      if (header == null) {
        throw StateError('Header JSON invalide');
      }

      final action = header['action'] as String?;
      final bodyLen = header['chunk_length'] as int? ?? 0;
      final total = need + bodyLen;
      if (buf.length < total) return;

      final body = bodyLen > 0
          ? Uint8List.sublistView(buf, need, total)
          : Uint8List(0);

      // On consomme ce paquet du buffer
      final remaining = buf.sublist(total);
      _buffer.clear();
      _buffer.add(remaining);

      await _dispatch(action, header, body);
      if (_done) return;
    }
  }

  Future<void> _dispatch(
    String? action,
    Map<String, dynamic> header,
    Uint8List body,
  ) async {
    switch (action) {
      case FileProtocol.actionHandshake:
        await _onHandshake(header);
        break;
      case FileProtocol.actionStart:
        await _onStart(header);
        break;
      case FileProtocol.actionChunk:
        await _onChunk(header, body);
        break;
      case FileProtocol.actionEnd:
        await _onEnd(header);
        break;
      case FileProtocol.actionCancel:
        await _onCancel();
        break;
      default:
        debugPrint('[FILE] Action inconnue : $action');
    }
  }

  // ────── Handshake ──────

  Future<void> _onHandshake(Map<String, dynamic> header) async {
    final transferId = header['transfer_id'] as String?;
    final senderId = header['sender_id'] as String?;
    final filename = header['filename'] as String?;
    final fileSize = header['file_size'] as int?;

    if (transferId == null ||
        senderId == null ||
        filename == null ||
        fileSize == null) {
      await _sendHandshakeKo(
        transferId ?? '',
        FileErrorCode.unknown,
        'Champs de handshake manquants',
      );
      return;
    }

    _transferId = transferId;
    _totalBytes = fileSize;

    final folder = downloadPathProvider();
    final check = await _verifyDestination(folder, filename, fileSize);
    if (!check.ok) {
      await _sendHandshakeKo(transferId, check.code!, check.message!);
      store.put(
        TransferState(
          transferId: transferId,
          peerId: senderId,
          direction: TransferDirection.download,
          filename: filename,
          totalBytes: fileSize,
          status: TransferStatus.failed,
          errorMessage: check.message,
        ),
      );
      return;
    }

    _finalPath = check.finalPath;
    _partPath = '${check.finalPath}.part';

    // Pré-ouvre le fichier en écriture (append)
    _sink = File(_partPath!).openWrite(mode: FileMode.writeOnly);

    store.put(
      TransferState(
        transferId: transferId,
        peerId: senderId,
        direction: TransferDirection.download,
        filename: filename,
        totalBytes: fileSize,
        status: TransferStatus.transferring,
        localFilePath: _finalPath,
      ),
    );

    _send({
      'action': FileProtocol.actionHandshakeOk,
      'transfer_id': transferId,
      'destination': p.basename(_finalPath!),
    });
    debugPrint('[FILE] Handshake OK : $filename → ${_partPath!}');
  }

  Future<_DestCheck> _verifyDestination(
    String folder,
    String filename,
    int fileSize,
  ) async {
    final dir = Directory(folder);
    if (!await dir.exists()) {
      return _DestCheck.ko(
        FileErrorCode.folderNotFound,
        'Dossier de réception introuvable : $folder',
      );
    }

    // Test d'écriture via un fichier temporaire
    try {
      final testFile = File(p.join(folder, '.crosslink_wtest'));
      await testFile.writeAsString('x', flush: true);
      await testFile.delete();
    } catch (_) {
      return _DestCheck.ko(
        FileErrorCode.folderNotWritable,
        'Le dossier n\'est pas accessible en écriture',
      );
    }

    // Espace disque libre
    try {
      final stat = await dir.stat();
      // Dart n'expose pas directement l'espace libre — on fait un essai
      // via un appel système. Sur les plateformes où ça n'est pas fiable,
      // on se rabat sur une estimation best-effort.
      final free = await _getFreeSpace(folder);
      if (free != null && free < fileSize + _diskSafetyMargin) {
        final freeM = (free / (1024 * 1024)).toStringAsFixed(1);
        final needM = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        return _DestCheck.ko(
          FileErrorCode.diskFull,
          'Espace insuffisant : $freeM Mo dispo, $needM Mo requis',
        );
      }
      // stat inutilisé mais gardé pour future inspection
      stat.changed;
    } catch (_) {
      // Ignorer : on laisse passer si on ne peut pas vérifier
    }

    // Résolution des conflits de nom
    final finalPath = _resolveUniquePath(folder, filename);
    return _DestCheck.ok(finalPath);
  }

  String _resolveUniquePath(String folder, String filename) {
    final basePath = p.join(folder, filename);
    if (!File(basePath).existsSync() && !File('$basePath.part').existsSync()) {
      return basePath;
    }

    final ext = p.extension(filename);
    final name = p.basenameWithoutExtension(filename);
    var n = 1;
    while (true) {
      final candidate = p.join(folder, '$name ($n)$ext');
      if (!File(candidate).existsSync() &&
          !File('$candidate.part').existsSync()) {
        return candidate;
      }
      n++;
    }
  }

  Future<int?> _getFreeSpace(String folder) async {
    // Best-effort via `df` sur Linux/macOS, ou sans vérification ailleurs.
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        final result = await Process.run('df', ['-k', folder]);
        if (result.exitCode == 0) {
          final lines =
              (result.stdout as String).trim().split('\n');
          if (lines.length >= 2) {
            final cols = lines.last.split(RegExp(r'\s+'));
            // Colonne "Available" = index 3 (en KB)
            final kb = int.tryParse(cols[3]);
            if (kb != null) return kb * 1024;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _sendHandshakeKo(
    String transferId,
    String code,
    String message,
  ) async {
    _send({
      'action': FileProtocol.actionHandshakeKo,
      'transfer_id': transferId,
      'error': code,
      'message': message,
    });
    _done = true;
  }

  // ────── Start / Chunk / End ──────

  Future<void> _onStart(Map<String, dynamic> header) async {
    // Rien de particulier à faire : on a déjà ouvert le IOSink au handshake.
    debugPrint('[FILE] Start reçu pour $_transferId');
  }

  Future<void> _onChunk(
    Map<String, dynamic> header,
    Uint8List body,
  ) async {
    final chunkIndex = header['chunk_index'] as int?;
    if (chunkIndex == null || _sink == null) return;

    try {
      _sink!.add(body);
      await _sink!.flush();
      _writtenBytes += body.length;

      if (_transferId != null) {
        store.update(
          _transferId!,
          (t) => t.copyWith(transferredBytes: _writtenBytes),
        );
      }

      _send({
        'action': FileProtocol.actionAck,
        'chunk_index': chunkIndex,
      });
    } catch (e) {
      debugPrint('[FILE] Erreur écriture chunk $chunkIndex : $e');
      _send({
        'action': FileProtocol.actionError,
        'transfer_id': _transferId,
        'error': FileErrorCode.diskFull,
        'message': 'Écriture impossible : $e',
      });
      _abortPartial();
      _done = true;
    }
  }

  Future<void> _onEnd(Map<String, dynamic> header) async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    // Rename .part → final
    if (_partPath != null && _finalPath != null) {
      try {
        await File(_partPath!).rename(_finalPath!);
      } catch (e) {
        debugPrint('[FILE] Erreur rename : $e');
      }
    }

    if (_transferId != null) {
      store.update(
        _transferId!,
        (t) => t.copyWith(
          status: TransferStatus.completed,
          transferredBytes: _totalBytes,
          localFilePath: _finalPath,
        ),
      );
    }

    _send({
      'action': FileProtocol.actionAckEnd,
      'transfer_id': _transferId,
    });
    _done = true;
    debugPrint('[FILE] Transfert terminé : $_finalPath');
  }

  Future<void> _onCancel() async {
    debugPrint('[FILE] Annulation reçue pour $_transferId');
    _abortPartial();
    if (_transferId != null) {
      store.update(
        _transferId!,
        (t) => t.copyWith(status: TransferStatus.cancelled),
      );
    }
    _done = true;
  }

  void _abortPartial() {
    _sink?.close();
    _sink = null;
    if (_partPath != null) {
      final f = File(_partPath!);
      if (f.existsSync()) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    }
  }

  void _send(Map<String, dynamic> header) {
    try {
      socket.add(FileProtocol.encode(header));
    } catch (_) {}
  }
}

class _DestCheck {
  final bool ok;
  final String? finalPath;
  final String? code;
  final String? message;

  _DestCheck._({
    required this.ok,
    this.finalPath,
    this.code,
    this.message,
  });

  factory _DestCheck.ok(String finalPath) =>
      _DestCheck._(ok: true, finalPath: finalPath);

  factory _DestCheck.ko(String code, String message) =>
      _DestCheck._(ok: false, code: code, message: message);
}
