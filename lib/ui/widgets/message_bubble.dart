import 'package:flutter/material.dart';

class MessageBubble extends StatelessWidget {
  final String content;
  final bool isMine;
  final bool isFile;
  final String peerName;

  const MessageBubble({
    super.key,
    required this.content,
    required this.isMine,
    required this.isFile,
    required this.peerName,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHigh,
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
            if (isFile) _buildFileContent(theme) else _buildTextContent(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildTextContent(ThemeData theme) {
    return Text(
      content,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: isMine
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurface,
      ),
    );
  }

  Widget _buildFileContent(ThemeData theme) {
    final foreground = isMine
        ? theme.colorScheme.onPrimary
        : theme.colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.insert_drive_file, size: 18, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        if (!isMine) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _FileAction(
                label: 'Ouvrir',
                icon: Icons.open_in_new,
                color: theme.colorScheme.primary,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              _FileAction(
                label: 'Dossier',
                icon: Icons.folder_open,
                color: theme.colorScheme.primary,
                onTap: () {},
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _FileAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FileAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
