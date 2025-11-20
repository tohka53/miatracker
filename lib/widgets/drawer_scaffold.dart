import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class DrawerScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final String currentRoute;
  final FloatingActionButton? floatingActionButton;
  final List<Widget>? actions;

  const DrawerScaffold({
    super.key,
    required this.title,
    required this.body,
    required this.currentRoute,
    this.floatingActionButton,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF2B5F8C),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      drawer: _buildDrawer(context),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final user = AuthService.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF2B5F8C),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                user?.email?.substring(0, 1).toUpperCase() ?? 'U',
                style: const TextStyle(
                  fontSize: 24,
                  color: Color(0xFF2B5F8C),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            accountName: Text(
              user?.userMetadata?['full_name'] ?? 'Usuario',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user?.email ?? ''),
          ),

          // Dashboard
          _buildDrawerItem(
            context,
            icon: Icons.dashboard,
            title: 'Dashboard',
            route: '/dashboard',
          ),

          const Divider(),

          // Sección de Inventario
          _buildDrawerHeader('Inventory'),

          _buildDrawerItem(
            context,
            icon: Icons.inventory_2,
            title: 'Productos',
            route: '/inventory',
          ),

          _buildDrawerItem(
            context,
            icon: Icons.location_on,
            title: 'Ubicaciones',
            route: '/locations',
          ),

          _buildDrawerItem(
            context,
            icon: Icons.qr_code_scanner,
            title: 'Escanear',
            route: '/scan',
          ),

          const Divider(),

          // Sección de Operaciones
          _buildDrawerHeader('OPERACIONES'),

          _buildDrawerItem(
            context,
            icon: Icons.swap_horiz,
            title: 'Transferencias',
            route: '/transfers',
          ),

          _buildDrawerItem(
            context,
            icon: Icons.add_shopping_cart,
            title: 'Nueva Entrada',
            route: '/new-entry',
          ),

          _buildDrawerItem(
            context,
            icon: Icons.remove_shopping_cart,
            title: 'Salidas',
            route: '/exits',
          ),

          const Divider(),

          // Sección de Assets (si lo usas)
          _buildDrawerHeader('ACTIVOS'),

          _buildDrawerItem(
            context,
            icon: Icons.business_center,
            title: 'Assets',
            route: '/assets',
          ),

          _buildDrawerItem(
            context,
            icon: Icons.build,
            title: 'Mantenimiento',
            route: '/maintenance',
          ),

          const Divider(),

          // Configuración
          _buildDrawerItem(
            context,
            icon: Icons.settings,
            title: 'Configuración',
            route: '/settings',
          ),

          _buildDrawerItem(
            context,
            icon: Icons.help,
            title: 'Ayuda',
            route: '/help',
          ),

          const Divider(),

          // Cerrar sesión
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.red),
            ),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Cerrar Sesión'),
                  content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Cerrar Sesión'),
                    ),
                  ],
                ),
              );

              if (confirm == true && context.mounted) {
                await AuthService.signOut();
                if (context.mounted) {
                  Navigator.pushReplacementNamed(context, '/login');
                }
              }
            },
          ),

          const SizedBox(height: 16),

          // Versión
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'M.I.A Tracker v1.6.2',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade600,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildDrawerItem(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String route,
      }) {
    final isSelected = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF6B8E3D).withOpacity(0.1) : null,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? const Color(0xFF6B8E3D) : Colors.grey.shade700,
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? const Color(0xFF6B8E3D) : Colors.grey.shade800,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        selected: isSelected,
        onTap: () {
          Navigator.pop(context);
          if (!isSelected) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
      ),
    );
  }
}