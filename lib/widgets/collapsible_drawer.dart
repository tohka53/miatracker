import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/mia_logo.dart';

class CollapsibleDrawer extends StatefulWidget {
  final Widget child;
  final String currentRoute;

  const CollapsibleDrawer({
    super.key,
    required this.child,
    this.currentRoute = '/home',
  });

  @override
  State<CollapsibleDrawer> createState() => _CollapsibleDrawerState();
}

class _CollapsibleDrawerState extends State<CollapsibleDrawer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _menuScaleAnimation;
  late Animation<double> _contentScaleAnimation;

  bool _isMenuOpen = false;
  final double _menuWidth = 280;
  final double _collapsedWidth = 70;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _menuScaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _contentScaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });

    if (_isMenuOpen) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF2B5F8C),
                  Color(0xFF1A4A6B),
                ],
              ),
            ),
          ),

          // Side Menu
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(
                  _menuScaleAnimation.value * _menuWidth - _menuWidth,
                  0,
                ),
                child: _buildSideMenu(),
              );
            },
          ),

          // Main Content
          AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final slideOffset = _menuScaleAnimation.value * (_menuWidth * 0.6);
              final scale = _contentScaleAnimation.value;

              return Transform.translate(
                offset: Offset(slideOffset, 0),
                child: Transform.scale(
                  scale: scale,
                  child: ClipRRect(
                    borderRadius: _isMenuOpen
                        ? BorderRadius.circular(20)
                        : BorderRadius.zero,
                    child: widget.child,
                  ),
                ),
              );
            },
          ),

          // Menu button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: _buildMenuButton(),
          ),

          // Overlay to close menu when tapping outside
          if (_isMenuOpen)
            GestureDetector(
              onTap: _toggleMenu,
              child: Container(
                color: Colors.black.withOpacity(0.3),
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMenuButton() {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.rotate(
              angle: _menuScaleAnimation.value * 0.5,
              child: Icon(
                _isMenuOpen ? Icons.close : Icons.menu,
                color: const Color(0xFF2B5F8C),
                size: 24,
              ),
            );
          },
        ),
        onPressed: _toggleMenu,
      ),
    );
  }

  Widget _buildSideMenu() {
    return Container(
      width: _menuWidth,
      height: MediaQuery.of(context).size.height,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2B5F8C),
            Color(0xFF1A4A6B),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildUserProfile(),
            const SizedBox(height: 30),
            Expanded(
              child: _buildMenuItems(),
            ),
            _buildMenuFooter(),
            const SizedBox(height: 10), // Extra padding at bottom
          ],
        ),
      ),
    );
  }

  Widget _buildUserProfile() {
    final user = AuthService.currentUser;
    final emailColor = Colors.white.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const MIALogo(
            width: 60,
            height: 60,
            showBackground: true,
            backgroundColor: Colors.white,
            borderRadius: 15,
          ),
          const SizedBox(height: 15),
          Text(
            user?.userMetadata?['full_name'] ?? 'Usuario',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 5),
          Text(
            user?.email ?? '',
            style: TextStyle(
              color: emailColor,
              fontSize: 12,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItems() {
    final menuItems = <Widget>[
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.home_outlined,
        title: 'Home',
        route: '/home',
        isSelected: widget.currentRoute == '/home',
      )),
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.inventory_2_outlined,
        title: 'Inventory',
        route: '/inventory',
        isSelected: widget.currentRoute == '/inventory',
      )),
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.build_outlined,
        title: 'Maintenance',
        route: '/maintenance',
        isSelected: widget.currentRoute == '/maintenance',
      )),
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.analytics_outlined,
        title: 'Reports',
        route: '/reports',
        isSelected: widget.currentRoute == '/reports',
      )),
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.category_outlined,
        title: 'Categories',
        route: '/categories',
        isSelected: widget.currentRoute == '/categories',
      )),
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.location_on_outlined,
        title: 'Locations',
        route: '/locations',
        isSelected: widget.currentRoute == '/locations',
      )),
      const SizedBox(height: 20), // Separator
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.settings_outlined,
        title: 'Settings',
        route: '/settings',
        isSelected: widget.currentRoute == '/settings',
      )),
      _buildMenuItem(DrawerMenuItem(
        icon: Icons.help_outline,
        title: 'Help & Support',
        route: '/help',
        isSelected: widget.currentRoute == '/help',
      )),
    ];

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      itemCount: menuItems.length,
      separatorBuilder: (context, index) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        return menuItems[index];
      },
    );
  }

  Widget _buildMenuItem(DrawerMenuItem item) {
    // Pre-calculate colors to avoid repeated withOpacity calls
    const selectedTextColor = Colors.white;
    final unselectedTextColor = Colors.white.withValues(alpha: 0.8);
    final selectedBackgroundColor = Colors.white.withValues(alpha: 0.15);
    final borderColor = Colors.white.withValues(alpha: 0.3);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _onMenuItemTap(item.route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: item.isSelected
                  ? selectedBackgroundColor
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: item.isSelected
                  ? Border.all(color: borderColor)
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: item.isSelected
                      ? selectedTextColor
                      : unselectedTextColor,
                  size: 24,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: item.isSelected
                          ? selectedTextColor
                          : unselectedTextColor,
                      fontSize: 16,
                      fontWeight: item.isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ),
                if (item.isSelected)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuFooter() {
    final dividerColor = Colors.white.withValues(alpha: 0.3);
    final logoutColor = Colors.red.withValues(alpha: 0.8);
    final logoutBorderColor = Colors.red.withValues(alpha: 0.3);
    final versionColor = Colors.white.withValues(alpha: 0.5);

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Divider(color: dividerColor),
          const SizedBox(height: 10),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: _handleLogout,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: logoutBorderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: logoutColor,
                      size: 24,
                    ),
                    const SizedBox(width: 15),
                    Text(
                      'Sign Out',
                      style: TextStyle(
                        color: logoutColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'M.I.A Tracker v1.0.0',
            style: TextStyle(
              color: versionColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _onMenuItemTap(String route) {
    _toggleMenu(); // Close menu first

    Future.delayed(const Duration(milliseconds: 250), () {
      // Check if widget is still mounted before using context
      if (!mounted) return;

      if (widget.currentRoute != route) {
        // Navigate to different screen
        switch (route) {
          case '/home':
            Navigator.pushReplacementNamed(context, '/home');
            break;
          case '/inventory':
          case '/maintenance':
          case '/reports':
          case '/categories':
          case '/locations':
          case '/settings':
          case '/help':
            _showModuleInfo(route);
            break;
        }
      }
    });
  }

  void _showModuleInfo(String route) {
    // Check if widget is still mounted before showing dialog
    if (!mounted) return;

    final moduleName = route.replaceFirst('/', '').capitalize();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(
                _getModuleIcon(moduleName),
                color: const Color(0xFF2B5F8C),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  moduleName,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '$moduleName module is currently in development.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This module will connect to your Supabase database to provide real-time functionality.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Got it!',
                style: TextStyle(color: Color(0xFF6B8E3D)),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getModuleIcon(String moduleName) {
    switch (moduleName.toLowerCase()) {
      case 'inventory':
        return Icons.inventory_2_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      case 'reports':
        return Icons.analytics_outlined;
      case 'categories':
        return Icons.category_outlined;
      case 'locations':
        return Icons.location_on_outlined;
      case 'settings':
        return Icons.settings_outlined;
      case 'help':
        return Icons.help_outline;
      default:
        return Icons.help;
    }
  }

  Future<void> _handleLogout() async {
    try {
      await AuthService.signOut();
      // AuthWrapper manejará la navegación automáticamente
    } catch (e) {
      // Check if widget is still mounted before showing SnackBar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

class DrawerMenuItem {
  final IconData icon;
  final String title;
  final String route;
  final bool isSelected;

  const DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.route,
    this.isSelected = false,
  });
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}