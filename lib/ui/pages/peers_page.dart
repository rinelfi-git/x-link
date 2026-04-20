import 'package:flutter/material.dart';

import '../widgets/peer_tile.dart';
import 'context_page.dart';

class PeersPage extends StatelessWidget {
  const PeersPage({super.key});

  // Données de démonstration
  static const _demoPeers = [
    {'hostname': 'PC-Bureau', 'os': 'linux', 'ip': '192.168.1.42'},
    {'hostname': 'Pixel-8', 'os': 'android', 'ip': '192.168.1.73'},
    {'hostname': 'MacBook-Pro', 'os': 'macos', 'ip': '192.168.1.108'},
    {'hostname': 'Surface-Laptop', 'os': 'windows', 'ip': '192.168.1.91'},
    {'hostname': 'iPhone-15', 'os': 'ios', 'ip': '192.168.1.55'},
    {'hostname': 'Raspberry-NAS', 'os': 'unknown', 'ip': '192.168.1.200'},
    {'hostname': 'Dev-Tower', 'os': 'linux', 'ip': '192.168.1.12'},
    {'hostname': 'Galaxy-S24', 'os': 'android', 'ip': '192.168.1.61'},
    {'hostname': 'Mac-Mini-M4', 'os': 'macos', 'ip': '192.168.1.77'},
    {'hostname': 'WorkStation-01', 'os': 'windows', 'ip': '192.168.1.34'},
    {'hostname': 'iPad-Pro', 'os': 'ios', 'ip': '192.168.1.82'},
    {'hostname': 'ThinkPad-X1', 'os': 'linux', 'ip': '192.168.1.145'},
    {'hostname': 'Xiaomi-14', 'os': 'android', 'ip': '192.168.1.19'},
    {'hostname': 'iMac-27', 'os': 'macos', 'ip': '192.168.1.167'},
    {'hostname': 'Gaming-Rig', 'os': 'windows', 'ip': '192.168.1.88'},
    {'hostname': 'Smart-TV', 'os': 'unknown', 'ip': '192.168.1.250'},
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
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final peer = _demoPeers[index];
                    return PeerTile(
                      hostname: peer['hostname']!,
                      os: peer['os']!,
                      ip: peer['ip']!,
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
