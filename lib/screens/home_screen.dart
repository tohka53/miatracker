import 'package:flutter/material.dart';
import '../widgets/mia_logo.dart';
import '../widgets/collapsible_drawer.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../screens/inventory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userEmail;
  String displayName = 'Usuario';
  Map<String, dynamic> dashboardStats = {};
  Map<String, dynamic> inventoryStats = {};
  bool _isLoadingStats = true;
  bool _isLoadingProfile = true;
  bool _isLoadingInventory = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadDashboardStats();
    _loadInventoryStats();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = AuthService.currentUser;
      setState(() {
        userEmail = user?.email;
      });

      await ProfileService.ensureProfileExists();
      final name = await ProfileService.getUserDisplayName();

      if (mounted) {
        setState(() {
          displayName = name;
          _isLoadingProfile = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          displayName = 'Usuario';
          _isLoadingProfile = false;
        });
      }
    }
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await DatabaseService.getDashboardStats();
      if (mounted) {
        setState(() {
          dashboardStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
        });
      }
    }
  }

  Future<void> _loadInventoryStats() async {
    try {
      final stats = await InventoryService.getInventoryStats();
      if (mounted) {
        setState(() {
          inventoryStats = stats;
          _isLoadingInventory = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingInventory = false;
        });
      }
    }
  }

  Future<void> _refreshData() async {
    await Future.wait([
      _loadDashboardStats(),
      _loadInventoryStats(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/home',
      child: Scaffold(
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
            child: RefreshIndicator(
              onRefresh: _refreshData,
              color: const Color(0xFF6B8E3D),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 70, // Space for menu button
                  bottom: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Section
                    _buildWelcomeSection(),
                    const SizedBox(height: 20),

                    // Assets Stats Cards
                    _buildAssetsStatsSection(),
                    const SizedBox(height: 20),

                    // Inventory Stats Cards
                    _buildInventoryStatsSection(),
                    const SizedBox(height: 20),

                    // Quick Actions
                    _buildQuickActionsSection(),
                    const SizedBox(height: 20),

                    // Recent Activity
                    _buildRecentActivitySection(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const MIALogo(
                width: 50,
                height: 50,
                showBackground: true,
                backgroundColor: Color(0xFFF5F3E8),
                borderRadius: 12,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isLoadingProfile
                        ? Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    )
                        : Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        color: Color(0xFF6B8E3D),
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (userEmail != null && !_isLoadingProfile) ...[
                      const SizedBox(height: 2),
                      Text(
                        userEmail!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B8E3D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Color(0xFF6B8E3D),
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF6B8E3D),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Connected to Supabase',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF2B5F8C),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _getFormattedDateTime(),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _getFormattedDateTime() {
    final now = DateTime.now();
    final timeString = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final dateString = '${now.day}/${now.month}/${now.year}';
    return '$timeString • $dateString';
  }

  Widget _buildAssetsStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Assets Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingStats)
          const Center(child: CircularProgressIndicator(
            color: Color(0xFF6B8E3D),
          ))
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                title: 'Total Assets',
                value: dashboardStats['total_assets']?.toString() ?? '0',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF2B5F8C),
                onTap: () => _navigateToInventory(),
              ),
              _buildStatCard(
                title: 'Active Assets',
                value: dashboardStats['active_assets']?.toString() ?? '0',
                icon: Icons.check_circle_outlined,
                color: const Color(0xFF6B8E3D),
                onTap: () => _navigateToInventory(),
              ),
              _buildStatCard(
                title: 'Pending Maintenance',
                value: dashboardStats['pending_maintenance']?.toString() ?? '0',
                icon: Icons.build_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => _showModuleInfo('Maintenance'),
              ),
              _buildStatCard(
                title: 'Completed Tasks',
                value: dashboardStats['completed_maintenance']?.toString() ?? '0',
                icon: Icons.done_all_outlined,
                color: const Color(0xFF8B5A2B),
                onTap: () => _showModuleInfo('Maintenance'),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInventoryStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Inventory Overview',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
            ),
            TextButton.icon(
              onPressed: _navigateToInventory,
              icon: const Icon(Icons.arrow_forward, size: 16),
              label: const Text('Ver Todo'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B8E3D),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingInventory)
          const Center(child: CircularProgressIndicator(
            color: Color(0xFF6B8E3D),
          ))
        else
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.3,
            children: [
              _buildStatCard(
                title: 'Total Productos',
                value: inventoryStats['total_productos']?.toString() ?? '0',
                icon: Icons.inventory_outlined,
                color: const Color(0xFF2B5F8C),
                onTap: () => _navigateToInventory(),
              ),
              _buildStatCard(
                title: 'Productos Activos',
                value: inventoryStats['productos_activos']?.toString() ?? '0',
                icon: Icons.check_circle_outline,
                color: const Color(0xFF6B8E3D),
                onTap: () => _navigateToInventory(),
              ),
              _buildStatCard(
                title: 'Sin Stock',
                value: inventoryStats['productos_sin_stock']?.toString() ?? '0',
                icon: Icons.warning_outlined,
                color: const Color(0xFFEF4444),
                onTap: () => _navigateToInventory(),
              ),
              _buildStatCard(
                title: 'Stock Bajo',
                value: inventoryStats['productos_stock_bajo']?.toString() ?? '0',
                icon: Icons.trending_down_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => _navigateToInventory(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Add Product',
                subtitle: 'Agregar al inventario',
                icon: Icons.add_circle_outline,
                color: const Color(0xFF6B8E3D),
                onTap: () => _navigateToInventory(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'View Inventory',
                subtitle: 'Ver productos',
                icon: Icons.inventory_2_outlined,
                color: const Color(0xFF2B5F8C),
                onTap: () => _navigateToInventory(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                title: 'Schedule Maintenance',
                subtitle: 'Plan upcoming tasks',
                icon: Icons.schedule_outlined,
                color: const Color(0xFFF59E0B),
                onTap: () => _showModuleInfo('Schedule Maintenance'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Create Sample Data',
                subtitle: 'Datos de ejemplo',
                icon: Icons.data_object_outlined,
                color: const Color(0xFF8B5A2B),
                onTap: () => _createSampleData(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivitySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
            ),
            TextButton(
              onPressed: () => _showModuleInfo('View All Activities'),
              child: const Text(
                'View All',
                style: TextStyle(
                  color: Color(0xFF6B8E3D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            children: [
              const Icon(
                Icons.timeline_outlined,
                size: 48,
                color: Color(0xFF6B8E3D),
              ),
              const SizedBox(height: 16),
              const Text(
                'No recent activity',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Start by adding your first asset or inventory item.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _navigateToInventory(),
                icon: const Icon(Icons.rocket_launch_outlined),
                label: const Text('Get Started'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToInventory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const InventoryScreen(),
      ),
    );
  }

  void _createSampleData() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.data_object, color: Color(0xFF2B5F8C)),
            SizedBox(width: 8),
            Text('Create Sample Data'),
          ],
        ),
        content: const Text(
          'This will create sample inventory data including locations and products. This action is useful for testing the application.\n\nDo you want to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await InventoryService.createSampleData();
                Navigator.pop(context);
                _showSuccessSnackBar('Sample data created successfully!');
                _refreshData();
              } catch (e) {
                Navigator.pop(context);
                _showErrorSnackBar('Error creating sample data: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create'),
          ),
        ],
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
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B5F8C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getModuleIcon(moduleName),
                  color: const Color(0xFF2B5F8C),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  moduleName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F3E8),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.construction,
                        size: 32,
                        color: Color(0xFF6B8E3D),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$moduleName feature is currently in development.',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'This feature will connect to your Supabase database to provide real-time functionality for asset management and maintenance tracking.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Got it!',
                style: TextStyle(
                  color: Color(0xFF6B8E3D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  IconData _getModuleIcon(String moduleName) {
    switch (moduleName.toLowerCase()) {
      case 'schedule maintenance':
        return Icons.schedule_outlined;
      case 'view all activities':
        return Icons.list_alt_outlined;
      case 'maintenance':
        return Icons.build_outlined;
      default:
        return Icons.help_outline;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E3D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}