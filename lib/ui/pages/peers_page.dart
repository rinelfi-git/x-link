import 'package:flutter/material.dart';

import '../../core/models/peer.dart';
import '../../main.dart' show udpDiscovery;
import '../widgets/peer_tile.dart';
import 'context_page.dart';

class PeersPage extends StatelessWidget {
  const PeersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Peer>>(
      stream: udpDiscovery.peersStream,
      initialData: udpDiscovery.peers,
      builder: (context, snapshot) {
        final peers = snapshot.data ?? const <Peer>[];
        return _PeersView(peers: peers);
      },
    );
  }
}

class _PeersView extends StatelessWidget {
  final List<Peer> peers;

  const _PeersView({required this.peers});

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
                '${peers.length} pair${peers.length > 1 ? 's' : ''} en ligne',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: peers.isEmpty
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
                  itemCount: peers.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final peer = peers[index];
                    return PeerTile(
                      hostname: peer.hostname,
                      os: peer.os,
                      ip: peer.ip,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ContextPage(peer: peer),
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
