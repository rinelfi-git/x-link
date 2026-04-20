import 'package:flutter/material.dart';

class PeerTile extends StatelessWidget {
  final String hostname;
  final String os;
  final VoidCallback onTap;
  final bool isUploading;
  final bool isDownloading;
  final String? uploadSpeed;
  final String? downloadSpeed;

  const PeerTile({
    super.key,
    required this.hostname,
    required this.os,
    required this.onTap,
    this.isUploading = false,
    this.isDownloading = false,
    this.uploadSpeed,
    this.downloadSpeed,
  });

  IconData get _osIcon => switch (os) {
    'linux' => Icons.computer,
    'windows' => Icons.desktop_windows,
    'macos' => Icons.laptop_mac,
    'android' => Icons.phone_android,
    'ios' => Icons.phone_iphone,
    _ => Icons.devices,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(_osIcon, color: theme.colorScheme.primary, size: 20),
        ),
        title: Text(
          hostname,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          os,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUploading)
              _TransferIndicator(
                icon: Icons.cloud_upload,
                color: theme.colorScheme.primary,
                speed: uploadSpeed,
              ),
            if (isDownloading)
              _TransferIndicator(
                icon: Icons.cloud_download,
                color: theme.colorScheme.tertiary,
                speed: downloadSpeed,
              ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

class _TransferIndicator extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? speed;

  const _TransferIndicator({
    required this.icon,
    required this.color,
    this.speed,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          if (speed != null) ...[
            const SizedBox(width: 4),
            Text(
              speed!,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ],
        ],
      ),
    );
  }
}
