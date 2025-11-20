// lib/widgets/base_screen.dart

import 'package:flutter/material.dart';
import 'collapsible_drawer.dart';

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
          actions: actions,
        ),
        body: child,
        floatingActionButton: floatingActionButton,
      ),
    );
  }
}