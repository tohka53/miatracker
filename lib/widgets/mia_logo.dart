import 'package:flutter/material.dart';

/// Widget reutilizable para mostrar el logo de M.I.A Tracker
/// en diferentes partes de la aplicación
class MIALogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showBackground;
  final Color? backgroundColor;
  final double borderRadius;
  final Widget? fallbackIcon;

  const MIALogo({
    super.key,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.contain,
    this.showBackground = false,
    this.backgroundColor,
    this.borderRadius = 10,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoImage = Image.asset(
      'assets/images/logomiatrackersf.png', // Ruta corregida a tu logo
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        // Si no encuentra el logo, muestra un icono por defecto
        return fallbackIcon ??
            Icon(
              Icons.assignment_turned_in_outlined,
              size: width! * 0.8,
              color: const Color(0xFF2B5F8C),
            );
      },
    );

    if (showBackground) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: logoImage,
      );
    }

    return logoImage;
  }
}

/// AppBar personalizado con logo de M.I.A Tracker
class MIAAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;

  const MIAAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = true,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Row(
        children: [
          if (showLogo) ...[
            const MIALogo(
              width: 36, // Un poco más grande en el AppBar
              height: 36,
              fallbackIcon: Icon(
                Icons.track_changes,
                size: 28,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      backgroundColor: const Color(0xFF2B5F8C),
      foregroundColor: Colors.white,
      elevation: 2,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}