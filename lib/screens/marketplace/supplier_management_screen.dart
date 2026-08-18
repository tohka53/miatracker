import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/auth_service.dart';
import '../../services/inventory_service.dart';

/// Pantalla para que proveedores gestionen sus productos
class SupplierManagementScreen extends StatefulWidget {
  const SupplierManagementScreen({super.key});

  @override
  State<SupplierManagementScreen> createState() => _SupplierManagementScreenState();
}

class _SupplierManagementScreenState extends State<SupplierManagementScreen> {
  Map<String, dynamic>? _supplierInfo;
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        throw Exception('Company not found');
      }

      // Obtener información del proveedor
      final supplierResponse = await AuthService.client
          .from('supply_company')
          .select()
          .eq('id_company', companyId)
          .maybeSingle();

      // Si no existe, crear proveedor
      if (supplierResponse == null) {
        await _createSupplier(companyId);
        return;
      }

      // Obtener productos
      final productsResponse = await AuthService.client
          .from('supply_products')
          .select()
          .eq('id_supply_company', supplierResponse['id'])
          .order('created_at', ascending: false);

      // Obtener pedidos recibidos
      final ordersResponse = await AuthService.client
          .from('supply_orders')
          .select('''
            *,
            company!inner(company_name)
          ''')
          .eq('id_supply_company', supplierResponse['id'])
          .order('created_at', ascending: false)
          .limit(20);

      if (mounted) {
        setState(() {
          _supplierInfo = supplierResponse;
          _products = List<Map<String, dynamic>>.from(productsResponse);
          _orders = List<Map<String, dynamic>>.from(ordersResponse);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _createSupplier(int companyId) async {
    final companyInfo = await InventoryService.getCurrentCompanyInfo();

    await AuthService.client.from('supply_company').insert({
      'id_company': companyId,
      'name': companyInfo?['company_name'] ?? 'Mi Empresa',
      'is_public': false,
      'status': 1,
    });

    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supplier Panel'),
        backgroundColor: const Color(0xFF2B5F8C),
        foregroundColor: Colors.white,
        bottom: TabBar(
          indicatorColor: Colors.white,
          onTap: (index) => setState(() => _selectedTab = index),
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Dashboard'),
            Tab(icon: Icon(Icons.inventory), text: 'Products'),
            Tab(icon: Icon(Icons.shopping_bag), text: 'Pedidos'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B8E3D)))
          : TabBarView(
        children: [
          _buildDashboard(),
          _buildProductsTab(),
          _buildOrdersTab(),
        ],
      ),
      floatingActionButton: _selectedTab == 1
          ? FloatingActionButton.extended(
        onPressed: _showAddProductDialog,
        backgroundColor: const Color(0xFF6B8E3D),
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      )
          : null,
    );
  }

  Widget _buildDashboard() {
    final isPublic = _supplierInfo?['is_public'] ?? false;
    final isVerified = _supplierInfo?['is_verified'] ?? false;
    final rating = _supplierInfo?['rating'] ?? 0.0;
    final totalReviews = _supplierInfo?['total_reviews'] ?? 0;

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF6B8E3D),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Estado del proveedor
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.store, color: Color(0xFF2B5F8C)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _supplierInfo?['name'] ?? 'No name',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B5F8C),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildStatusChip(
                        isPublic ? 'Public' : 'Privado',
                        isPublic ? Colors.green : Colors.grey,
                        isPublic ? Icons.visibility : Icons.visibility_off,
                      ),
                      const SizedBox(width: 8),
                      if (isVerified)
                        _buildStatusChip(
                          'Verificado',
                          const Color(0xFF2B5F8C),
                          Icons.verified,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      ...List.generate(
                        5,
                            (i) => Icon(
                          i < rating.round() ? Icons.star : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '$rating ($totalReviews reviews)',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _togglePublicStatus(!isPublic),
                      icon: Icon(isPublic ? Icons.visibility_off : Icons.visibility),
                      label: Text(isPublic ? 'Hacer Privado' : 'Make Public'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPublic ? Colors.grey : const Color(0xFF6B8E3D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Estadísticas
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Products',
                  '${_products.length}',
                  Icons.inventory,
                  const Color(0xFF6B8E3D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Pedidos',
                  '${_orders.length}',
                  Icons.shopping_bag,
                  const Color(0xFF2B5F8C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Pending',
                  '${_orders.where((o) => o['status'] == 'pending').length}',
                  Icons.pending,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Completados',
                  '${_orders.where((o) => o['status'] == 'delivered').length}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductsTab() {
    if (_products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No tienes productos publicados',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showAddProductDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add First Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
              ),
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
        itemCount: _products.length,
        itemBuilder: (context, index) => _buildProductCard(_products[index]),
      ),
    );
  }

  Widget _buildOrdersTab() {
    if (_orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No has recibido pedidos',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
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
        itemCount: _orders.length,
        itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final disponible = product['disponible'] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: product['imagen'] != null
              ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: product['imagen'],
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const Icon(Icons.inventory),
            ),
          )
              : const Icon(Icons.inventory, color: Colors.grey),
        ),
        title: Text(
          product['nombre_producto'] ?? 'No name',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${product['precio_base'] ?? 0}'),
            Text(
              'Stock: ${product['stock_disponible'] ?? 0}',
              style: TextStyle(
                fontSize: 11,
                color: disponible ? const Color(0xFF6B8E3D) : Colors.red,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: disponible
                    ? const Color(0xFF6B8E3D).withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                disponible ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: disponible ? const Color(0xFF6B8E3D) : Colors.red,
                ),
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'toggle', child: Text('Activar/Desactivar')),
                const PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
              onSelected: (value) => _handleProductAction(value, product),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final status = order['status'] ?? 'pending';
    final company = order['company'];
    final companyName = company?['company_name'] ?? 'Cliente';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pedido #${order['order_number']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        companyName,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(
                  _getStatusText(status),
                  _getStatusColor(status),
                  Icons.circle,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${order['total_productos']} productos'),
                Text(
                  '\$${order['total'] ?? 0}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF6B8E3D),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending': return 'Pending';
      case 'confirmed': return 'Confirmed';
      case 'shipped': return 'Shipped';
      case 'delivered': return 'Delivered';
      case 'cancelled': return 'Cancelled';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'confirmed': return Colors.blue;
      case 'shipped': return Colors.purple;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  void _handleProductAction(String action, Map<String, dynamic> product) {
    switch (action) {
      case 'edit':
        _showEditProductDialog(product);
        break;
      case 'toggle':
        _toggleProductStatus(product);
        break;
      case 'delete':
        _deleteProduct(product);
        break;
    }
  }

  Future<void> _togglePublicStatus(bool makePublic) async {
    try {
      await AuthService.client
          .from('supply_company')
          .update({'is_public': makePublic})
          .eq('id', _supplierInfo!['id']);

      _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(makePublic
                ? 'Catalog is now public'
                : 'Catalog is now private'),
            backgroundColor: const Color(0xFF6B8E3D),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleProductStatus(Map<String, dynamic> product) async {
    final newStatus = !(product['disponible'] ?? false);

    try {
      await AuthService.client
          .from('supply_products')
          .update({'disponible': newStatus})
          .eq('id_supply_product', product['id_supply_product']);

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteProduct(Map<String, dynamic> product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete product'),
        content: Text('Delete ${product['nombre_producto']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AuthService.client
            .from('supply_products')
            .update({'status': 0})
            .eq('id_supply_product', product['id_supply_product']);

        _loadData();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showAddProductDialog() {
    // TODO: Implementar diálogo de agregar producto
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feature to be implemented')),
    );
  }

  void _showEditProductDialog(Map<String, dynamic> product) {
    // TODO: Implementar diálogo de editar producto
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Feature to be implemented')),
    );
  }
}