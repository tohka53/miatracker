// lib/widgets/base_screen.dart

import 'package:flutter/material.dart';
import 'collapsible_drawer.dart';
import 'notifications_bell_icon.dart';

class BaseScreen extends StatelessWidget {
  final Widget child;
  final String currentRoute;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const BaseScreen({
    super.key,
    required this.child,
    required this.currentRoute,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: currentRoute,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: const SizedBox.shrink(), // El drawer maneja su propio botón
          actions: [
            const NotificationsBellIcon(), // 🔔 Campana con badge en todas las pantallas
            ...?actions,
          ],
        ),
        body: child,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}