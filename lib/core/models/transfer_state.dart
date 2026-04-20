enum TransferStatus {
  /// En train de négocier avec le receveur (handshake en cours).
  handshaking,

  /// Handshake OK, transfert en cours.
  transferring,

  /// Transfert terminé et vérifié.
  completed,

  /// Annulé par l'utilisateur.
  cancelled,

  /// Échec : handshake_ko, timeout, chunk corrompu, checksum KO...
  failed,
}

enum TransferDirection { upload, download }

/// État d'un transfert de fichier (envoi ou réception).
class TransferState {
  final String transferId;
  final String peerId;
  final TransferDirection direction;
  final String filename;
  final int totalBytes;

  final int transferredBytes;
  final TransferStatus status;

  /// Message d'erreur (si [status] est [TransferStatus.failed]).
  final String? errorMessage;

  /// Chemin local du fichier (sur l'appareil de réception).
  final String? localFilePath;

  final DateTime startedAt;

  TransferState({
    required this.transferId,
    required this.peerId,
    required this.direction,
    required this.filename,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = TransferStatus.handshaking,
    this.errorMessage,
    this.localFilePath,
    DateTime? startedAt,
  }) : startedAt = startedAt ?? DateTime.now();

  double get progress =>
      totalBytes == 0 ? 0.0 : transferredBytes / totalBytes;

  TransferState copyWith({
    int? transferredBytes,
    TransferStatus? status,
    String? errorMessage,
    String? localFilePath,
  }) {
    return TransferState(
      transferId: transferId,
      peerId: peerId,
      direction: direction,
      filename: filename,
      totalBytes: totalBytes,
      transferredBytes: transferredBytes ?? this.transferredBytes,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      localFilePath: localFilePath ?? this.localFilePath,
      startedAt: startedAt,
    );
  }
}
