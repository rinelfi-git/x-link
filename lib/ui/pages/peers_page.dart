import 'package:flutter/material.dart';

import '../widgets/peer_tile.dart';
import 'context_page.dart';

class PeersPage extends StatelessWidget {
  const PeersPage({super.key});

  // Données de démonstration
  static const _demoPeers = [
    {'hostname': 'PC-Bureau', 'os': 'linux'},
    {'hostname': 'Pixel-8', 'os': 'android'},
    {'hostname': 'MacBook', 'os': 'macos'},
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
          child: Row(
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${_demoPeers.length} pairs en ligne',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _demoPeers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.devices_other,
                        size: 64,
                        color: theme.colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Aucun pair sur le réseau',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _demoPeers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final peer = _demoPeers[index];
                    return PeerTile(
                      hostname: peer['hostname']!,
                      os: peer['os']!,
                      isUploading: index == 0,
                      uploadSpeed: index == 0 ? '2.4 MB/s' : null,
                      isDownloading: index == 1,
                      downloadSpeed: index == 1 ? '5.1 MB/s' : null,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ContextPage(
                              hostname: peer['hostname']!,
                              os: peer['os']!,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
