import 'package:flutter/material.dart';
import '../screens/qr_complete_order_screen.dart';
import '../services/auth_service.dart';
import '../services/account_deletion_service.dart';
import '../services/cart_service.dart';
import '../services/marketplace_cart_service.dart';
import '../screens/inventory_screen.dart';
import '../screens/shopping_cart_screen.dart';
import '../screens/transfer_screen.dart';
import '../screens/restock_management_screen.dart';
import '../screens/help_support_screen.dart';

// Suppliers
import '../screens/suppliers/supply_company_screen.dart';
import '../screens/suppliers/supplier_dashboard.dart';
import '../screens/suppliers/products_without_supplier_screen.dart';

// Reports
import '../screens/reports/inventory_reports_screen.dart';

// Marketplace
import '../screens/marketplace/supply_marketplace_screen.dart';
import '../screens/marketplace/marketplace_cart_screen.dart';
import '../screens/marketplace/supplier_management_screen.dart';

// Orders
import '../screens/orders_screen.dart';

// Settings
import '../screens/settings/company_settings_screen.dart';

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
  final CartService _cartService = CartService();
  final MarketplaceCartService _marketplaceCartService = MarketplaceCartService();

  // 🆕 Roles del usuario
  String _userRole = 'user'; // 'user', 'supervisor', 'admin'
  bool _isSupplier = false;
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _cartService.addListener(_onCartChanged);
    _marketplaceCartService.addListener(_onCartChanged);
    _loadUserRole();
    _checkIfSupplier();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _menuScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _contentScaleAnimation = Tween<double>(begin: 1.0, end: 0.85).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  // 🆕 Cargar rol del usuario
  Future<void> _loadUserRole() async {
    try {
      final profile = await AuthService.getUserProfile();
      final role = profile?['role'] ?? 'user';

      if (mounted) {
        setState(() {
          _userRole = role.toString().toLowerCase();
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _userRole = 'user';
          _isLoadingRole = false;
        });
      }
    }
  }

  Future<void> _checkIfSupplier() async {
    // TODO: Verificar en Supabase si el usuario tiene modo proveedor activo
    setState(() => _isSupplier = false); // Por ahora false
  }

  // 🆕 Verificadores de roles
  bool get _isUser => _userRole == 'user';
  bool get _isSupervisor => _userRole == 'supervisor';
  bool get _isAdmin => _userRole == 'admin' || _userRole == 'super_admin';
  bool get _isAdminOrSupervisor => _isAdmin || _isSupervisor;

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  void _toggleMenu() {
    setState(() => _isMenuOpen = !_isMenuOpen);
    _isMenuOpen ? _animationController.forward() : _animationController.reverse();
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    _marketplaceCartService.removeListener(_onCartChanged);
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Fondo del drawer
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2B5F8C), Color(0xFF1A4A6B)],
              ),
            ),
          ),

          // Contenido principal con animación
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

          // Overlay semitransparente
          if (_isMenuOpen)
            Positioned.fill(
              child: GestureDetector(
                onTap: _toggleMenu,
                behavior: HitTestBehavior.translucent,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3),
                ),
              ),
            ),

          // Menú lateral
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

          // Botones superiores
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Row(
              children: [
                _buildMenuButton(),
                const SizedBox(width: 12),
                if (widget.currentRoute != '/cart' &&
                    widget.currentRoute != '/marketplace-cart')
                  _buildCartBadges(),
              ],
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
            color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildCartBadges() {
    return Row(
      children: [
        if (_cartService.totalItems > 0)
          _buildCartBadge(
            icon: Icons.shopping_cart_outlined,
            count: _cartService.totalItems,
            route: '/cart',
            color: const Color(0xFF6B8E3D),
          ),
        const SizedBox(width: 8),
        if (_marketplaceCartService.totalItems > 0)
          _buildCartBadge(
            icon: Icons.store,
            count: _marketplaceCartService.totalItems,
            route: '/marketplace-cart',
            color: const Color(0xFF2B5F8C),
          ),
      ],
    );
  }

  Widget _buildCartBadge({
    required IconData icon,
    required int count,
    required String route,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, route),
      child: Stack(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              constraints: const BoxConstraints(
                minWidth: 20,
                minHeight: 20,
              ),
              child: Center(
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSideMenu() {
    final user = AuthService.currentUser;
    final userName = user?.userMetadata?['full_name'] ?? 'User';
    final userEmail = user?.email ?? '';
    final userInitial = (user?.email?.substring(0, 1).toUpperCase() ?? 'U');

    return SizedBox(
      width: _menuWidth,
      child: Material(
        color: Colors.transparent,
        child: SafeArea(
          child: Column(
            children: [
              _buildUserHeader(userInitial, userName, userEmail),
              Expanded(child: _buildMenuItems()),
              _buildMenuFooter(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(String initial, String name, String email) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white,
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 28,
                color: Color(0xFF2B5F8C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // 🆕 Badge del rol
                    if (!_isLoadingRole) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getRoleBadgeColor(),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getRoleBadgeText(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 Helpers para badge de rol
  Color _getRoleBadgeColor() {
    switch (_userRole) {
      case 'admin':
        return const Color(0xFFDC2626); // Rojo
      case 'supervisor':
        return const Color(0xFF6B8E3D); // Verde
      default:
        return const Color(0xFF2B5F8C); // Azul
    }
  }

  String _getRoleBadgeText() {
    switch (_userRole) {
      case 'admin':
        return 'ADMIN';
      case 'supervisor':
        return 'SUPERVISOR';
      default:
        return 'USER';
    }
  }

  Widget _buildMenuItems() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      physics: const BouncingScrollPhysics(),
      children: [
        // ========================================
        // SECCIÓN: PRINCIPAL (TODOS LOS USUARIOS)
        // ========================================
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

        _buildCartMenuItem('/cart', 'Take Out Stock', _cartService),

        const Divider(height: 24, color: Colors.white24),

        // ========================================
        // SECCIÓN: SUPPLIERS (Admin/Supervisor)
        // ========================================
        if (_isAdminOrSupervisor && !_isLoadingRole) ...[
          _buildSectionHeader('Suppliers'),

          _buildExpandableMenuItem(
            icon: Icons.business_outlined,
            title: 'Suppliers',
            routes: {
              '/suppliers': 'All Suppliers',
              '/suppliers/dashboard': 'Dashboard',
              '/suppliers/products-without': 'Products Without Supplier',
            },
          ),

          _buildMenuItem(DrawerMenuItem(
            icon: Icons.add_box_outlined,
            title: 'Restock Management',
            route: '/restock-management',
            isSelected: widget.currentRoute == '/restock-management',
          )),

          if (_isAdmin) // Solo admin puede completar órdenes con QR
            _buildMenuItem(DrawerMenuItem(
              icon: Icons.qr_code_2,
              title: 'Complete Order (QR)',
              route: '/qr-complete-order',
              isSelected: widget.currentRoute == '/qr-complete-order',
            )),

          const Divider(height: 24, color: Colors.white24),
        ],

        // ========================================
        // SECCIÓN: ORDERS (Admin/Supervisor)
        // ========================================
        if (_isAdminOrSupervisor && !_isLoadingRole) ...[
          _buildSectionHeader('Orders'),

          _buildMenuItem(DrawerMenuItem(
            icon: Icons.receipt_long_outlined,
            title: 'General Orders',
            route: '/general-orders',
            isSelected: widget.currentRoute == '/general-orders',
          )),

          /*_buildMenuItem(DrawerMenuItem(
            icon: Icons.shopping_bag_outlined,
            title: 'Marketplace Orders',
            route: '/orders',
            isSelected: widget.currentRoute == '/orders',
          )),*/

          const Divider(height: 24, color: Colors.white24),
        ],

        // ========================================
        // SECCIÓN: MARKETPLACE (Admin/Supervisor)
        // ========================================
        if (_isAdminOrSupervisor && !_isLoadingRole) ...[
          _buildSectionHeader('Marketplace'),

          _buildMenuItem(DrawerMenuItem(
            icon: Icons.store_outlined,
            title: 'Browse Products',
            route: '/marketplace',
            isSelected: widget.currentRoute == '/marketplace',
          )),

          /*_buildCartMenuItem(
              '/marketplace-cart',
              'Marketplace Cart',
              _marketplaceCartService
          ),*/

          const Divider(height: 24, color: Colors.white24),
        ],

        // ========================================
        // SECCIÓN: SUPPLIER MODE (Si es proveedor)
        // ========================================
        if (_isSupplier) ...[
          _buildSectionHeader('I\'m a Supplier'),

          _buildMenuItem(DrawerMenuItem(
            icon: Icons.dashboard_outlined,
            title: 'Supplier Panel',
            route: '/supplier-management',
            isSelected: widget.currentRoute == '/supplier-management',
          )),

          const Divider(height: 24, color: Colors.white24),
        ],

        // ========================================
        // SECCIÓN: OPERATIONS (Admin/Supervisor)
        // ========================================
        if (_isAdminOrSupervisor && !_isLoadingRole) ...[
          _buildSectionHeader('Operations'),

          _buildMenuItem(DrawerMenuItem(
            icon: Icons.swap_horiz_outlined,
            title: 'Transfers',
            route: '/transfers',
            isSelected: widget.currentRoute == '/transfers',
          )),

          _buildMenuItem(DrawerMenuItem(
            icon: Icons.analytics_outlined,
            title: 'Reports',
            route: '/reports',
            isSelected: widget.currentRoute == '/reports',
          )),

          const Divider(height: 24, color: Colors.white24),
        ],

        // ========================================
        // SECCIÓN: ADMINISTRATION (Solo Admin)
        // ========================================
        if (_isAdmin && !_isLoadingRole) ...[
          _buildSectionHeader('Administration'),

          _buildMenuItem(DrawerMenuItem(
            icon: Icons.settings_outlined,
            title: 'Company Settings',
            route: '/company-settings',
            isSelected: widget.currentRoute == '/company-settings',
          )),

          const Divider(height: 24, color: Colors.white24),
        ],

        // ========================================
        // SECCIÓN: HELP (TODOS LOS USUARIOS)
        // ========================================
        _buildMenuItem(DrawerMenuItem(
          icon: Icons.help_outline,
          title: 'Help & Support',
          route: '/help',
          isSelected: widget.currentRoute == '/help',
        )),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 5),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildExpandableMenuItem({
    required IconData icon,
    required String title,
    required Map<String, String> routes,
  }) {
    final isAnySelected = routes.keys.any((route) => widget.currentRoute == route);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          leading: Icon(
            icon,
            color: isAnySelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.8),
            size: 24,
          ),
          title: Text(
            title,
            style: TextStyle(
              color: isAnySelected
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.8),
              fontSize: 16,
              fontWeight: isAnySelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          trailing: Icon(
            Icons.keyboard_arrow_down,
            color: isAnySelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.8),
          ),
          children: routes.entries.map((entry) {
            final isSelected = widget.currentRoute == entry.key;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _onMenuItemTap(entry.key),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.8),
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildCartMenuItem(String route, String title, dynamic cartService) {
    final isSelected = widget.currentRoute == route;
    final totalItems = cartService.totalItems as int;
    final totalAmount = cartService.totalAmount as double;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(15),
          onTap: () => _onMenuItemTap(route),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: isSelected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                Stack(
                  children: [
                    Icon(
                      route == '/cart'
                          ? Icons.shopping_cart_outlined
                          : Icons.store_outlined,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8),
                      size: 24,
                    ),
                    if (totalItems > 0)
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6B8E3D),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(color: Colors.white, width: 1),
                          ),
                          child: Text(
                            totalItems > 99 ? '99+' : totalItems.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
                if (totalItems > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B8E3D),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '\$${totalAmount.toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(DrawerMenuItem item) {
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
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(15),
              border: item.isSelected
                  ? Border.all(color: Colors.white.withValues(alpha: 0.3))
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  item.icon,
                  color: item.isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.8),
                  size: 24,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Text(
                    item.title,
                    style: TextStyle(
                      color: item.isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.8),
                      fontSize: 16,
                      fontWeight: item.isSelected ? FontWeight.w600 : FontWeight.normal,
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
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Divider(color: Colors.white.withValues(alpha: 0.3)),
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
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.logout,
                      color: Colors.red.withValues(alpha: 0.8),
                      size: 24,
                    ),
                    const SizedBox(width: 15),
                    Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
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
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: _handleDeleteAccount,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  color: Colors.red.withValues(alpha: 0.12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.delete_forever,
                      color: Colors.red.withValues(alpha: 0.9),
                      size: 24,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        'Eliminar cuenta',
                        style: TextStyle(
                          color: Colors.red.withValues(alpha: 0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
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
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _onMenuItemTap(String route) {
    if (widget.currentRoute == route) {
      _toggleMenu();
      return;
    }

    _toggleMenu();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;

      switch (route) {
        case '/home':
          Navigator.pushReplacementNamed(context, '/home');
          break;
        case '/inventory':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const InventoryScreen()),
          );
          break;
        case '/cart':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShoppingCartScreen()),
          );
          break;
        case '/qr-complete-order':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const QRCompleteOrderScreen()),
          );
          break;
        case '/general-orders':
          Navigator.pushReplacementNamed(context, '/general-orders');
          break;
        case '/orders':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const OrdersScreen()),
          );
          break;
        case '/marketplace':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SupplyMarketplaceScreen()),
          );
          break;
        case '/marketplace-cart':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const MarketplaceCartScreen()),
          );
          break;
        case '/supplier-management':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SupplierManagementScreen()),
          );
          break;
        case '/transfers':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TransferScreen()),
          );
          break;
        case '/suppliers':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SupplyCompanyScreen()),
          );
          break;
        case '/suppliers/dashboard':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SupplierDashboard()),
          );
          break;
        case '/suppliers/products-without':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ProductsWithoutSupplierScreen()),
          );
          break;
        case '/reports':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const InventoryReportsScreen()),
          );
          break;
        case '/company-settings':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const CompanySettingsScreen()),
          );
          break;
        case '/restock-management':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const RestockManagementScreen()),
          );
          break;
        case '/help':
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HelpSupportScreen()),
          );
          break;
        case '/settings':

          _showModuleInfo(route);
          break;
      }
    });
  }

  void _showModuleInfo(String route) {
    if (!mounted) return;

    final moduleName = route.replaceFirst('/', '').capitalize();
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              Icon(_getModuleIcon(moduleName), color: const Color(0xFF2B5F8C)),
              const SizedBox(width: 10),
              Flexible(child: Text(moduleName, overflow: TextOverflow.ellipsis)),
            ],
          ),
          content: Text('$moduleName module is currently in development.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Got it!', style: TextStyle(color: Color(0xFF6B8E3D))),
            ),
          ],
        );
      },
    );
  }

  IconData _getModuleIcon(String moduleName) {
    switch (moduleName.toLowerCase()) {
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
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } catch (e) {
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

  /// Borrado permanente de cuenta. Requerido por App Store Guideline 5.1.1(v).
  Future<void> _handleDeleteAccount() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar cuenta'),
        content: const Text(
          'Esta acción es permanente y no se puede deshacer.\n\n'
          'Se eliminarán tu perfil, todo tu inventario, tus ubicaciones, '
          'las fotos de productos y tus órdenes de reabastecimiento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar mi cuenta'),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await AccountDeletionService.deleteAccount();
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
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