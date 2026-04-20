import 'dart:convert';
import 'dart:typed_data';

/// Protocole TCP pour les transferts de fichiers.
///
/// Structure d'un paquet :
/// ```
/// header_length (4 bytes, big-endian) | header (JSON, UTF-8) | body (bytes)
/// ```
///
/// Le champ `action` du header JSON indique la nature du message :
///   - Expéditeur → Receveur : handshake, start, chunk, end, cancel, resume
///   - Receveur  → Expéditeur : handshake_ok, handshake_ko, ack, retry,
///                               ack_end, error
class FileProtocol {
  static const int headerLengthSize = 4;
  static const int maxHeaderSize = 4096;

  /// Taille d'un chunk de données : 1 Mo.
  static const int chunkSize = 1024 * 1024;

  // Actions expéditeur → receveur
  static const String actionHandshake = 'handshake';
  static const String actionStart = 'start';
  static const String actionChunk = 'chunk';
  static const String actionEnd = 'end';
  static const String actionCancel = 'cancel';
  static const String actionResume = 'resume';

  // Actions receveur → expéditeur
  static const String actionHandshakeOk = 'handshake_ok';
  static const String actionHandshakeKo = 'handshake_ko';
  static const String actionAck = 'ack';
  static const String actionRetry = 'retry';
  static const String actionAckEnd = 'ack_end';
  static const String actionError = 'error';

  /// Encode un paquet : [length prefix] + [header JSON] + [body optionnel].
  static Uint8List encode(Map<String, dynamic> header, [List<int>? body]) {
    final headerBytes = utf8.encode(jsonEncode(header));
    if (headerBytes.length > maxHeaderSize) {
      throw StateError('Header trop volumineux : ${headerBytes.length} bytes');
    }

    final builder = BytesBuilder(copy: false);
    builder.add(_uint32BE(headerBytes.length));
    builder.add(headerBytes);
    if (body != null && body.isNotEmpty) {
      builder.add(body);
    }
    return builder.takeBytes();
  }

  /// Encode uniquement le préfixe de longueur du header sur 4 bytes big-endian.
  static Uint8List _uint32BE(int value) {
    final bytes = Uint8List(4);
    bytes[0] = (value >> 24) & 0xFF;
    bytes[1] = (value >> 16) & 0xFF;
    bytes[2] = (value >> 8) & 0xFF;
    bytes[3] = value & 0xFF;
    return bytes;
  }

  /// Décode un préfixe de 4 bytes big-endian en int.
  static int decodeUint32BE(Uint8List bytes) {
    return (bytes[0] << 24) | (bytes[1] << 16) | (bytes[2] << 8) | bytes[3];
  }

  /// Décode un header JSON. Retourne null si le format est invalide.
  static Map<String, dynamic>? decodeHeader(Uint8List bytes) {
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}

/// Codes d'erreur renvoyés par HANDSHAKE_KO ou ERROR.
class FileErrorCode {
  static const String permissionDenied = 'permission_denied';
  static const String folderNotWritable = 'folder_not_writable';
  static const String folderNotFound = 'folder_not_found';
  static const String diskFull = 'disk_full';
  static const String serverBusy = 'server_busy';
  static const String chunkCorrupted = 'chunk_corrupted';
  static const String checksumMismatch = 'checksum_mismatch';
  static const String unknown = 'unknown';

  /// Message par défaut selon le code d'erreur.
  static String defaultMessage(String code) => switch (code) {
    permissionDenied => 'Permission d\'écriture refusée',
    folderNotWritable => 'Le dossier de réception n\'est pas accessible',
    folderNotFound => 'Le dossier de réception est introuvable',
    diskFull => 'Espace disque insuffisant',
    serverBusy => 'Aucun slot disponible',
    chunkCorrupted => 'Chunk corrompu après 3 tentatives',
    checksumMismatch => 'Le fichier reçu est corrompu',
    _ => 'Erreur inconnue',
  };
}
