import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/supply_company_service.dart';
import '../../widgets/collapsible_drawer.dart';

/// Dashboard with supplier statistics and inventory value
class SupplierDashboard extends StatefulWidget {
  const SupplierDashboard({super.key});

  @override
  State<SupplierDashboard> createState() => _SupplierDashboardState();
}

class _SupplierDashboardState extends State<SupplierDashboard> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _valueBySupplier = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final stats = await InventoryService.getInventoryStatsWithSuppliers();
      final valueBySupplier = await InventoryService.getInventoryValueBySupplier();

      setState(() {
        _stats = stats;
        _valueBySupplier = valueBySupplier;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/suppliers/dashboard',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          title: const Text(
            'Supplier Dashboard',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B8E3D)))
            : RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF6B8E3D),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGeneralSummary(),
                  const SizedBox(height: 24),
                  _buildSuppliersOverview(),
                  const SizedBox(height: 24),
                  _buildInventoryValue(),
                  const SizedBox(height: 24),
                  Text(
                    'Value by Supplier',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2B5F8C),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildValueBySupplierList(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralSummary() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.secondaryContainer,
            ],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'General Overview',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Active Products',
                    _stats['productos_activos']?.toString() ?? '0',
                    Icons.inventory_2,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Low Stock',
                    _stats['productos_stock_bajo']?.toString() ?? '0',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Out of Stock',
                    _stats['productos_sin_stock']?.toString() ?? '0',
                    Icons.error,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Locations',
                    _stats['ubicaciones_activas']?.toString() ?? '0',
                    Icons.location_on,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSuppliersOverview() {
    final totalSuppliers = _stats['total_proveedores'] ?? 0;
    final activeSuppliers = _stats['proveedores_activos'] ?? 0;
    final productsWithSupplier = _stats['productos_con_proveedor'] ?? 0;
    final productsWithoutSupplier = _stats['productos_sin_proveedor'] ?? 0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.business,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  'Suppliers',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularStat(
                  'Total',
                  totalSuppliers.toString(),
                  Colors.blue,
                ),
                _buildCircularStat(
                  'Active',
                  activeSuppliers.toString(),
                  Colors.green,
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _buildProgressItem(
              'Products with supplier',
              productsWithSupplier,
              productsWithSupplier + productsWithoutSupplier,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildProgressItem(
              'Products without supplier',
              productsWithoutSupplier,
              productsWithSupplier + productsWithoutSupplier,
              Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularStat(String label, String value, Color color) {
    return Column(
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildProgressItem(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '$value / $total',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: percentage,
            minHeight: 10,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryValue() {
    final totalValue = _stats['valor_total_inventario'] ?? 0.0;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green.shade100,
              Colors.teal.shade100,
            ],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet,
                  size: 32,
                  color: Colors.green.shade700,
                ),
                const SizedBox(width: 12),
                Text(
                  'Total Inventory Value',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              InventoryService.formatPrice(totalValue),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildValueBySupplierList() {
    if (_valueBySupplier.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.business_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No products with assigned suppliers',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: _valueBySupplier.map((supplier) {
        return _buildSupplierValueCard(supplier);
      }).toList(),
    );
  }

  Widget _buildSupplierValueCard(Map<String, dynamic> supplier) {
    final totalValue = supplier['total_value'] ?? 0.0;
    final totalProducts = supplier['total_products'] ?? 0;
    final totalStock = supplier['total_stock'] ?? 0;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            (supplier['supplier_name'] as String?)
                ?.substring(0, 1)
                .toUpperCase() ??
                '?',
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          supplier['supplier_name'] ?? 'No name',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('$totalProducts products • $totalStock units'),
        trailing: Text(
          InventoryService.formatPrice(totalValue),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green.shade700,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Total products', totalProducts.toString()),
                const SizedBox(height: 8),
                _buildDetailRow('Total stock', totalStock.toString()),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Total value',
                  InventoryService.formatPrice(totalValue),
                ),
                const SizedBox(height: 8),
                _buildDetailRow(
                  'Average value per product',
                  InventoryService.formatPrice(
                    totalProducts > 0 ? totalValue / totalProducts : 0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[600]),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}