import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';
import '../../widgets/collapsible_drawer.dart';

/// Full company settings screen
class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Map<String, dynamic>? _companyInfo;
  List<Map<String, dynamic>> _users = [];
  Map<String, dynamic>? _currentUserProfile;
  bool _isLoading = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final companyInfo = await InventoryService.getCurrentCompanyInfo();
      final users = await InventoryService.getCompanyUsers();
      final userId = AuthService.currentUser?.id;

      // Get current user profile
      Map<String, dynamic>? currentProfile;
      if (userId != null) {
        final response = await AuthService.client
            .from('profiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        currentProfile = response;
      }

      if (mounted) {
        setState(() {
          _companyInfo = companyInfo;
          _users = users;
          _currentUserProfile = currentProfile;
          _isAdmin = currentProfile?['role'] == 'admin' || currentProfile?['role'] == 'owner';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/company-settings',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Company Settings'),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          automaticallyImplyLeading: false,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.business), text: 'General'),
              Tab(icon: Icon(Icons.people), text: 'Users'),
              Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B8E3D)))
            : TabBarView(
          controller: _tabController,
          children: [
            _buildGeneralTab(),
            _buildUsersTab(),
            _buildStatsTab(),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // TAB 1: GENERAL
  // ========================================================================

  Widget _buildGeneralTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF6B8E3D),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildCompanyInfoCard(),
          const SizedBox(height: 16),
          _buildAddressCard(),
          const SizedBox(height: 16),
          _buildCurrentUserCard(),
        ],
      ),
    );
  }

  Widget _buildCompanyInfoCard() {
    final companyName = _companyInfo?['company_name'] ?? 'No name';
    final userCount = _companyInfo?['user_count'] ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B5F8C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.business,
                    color: Color(0xFF2B5F8C),
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company Name',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        companyName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B5F8C),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isAdmin)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: _showEditCompanyNameDialog,
                    color: const Color(0xFF6B8E3D),
                  ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                _buildInfoChip(
                  Icons.people,
                  '$userCount users',
                  const Color(0xFF6B8E3D),
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.verified,
                  'Active',
                  Colors.green,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    final address = _companyInfo?['address'] as Map<String, dynamic>?;
    final hasAddress = address != null && address.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFF2B5F8C)),
                const SizedBox(width: 8),
                const Text(
                  'Address',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
                const Spacer(),
                if (_isAdmin)
                  TextButton.icon(
                    onPressed: _showEditAddressDialog,
                    icon: Icon(hasAddress ? Icons.edit : Icons.add),
                    label: Text(hasAddress ? 'Edit' : 'Add'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B8E3D),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (hasAddress) ...[
              _buildAddressInfo(address),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'No registered address',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAddressInfo(Map<String, dynamic> address) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (address['street'] != null && address['street'].toString().isNotEmpty)
          _buildAddressRow(Icons.home, address['street']),
        if (address['city'] != null && address['city'].toString().isNotEmpty)
          _buildAddressRow(Icons.location_city, address['city']),
        if (address['country'] != null && address['country'].toString().isNotEmpty)
          _buildAddressRow(Icons.public, address['country']),
        if (address['postal_code'] != null && address['postal_code'].toString().isNotEmpty)
          _buildAddressRow(Icons.mail, address['postal_code']),
      ],
    );
  }

  Widget _buildAddressRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentUserCard() {
    final fullName = _currentUserProfile?['full_name'] ?? 'No name';
    final email = AuthService.currentUser?.email ?? 'No email';
    final role = _currentUserProfile?['role'] ?? 'user';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.person, color: Color(0xFF2B5F8C)),
                SizedBox(width: 8),
                Text(
                  'My Profile',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: const Color(0xFF2B5F8C),
                  child: Text(
                    fullName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(role).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRoleText(role),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getRoleColor(role),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // TAB 2: USERS
  // ========================================================================

  Widget _buildUsersTab() {
    if (!_isAdmin) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Only administrators can view this section',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No users in your company',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Reload'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF6B8E3D),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _users.length,
        itemBuilder: (context, index) => _buildUserCard(_users[index]),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final fullName = user['full_name'] ?? 'No name';
    final email = user['email'] ?? 'No email';
    final role = user['role'] ?? 'user';
    final isCurrentUser = user['id'] == AuthService.currentUser?.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF2B5F8C),
          child: Text(
            fullName[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                fullName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B5F8C).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(email, style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _getRoleColor(role).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getRoleText(role),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: _getRoleColor(role),
                ),
              ),
            ),
          ],
        ),
        trailing: _isAdmin && !isCurrentUser
            ? PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) => _handleUserAction(value, user),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'change_role',
              child: Row(
                children: [
                  Icon(Icons.admin_panel_settings, size: 16),
                  SizedBox(width: 8),
                  Text('Change Role'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Remove', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        )
            : null,
      ),
    );
  }

  // ========================================================================
  // TAB 3: STATISTICS
  // ========================================================================

  Widget _buildStatsTab() {
    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF6B8E3D),
      child: FutureBuilder<Map<String, dynamic>>(
        future: InventoryService.getInventoryStats(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
            );
          }

          final stats = snapshot.data!;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildStatCard(
                'Inventory',
                [
                  _StatItem('Total Products', '${stats['productos_activos']}', Icons.inventory, const Color(0xFF6B8E3D)),
                  _StatItem('Out of Stock', '${stats['productos_sin_stock']}', Icons.warning, Colors.red),
                  _StatItem('Low Stock', '${stats['productos_stock_bajo']}', Icons.trending_down, Colors.orange),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Locations',
                [
                  _StatItem('Total', '${stats['ubicaciones_activas']}', Icons.location_on, const Color(0xFF2B5F8C)),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Value',
                [
                  _StatItem(
                    'Total Value',
                    '\$${(stats['valor_total_inventario'] ?? 0.0).toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.green,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildStatCard(
                'Users',
                [
                  _StatItem('Total Users', '${_companyInfo?['user_count'] ?? 0}', Icons.people, const Color(0xFF6B8E3D)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatCard(String title, List<_StatItem> items) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
            ),
            const SizedBox(height: 16),
            ...items.map((item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: item.color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: item.color,
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // DIALOGS
  // ========================================================================

  void _showEditCompanyNameDialog() {
    final controller = TextEditingController(
      text: _companyInfo?['company_name'] ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Company Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isEmpty) {
                _showErrorSnackBar('Name cannot be empty');
                return;
              }

              try {
                await InventoryService.updateCompanyInfo({
                  'company_name': newName,
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('Name updated');
                  _loadData();
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnackBar('Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showEditAddressDialog() {
    final address = _companyInfo?['address'] as Map<String, dynamic>? ?? {};

    final streetController = TextEditingController(text: address['street'] ?? '');
    final cityController = TextEditingController(text: address['city'] ?? '');
    final countryController = TextEditingController(text: address['country'] ?? '');
    final postalCodeController = TextEditingController(text: address['postal_code'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: streetController,
                decoration: const InputDecoration(
                  labelText: 'Street',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.home),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: cityController,
                decoration: const InputDecoration(
                  labelText: 'City',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_city),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: countryController,
                decoration: const InputDecoration(
                  labelText: 'Country',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.public),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: postalCodeController,
                decoration: const InputDecoration(
                  labelText: 'Postal Code',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.mail),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await InventoryService.updateCompanyInfo({
                  'address': {
                    'street': streetController.text.trim(),
                    'city': cityController.text.trim(),
                    'country': countryController.text.trim(),
                    'postal_code': postalCodeController.text.trim(),
                  },
                });

                if (context.mounted) {
                  Navigator.pop(context);
                  _showSuccessSnackBar('Address updated');
                  _loadData();
                }
              } catch (e) {
                if (context.mounted) {
                  _showErrorSnackBar('Error: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'change_role':
        _showChangeRoleDialog(user);
        break;
      case 'remove':
        _showRemoveUserDialog(user);
        break;
    }
  }

  void _showChangeRoleDialog(Map<String, dynamic> user) {
    final currentRole = user['role'] ?? 'user';
    String selectedRole = currentRole;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Change Role for ${user['full_name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('User'),
                subtitle: const Text('Basic access'),
                value: 'user',
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
              RadioListTile<String>(
                title: const Text('Administrator'),
                subtitle: const Text('Can manage company'),
                value: 'admin',
                groupValue: selectedRole,
                onChanged: (value) => setState(() => selectedRole = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await AuthService.client
                      .from('profiles')
                      .update({'role': selectedRole})
                      .eq('id', user['id']);

                  if (context.mounted) {
                    Navigator.pop(context);
                    _showSuccessSnackBar('Role updated');
                    _loadData();
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showErrorSnackBar('Error: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRemoveUserDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove User'),
        content: Text(
          'Are you sure you want to remove ${user['full_name']} from the company?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // TODO: Implement removal logic
              Navigator.pop(context);
              _showErrorSnackBar('Function not implemented');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // UTILITIES
  // ========================================================================

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleText(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'admin':
        return 'Administrator';
      case 'user':
        return 'User';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const Color(0xFF8B5A2B);
      case 'admin':
        return const Color(0xFF2B5F8C);
      case 'user':
        return const Color(0xFF6B8E3D);
      default:
        return Colors.grey;
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E3D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// Helper class for statistics items
class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  _StatItem(this.label, this.value, this.icon, this.color);
}