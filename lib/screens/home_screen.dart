import 'package:flutter/material.dart';
import '../widgets/mia_logo.dart';
import '../services/auth_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userEmail;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  void _loadUserInfo() {
    final user = AuthService.currentUser;
    setState(() {
      userEmail = user?.email;
    });
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.signOut();
      // AuthWrapper manejará la navegación automáticamente
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MIAAppBar(
        title: 'M.I.A Tracker',
        actions: [
          IconButton(
            icon: _isLoading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
                : const Icon(Icons.logout),
            onPressed: _isLoading ? null : _handleLogout,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F3E8),
              Color(0xFFE8E5D6),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height -
                    AppBar().preferredSize.height -
                    MediaQuery.of(context).padding.top -
                    32, // padding
              ),
              child: Column(
                children: [
                  // Información del usuario conectado
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF6B8E3D),
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '¡Conectado a Supabase!',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B5F8C),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          userEmail ?? 'Usuario desconocido',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B8E3D),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Logo principal
                  const MIALogo(
                    width: 80,
                    height: 80,
                    showBackground: true,
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Welcome to M.I.A Tracker!',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B5F8C),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Inventory and maintenance management system\npowered by Supabase',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF6B8E3D),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Módulos disponibles - Grid responsivo
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Calcular el número de columnas basado en el ancho de pantalla
                      int crossAxisCount = 2;
                      if (constraints.maxWidth > 600) {
                        crossAxisCount = 3;
                      } else if (constraints.maxWidth < 400) {
                        crossAxisCount = 1;
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: crossAxisCount == 1 ? 3 : 1.1,
                        children: [
                          _buildModuleCard(
                            icon: Icons.inventory,
                            title: 'Inventory',
                            description: 'Manage assets and equipment',
                            color: const Color(0xFF2B5F8C),
                            onTap: () => _showModuleInfo('Inventory'),
                          ),
                          _buildModuleCard(
                            icon: Icons.build,
                            title: 'Maintenance',
                            description: 'Schedule and track maintenance',
                            color: const Color(0xFF6B8E3D),
                            onTap: () => _showModuleInfo('Maintenance'),
                          ),
                          _buildModuleCard(
                            icon: Icons.analytics,
                            title: 'Reports',
                            description: 'View analytics and insights',
                            color: const Color(0xFF8B5A2B),
                            onTap: () => _showModuleInfo('Reports'),
                          ),
                          _buildModuleCard(
                            icon: Icons.settings,
                            title: 'Settings',
                            description: 'Configure your preferences',
                            color: const Color(0xFF5A5A5A),
                            onTap: () => _showModuleInfo('Settings'),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Información de conexión a Supabase
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B5F8C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF2B5F8C).withOpacity(0.3),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.cloud_done,
                          color: Color(0xFF2B5F8C),
                          size: 28,
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Database Status: Connected',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B5F8C),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Real-time data synchronization active',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2B5F8C),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Espaciado adicional para evitar que se corte el contenido
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModuleCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.1),
                color.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  description,
                  style: TextStyle(
                    fontSize: 10,
                    color: color.withOpacity(0.8),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showModuleInfo(String moduleName) {
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
                  'This module will connect to your Supabase database to provide real-time functionality for managing your assets and maintenance schedules.',
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
    switch (moduleName) {
      case 'Inventory':
        return Icons.inventory;
      case 'Maintenance':
        return Icons.build;
      case 'Reports':
        return Icons.analytics;
      case 'Settings':
        return Icons.settings;
      default:
        return Icons.help;
    }
  }
}