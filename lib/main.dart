import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'app/setup_desktop.dart';
import 'app/setup_mobile.dart';
import 'core/network/text_client.dart';
import 'core/network/text_server.dart';
import 'core/network/udp_discovery.dart';
import 'core/services/app_settings.dart';
import 'core/services/message_store.dart';

/// Instances globales accessibles dans toute l'app.
late final UdpDiscovery udpDiscovery;
late final TextServer textServer;
late final TextClient textClient;
late final MessageStore messageStore;
late final AppSettings appSettings;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  final discoveryPort =
      int.tryParse(dotenv.env['CROSSLINK_DISCOVERY_PORT'] ?? '') ?? 53317;

  appSettings = await AppSettings.load();
  messageStore = MessageStore();

  textServer = TextServer(store: messageStore);
  final textPort = await textServer.start();

  udpDiscovery = UdpDiscovery(
    discoveryPort: discoveryPort,
    hostname: Platform.localHostname,
    os: Platform.operatingSystem,
  );

  await udpDiscovery.start(textPort: textPort, filePorts: const []);

  textClient = TextClient(selfId: udpDiscovery.id, store: messageStore);

  debugPrint('[MAIN] hostname=${Platform.localHostname} '
      'os=${Platform.operatingSystem} '
      'id=${udpDiscovery.id} '
      'textPort=$textPort');

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await setupDesktop();
  } else {
    await setupMobile();
  }
}
