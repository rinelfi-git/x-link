import 'package:flutter/material.dart';

enum FileTransferStatus { pending, transferring, completed, failed }

class FileTransferBubble extends StatelessWidget {
  final String filename;
  final String fileSize;
  final bool isMine;
  final String peerName;
  final FileTransferStatus status;
  final double progress;
  final VoidCallback? onAction;

  const FileTransferBubble({
    super.key,
    required this.filename,
    required this.fileSize,
    required this.isMine,
    required this.peerName,
    required this.status,
    this.progress = 0.0,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bgColor = status == FileTransferStatus.failed
        ? theme.colorScheme.errorContainer
        : isMine
            ? theme.colorScheme.primary
            : theme.colorScheme.surfaceContainerHigh;

    final fgColor = status == FileTransferStatus.failed
        ? theme.colorScheme.onErrorContainer
        : isMine
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface;

    final subtleColor = fgColor.withValues(alpha: 0.7);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  peerName,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            // Ligne principale : infos fichier + bouton action
            Row(
              children: [
                Icon(Icons.insert_drive_file, size: 18, color: fgColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        filename,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: fgColor,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileSize,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: subtleColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _StatusActionButton(
                  status: status,
                  fgColor: fgColor,
                  onAction: onAction,
                ),
              ],
            ),

            // Barre de progression (pending ou transferring)
            if (status == FileTransferStatus.pending ||
                status == FileTransferStatus.transferring) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: status == FileTransferStatus.pending ? null : progress,
                  backgroundColor: fgColor.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    fgColor.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],

          ],
        ),
      ),
    );
  }

}

class _StatusActionButton extends StatelessWidget {
  final FileTransferStatus status;
  final Color fgColor;
  final VoidCallback? onAction;

  const _StatusActionButton({
    required this.status,
    required this.fgColor,
    this.onAction,
  });

  IconData get _icon => switch (status) {
    FileTransferStatus.pending => Icons.close,
    FileTransferStatus.transferring => Icons.close,
    FileTransferStatus.completed => Icons.folder_open,
    FileTransferStatus.failed => Icons.refresh,
  };

  String get _tooltip => switch (status) {
    FileTransferStatus.pending => 'Annuler',
    FileTransferStatus.transferring => 'Annuler',
    FileTransferStatus.completed => 'Ouvrir dans le dossier',
    FileTransferStatus.failed => 'Réessayer',
  };

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
        onTap: onAction,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: fgColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Icon(_icon, size: 20, color: fgColor),
        ),
      ),
      ),
    );
  }
}
