import 'package:flutter/material.dart';

import '../ui/pages/home_page.dart';
import 'lifecycle_watcher.dart';
import 'theme.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return LifecycleWatcher(
      child: MaterialApp(
        title: 'X Link',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomePage(),
      ),
    );
  }
}
