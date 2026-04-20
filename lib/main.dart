import 'dart:io';

import 'package:flutter/material.dart';

import 'app/setup_desktop.dart';
import 'app/setup_mobile.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await setupDesktop();
  } else {
    await setupMobile();
  }
}
