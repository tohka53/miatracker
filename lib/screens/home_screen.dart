import 'package:flutter/material.dart';
import '../widgets/mia_logo.dart';
import '../widgets/collapsible_drawer.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userEmail;
  Map<String, dynamic> dashboardStats = {};
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadDashboardStats();
  }

  void _loadUserInfo() {
    final user = AuthService.currentUser;
    setState(() {
      userEmail = user?.email;
    });
  }

  Future<void> _loadDashboardStats() async {
    try {
      final stats = await DatabaseService.getDashboardStats();
      setState(() {
        dashboardStats = stats;
        _isLoadingStats = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingStats = false;
      });
    }
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
            child: SingleChildScrollView(
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

                  // Stats Cards
                  _buildStatsSection(),
                  const SizedBox(height: 20),

                  // Quick Actions
                  _buildQuickActionsSection(),
                  const SizedBox(height: 20),

                  // Recent Activity (placeholder)
                  _buildRecentActivitySection(),
                ],
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
                    Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    Text(
                      userEmail ?? 'User',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF6B8E3D),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
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
                DateTime.now().toString().substring(0, 16),
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

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Dashboard Overview',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 12),
        if (_isLoadingStats)
          const Center(child: CircularProgressIndicator())
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
              ),
              _buildStatCard(
                title: 'Active Assets',
                value: dashboardStats['active_assets']?.toString() ?? '0',
                icon: Icons.check_circle_outlined,
                color: const Color(0xFF6B8E3D),
              ),
              _buildStatCard(
                title: 'Pending Maintenance',
                value: dashboardStats['pending_maintenance']?.toString() ?? '0',
                icon: Icons.build_outlined,
                color: const Color(0xFFF59E0B),
              ),
              _buildStatCard(
                title: 'Completed Tasks',
                value: dashboardStats['completed_maintenance']?.toString() ?? '0',
                icon: Icons.done_all_outlined,
                color: const Color(0xFF8B5A2B),
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
  }) {
    return Container(
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
                title: 'Add Asset',
                subtitle: 'Register new equipment',
                icon: Icons.add_circle_outline,
                color: const Color(0xFF6B8E3D),
                onTap: () => _showModuleInfo('Add Asset'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                title: 'Schedule Maintenance',
                subtitle: 'Plan upcoming tasks',
                icon: Icons.schedule_outlined,
                color: const Color(0xFF2B5F8C),
                onTap: () => _showModuleInfo('Schedule Maintenance'),
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
        const Text(
          'Recent Activity',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
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
                'Start by adding your first asset or scheduling maintenance tasks.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _showModuleInfo('Get Started'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Get Started'),
              ),
            ],
          ),
        ),
      ],
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
                  '$moduleName feature is currently in development.',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This feature will connect to your Supabase database to provide real-time functionality.',
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
      case 'add asset':
        return Icons.add_circle_outline;
      case 'schedule maintenance':
        return Icons.schedule_outlined;
      case 'get started':
        return Icons.rocket_launch_outlined;
      default:
        return Icons.help;
    }
  }
}