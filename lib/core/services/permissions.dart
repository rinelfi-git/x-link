import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Exception levée quand une permission nécessaire est refusée.
class PermissionDeniedException implements Exception {
  final Permission permission;
  final String message;
  final bool permanentlyDenied;

  PermissionDeniedException({
    required this.permission,
    required this.message,
    this.permanentlyDenied = false,
  });

  @override
  String toString() => message;
}

/// Helper pour vérifier / demander les permissions avant une action.
///
/// Sur desktop (Linux, Windows, macOS), les permissions runtime n'existent
/// pas : les méthodes retournent immédiatement sans rien faire.
///
/// Sur mobile, l'utilisateur est invité à accorder la permission, et une
/// [PermissionDeniedException] est levée s'il refuse.
///
/// Usage :
/// ```dart
/// try {
///   await AppPermissions.ensureStorage();
///   final result = await FilePicker.pickFiles();
///   // ...
/// } on PermissionDeniedException catch (e) {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(e.message)),
///   );
/// }
/// ```
class AppPermissions {
  /// Demande la permission d'accès au stockage. Lève [PermissionDeniedException]
  /// si elle est refusée.
  static Future<void> ensureStorage() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;

    if (Platform.isIOS) {
      final status = await Permission.photos.request();
      if (!status.isGranted && !status.isLimited) {
        throw PermissionDeniedException(
          permission: Permission.photos,
          message: 'Accès à la galerie refusé',
          permanentlyDenied: status.isPermanentlyDenied,
        );
      }
      return;
    }

    // Android 13+ : permissions granulaires
    final statuses = await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
    ].request();

    final mediaGranted = statuses.values.every(
      (s) => s.isGranted || s.isLimited,
    );
    if (mediaGranted) return;

    // Android < 13 : fallback sur READ_EXTERNAL_STORAGE
    final legacy = await Permission.storage.request();
    if (legacy.isGranted) return;

    throw PermissionDeniedException(
      permission: Permission.storage,
      message: 'Accès au stockage refusé',
      permanentlyDenied: legacy.isPermanentlyDenied,
    );
  }

  /// Demande la permission pour les notifications. Lève [PermissionDeniedException]
  /// si refusée.
  static Future<void> ensureNotifications() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final status = await Permission.notification.request();
    if (!status.isGranted) {
      throw PermissionDeniedException(
        permission: Permission.notification,
        message: 'Notifications refusées',
        permanentlyDenied: status.isPermanentlyDenied,
      );
    }
  }

  /// Ouvre les paramètres de l'app (utile quand une permission est
  /// permanentlyDenied).
  static Future<bool> openSettings() => openAppSettings();
}
