import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_app.dart';

Future<void> setupDesktop() async {
  await windowManager.ensureInitialized();

  windowManager.waitUntilReadyToShow(null, () async {
    await windowManager.setSize(const Size(500, 750));
    await windowManager.setMinimumSize(const Size(500, 750));
    await windowManager.setMaximumSize(const Size(500, 750));
    await windowManager.setResizable(false);
    await windowManager.setTitle('Cross Link');
    await windowManager.center();
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const DesktopApp());
}
