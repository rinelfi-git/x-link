import 'package:flutter/material.dart';

import '../ui/pages/home_page.dart';
import 'theme.dart';

class MobileApp extends StatelessWidget {
  const MobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cross Link',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomePage(),
    );
  }
}
