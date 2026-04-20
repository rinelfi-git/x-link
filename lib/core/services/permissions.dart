import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper générique pour demander les permissions au moment de l'action,
/// pas au démarrage de l'app.
class AppPermissions {
  /// Vérifie/demande la permission d'accès au stockage.
  ///
  /// - Sur desktop (Linux, Windows, macOS) : toujours autorisé (pas de
  ///   permission runtime, le file_picker utilise les dialogues natifs).
  /// - Sur Android 13+ : demande les permissions granulaires sur les médias.
  /// - Sur Android < 13 : demande READ_EXTERNAL_STORAGE.
  /// - Sur iOS : demande l'accès aux photos.
  ///
  /// Retourne true si la permission est accordée (full ou limited).
  static Future<bool> checkStorageWrite() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      return status.isGranted || status.isLimited;
    }

    final statuses = await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();

    final mediaGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );
    if (mediaGranted) return true;

    // Android < 13 : fallback sur READ_EXTERNAL_STORAGE
    final legacy = await Permission.storage.request();
    return legacy.isGranted;
  }

  /// Exécute [action] uniquement si la permission stockage est accordée.
  /// Si refusée, affiche un SnackBar informatif.
  ///
  /// Usage :
  /// ```dart
  /// AppPermissions.withStorage(context, () async {
  ///   final result = await FilePicker.pickFiles();
  ///   // ...
  /// });
  /// ```
  static Future<void> withStorage(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    final granted = await checkStorageWrite();
    if (!granted) {
      if (context.mounted) {
        _showDeniedSnackBar(
          context,
          'Accès au stockage refusé. Autorisez-le dans les paramètres.',
        );
      }
      return;
    }
    await action();
  }

  /// Vérifie/demande la permission de notifications.
  static Future<bool> checkNotifications() async {
    if (!Platform.isAndroid && !Platform.isIOS) return true;
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  static void _showDeniedSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Paramètres',
          onPressed: openAppSettings,
        ),
      ),
    );
  }
}
