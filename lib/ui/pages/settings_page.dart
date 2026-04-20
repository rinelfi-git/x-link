import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/services/app_settings.dart';
import '../../core/services/permissions.dart';
import '../../main.dart' show appSettings, udpDiscovery;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late int _maxFileTransfers;
  late String _downloadPath;
  late FileConflictStrategy _conflictStrategy;

  @override
  void initState() {
    super.initState();
    _maxFileTransfers = appSettings.maxFileTransfers;
    _downloadPath = appSettings.downloadPath;
    _conflictStrategy = appSettings.conflictStrategy;
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _pickDownloadFolder() async {
    try {
      await AppPermissions.ensureStorage();
      final path = await FilePicker.getDirectoryPath();
      if (path != null) {
        setState(() => _downloadPath = path);
      }
    } on PermissionDeniedException catch (e) {
      _showError(e.message);
    }
  }

  void _save() {
    appSettings
      ..setMaxFileTransfers(_maxFileTransfers)
      ..setDownloadPath(_downloadPath)
      ..setConflictStrategy(_conflictStrategy);

    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Paramètres enregistrés'),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Paramètres',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 24),

        // Transferts simultanés
        _SettingsCard(
          theme: theme,
          icon: Icons.swap_vert,
          title: 'Transferts fichier simultanés',
          subtitle: 'Nombre de slots ouverts pour la réception',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton.outlined(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: _maxFileTransfers > 1
                    ? () => setState(() => _maxFileTransfers--)
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_maxFileTransfers',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              IconButton.outlined(
                icon: const Icon(Icons.add, size: 18),
                onPressed: _maxFileTransfers < 5
                    ? () => setState(() => _maxFileTransfers++)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Dossier de réception
        _SettingsCard(
          theme: theme,
          icon: Icons.folder_outlined,
          title: 'Dossier de réception',
          subtitle: _downloadPath,
          child: FilledButton.tonal(
            onPressed: _pickDownloadFolder,
            child: const Text('Changer'),
          ),
        ),
        const SizedBox(height: 12),

        // Stratégie de conflit de nom
        _SettingsCard(
          theme: theme,
          icon: Icons.copy_outlined,
          title: 'Fichier du même nom',
          subtitle: 'Comportement si un fichier existe déjà',
          child: SegmentedButton<FileConflictStrategy>(
            segments: const [
              ButtonSegment(
                value: FileConflictStrategy.rename,
                label: Text('Renommer'),
                icon: Icon(Icons.edit),
              ),
              ButtonSegment(
                value: FileConflictStrategy.overwrite,
                label: Text('Écraser'),
                icon: Icon(Icons.refresh),
              ),
            ],
            selected: {_conflictStrategy},
            onSelectionChanged: (selection) {
              setState(() => _conflictStrategy = selection.first);
            },
          ),
        ),
        const SizedBox(height: 12),

        // Identité
        _SettingsCard(
          theme: theme,
          icon: Icons.person_outline,
          title: 'Identité sur le réseau',
          subtitle: 'Nom visible par les autres pairs',
          child: Text(
            '${udpDiscovery.hostname} (${udpDiscovery.os})',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Enregistrer'),
          ),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  const _SettingsCard({
    required this.theme,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.only(left: 30),
              child: child,
            ),
          ],
        ),
      ),
    );
  }
}
