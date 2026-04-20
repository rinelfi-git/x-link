import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/setup_desktop.dart';
import 'app/setup_mobile.dart';
import 'core/network/udp_discovery.dart';

/// Instance globale de la découverte UDP (accessible dans toute l'app).
late final UdpDiscovery udpDiscovery;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final discoveryPort =
      int.tryParse(dotenv.env['CROSSLINK_DISCOVERY_PORT'] ?? '') ?? 53317;

  udpDiscovery = UdpDiscovery(
    discoveryPort: discoveryPort,
    hostname: Platform.localHostname,
    os: Platform.operatingSystem,
  );

  // Démarrage avec des ports TCP placeholders pour l'instant.
  // Quand TextServer et FileServer seront implémentés, on les passera ici.
  await udpDiscovery.start(textPort: 0, filePorts: const []);

  debugPrint('[MAIN] hostname=${Platform.localHostname} '
      'os=${Platform.operatingSystem} '
      'id=${udpDiscovery.id}');

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await setupDesktop();
  } else {
    await setupMobile();
  }
}
