import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../main.dart' show udpDiscovery;

/// Écoute le cycle de vie de l'app pour envoyer le LEAVE UDP avant
/// que le processus ne se ferme.
class LifecycleWatcher extends StatefulWidget {
  final Widget child;

  const LifecycleWatcher({super.key, required this.child});

  @override
  State<LifecycleWatcher> createState() => _LifecycleWatcherState();
}

class _LifecycleWatcherState extends State<LifecycleWatcher> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(
      onExitRequested: _onExitRequested,
      onDetach: _onDetach,
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    super.dispose();
  }

  /// Desktop : déclenché quand l'utilisateur ferme la fenêtre.
  Future<ui.AppExitResponse> _onExitRequested() async {
    await udpDiscovery.stop();
    return ui.AppExitResponse.exit;
  }

  /// Mobile : déclenché quand l'OS détache le moteur Flutter
  /// (ex: swipe out de l'app).
  void _onDetach() {
    udpDiscovery.stop();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
