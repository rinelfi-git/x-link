import 'package:flutter/material.dart';

class FilePendingBubble extends StatelessWidget {
  final String filename;
  final String fileSize;

  const FilePendingBubble({
    super.key,
    required this.filename,
    required this.fileSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.insert_drive_file,
                  size: 18,
                  color: theme.colorScheme.onPrimary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    filename,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              fileSize,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                backgroundColor:
                    theme.colorScheme.onPrimary.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(
                  theme.colorScheme.onPrimary.withValues(alpha: 0.8),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'En attente d\'un slot...',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimary.withValues(alpha: 0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
