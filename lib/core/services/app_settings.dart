import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Stratégie quand un fichier reçu porte le même nom qu'un fichier existant.
enum FileConflictStrategy {
  /// Renomme le fichier reçu (ex: rapport (1).pdf)
  rename,

  /// Écrase le fichier existant
  overwrite,
}

/// Paramètres globaux de l'app, modifiables via la page Settings.
class AppSettings {
  int maxFileTransfers;
  String downloadPath;
  FileConflictStrategy conflictStrategy;

  final _controller = StreamController<AppSettings>.broadcast();

  /// Émet la configuration à chaque changement.
  Stream<AppSettings> get changes => _controller.stream;

  AppSettings({
    this.maxFileTransfers = 2,
    required this.downloadPath,
    this.conflictStrategy = FileConflictStrategy.rename,
  });

  /// Charge les paramètres avec le dossier Downloads du système
  /// comme destination par défaut.
  static Future<AppSettings> load() async {
    return AppSettings(downloadPath: await _resolveDownloadsPath());
  }

  /// Retourne le dossier Downloads natif de chaque plateforme :
  /// - Linux / macOS / Windows : `~/Downloads`
  /// - Android : `/storage/emulated/0/Download`
  /// - iOS : dossier Documents de l'app (pas d'accès au vrai Downloads)
  static Future<String> _resolveDownloadsPath() async {
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir.path;
    } catch (_) {}

    // Fallback selon la plateforme
    if (Platform.isAndroid) {
      return '/storage/emulated/0/Download';
    }

    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  /// Fallback pur si tout échoue : retourne $HOME ou le CWD.
  static String homeOrCwd() {
    final env = Platform.environment;
    final home = env['HOME'] ?? env['USERPROFILE'];
    if (home != null && home.isNotEmpty) return home;
    return p.current;
  }

  void setMaxFileTransfers(int value) {
    maxFileTransfers = value;
    _controller.add(this);
  }

  void setDownloadPath(String value) {
    downloadPath = value;
    _controller.add(this);
  }

  void setConflictStrategy(FileConflictStrategy value) {
    conflictStrategy = value;
    _controller.add(this);
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
