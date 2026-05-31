import 'package:flutter/material.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../services/inventory_service.dart';
import '../../services/inventory_report_service.dart';
import '../../widgets/collapsible_drawer.dart';

/// Inventory Reports Screen with PDF export functionality
class InventoryReportsScreen extends StatefulWidget {
  const InventoryReportsScreen({super.key});

  @override
  State<InventoryReportsScreen> createState() => _InventoryReportsScreenState();
}

class _InventoryReportsScreenState extends State<InventoryReportsScreen> {
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _lowStockProducts = [];
  bool _isLoading = true;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final stats = await InventoryService.getInventoryStats();
      final inventory = await InventoryService.getInventory();
      final lowStock = await InventoryService.getLowStockItems();

      if (mounted) {
        setState(() {
          _stats = stats;
          _inventory = inventory;
          _lowStockProducts = lowStock;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error loading data: $e');
      }
    }
  }

  Future<void> _exportToPdf() async {
    setState(() => _isExporting = true);

    try {
      // Request storage permission (for Android)
      final status = await Permission.storage.request();
      if (!status.isGranted) {
        _showError('Storage permission is required to save PDF');
        setState(() => _isExporting = false);
        return;
      }

      // Generate PDF
      final filePath = await InventoryReportService.generateInventoryReport(
        stats: _stats,
        inventory: _inventory,
        lowStockProducts: _lowStockProducts,
      );

      if (mounted) {
        setState(() => _isExporting = false);

        // Show success message with option to open file
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('PDF report generated successfully!'),
            backgroundColor: const Color(0xFF6B8E3D),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                await OpenFile.open(filePath);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        _showError('Error generating PDF: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/reports',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          title: const Text(
            'Inventory Reports',
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
              icon: const Icon(Icons.refresh, size: 22),
              onPressed: _isLoading ? null : _loadData,
              tooltip: 'Refresh',
            ),
            IconButton(
              icon: _isExporting
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : const Icon(Icons.picture_as_pdf, size: 22),
              onPressed: _isExporting || _isLoading ? null : _exportToPdf,
              tooltip: 'Export to PDF',
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF6B8E3D),
          ),
        )
            : RefreshIndicator(
          onRefresh: _loadData,
          color: const Color(0xFF6B8E3D),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSummaryCards(),
                const SizedBox(height: 24),
                _buildStockStatusSection(),
                const SizedBox(height: 24),
                _buildLowStockProducts(),
                const SizedBox(height: 24),
                _buildTopValueProducts(),
                const SizedBox(height: 24),
                _buildLocationDistribution(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'General Summary',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard(
              'Total Products',
              _stats['total_productos']?.toString() ?? '0',
              Icons.inventory_2,
              Colors.blue,
            ),
            _buildStatCard(
              'Active Products',
              _stats['productos_activos']?.toString() ?? '0',
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatCard(
              'Low Stock',
              _stats['productos_stock_bajo']?.toString() ?? '0',
              Icons.warning,
              Colors.orange,
            ),
            _buildStatCard(
              'Out of Stock',
              _stats['productos_sin_stock']?.toString() ?? '0',
              Icons.error,
              Colors.red,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ✅ Iconos más pequeños (24 en lugar de 32)
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStockStatusSection() {
    final totalProducts = _stats['productos_activos'] ?? 0;
    final normalStock = _inventory
        .where((item) => item['stock_status'] == 'normal')
        .length;
    final lowStock = _stats['productos_stock_bajo'] ?? 0;
    final outOfStock = _stats['productos_sin_stock'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ✅ Icono más pequeño (20 en lugar de 24)
                const Icon(Icons.pie_chart, color: Color(0xFF2B5F8C), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Stock Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildProgressRow(
              'Normal Stock',
              normalStock,
              totalProducts,
              Colors.green,
            ),
            const SizedBox(height: 12),
            _buildProgressRow(
              'Low Stock',
              lowStock,
              totalProducts,
              Colors.orange,
            ),
            const SizedBox(height: 12),
            _buildProgressRow(
              'Out of Stock',
              outOfStock,
              totalProducts,
              Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressRow(String label, int value, int total, Color color) {
    final percentage = total > 0 ? (value / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
            Text(
              '$value / $total (${(percentage * 100).toStringAsFixed(1)}%)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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

  Widget _buildLowStockProducts() {
    if (_lowStockProducts.isEmpty) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 56,
                  color: Colors.green[400],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Excellent! No products with low stock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // ✅ Icono más pequeño (20 en lugar de 24)
            const Icon(Icons.warning, color: Colors.orange, size: 20),
            const SizedBox(width: 8),
            const Text(
              'Low Stock Products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_lowStockProducts.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _lowStockProducts.take(5).length,
          itemBuilder: (context, index) {
            final product = _lowStockProducts[index];
            return _buildProductCard(product);
          },
        ),
        if (_lowStockProducts.length > 5)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: Text(
                '+ ${_lowStockProducts.length - 5} more products',
                style: const TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                  fontSize: 12,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTopValueProducts() {
    final sortedProducts = List<Map<String, dynamic>>.from(_inventory)
      ..sort((a, b) {
        final aValue = ((a['precio'] ?? 0.0) * (a['cantidad'] ?? 0)).toDouble();
        final bValue = ((b['precio'] ?? 0.0) * (b['cantidad'] ?? 0)).toDouble();
        return bValue.compareTo(aValue);
      });

    final topProducts = sortedProducts.take(5).toList();

    if (topProducts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // ✅ Icono más pequeño (20 en lugar de 24)
            const Icon(Icons.star, color: Color(0xFF6B8E3D), size: 20),
            const SizedBox(width: 8),
            const Text(
              'Top 5 Products by Value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: topProducts.length,
          itemBuilder: (context, index) {
            final product = topProducts[index];
            final totalValue = (product['precio'] ?? 0.0) * (product['cantidad'] ?? 0);

            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF6B8E3D).withOpacity(0.1),
                  radius: 18,
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF6B8E3D),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                title: Text(
                  product['nombre_producto'] ?? 'No name',
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                ),
                subtitle: Text(
                  '${product['cantidad']} units × \$${(product['precio'] ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  '\$${totalValue.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B8E3D),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLocationDistribution() {
    final locationsCount = _stats['ubicaciones_activas'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // ✅ Icono más pequeño (20 en lugar de 24)
                const Icon(Icons.location_on, color: Color(0xFF2B5F8C), size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Distribution by Locations',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildCircularStat(
                  'Total Locations',
                  locationsCount.toString(),
                  Colors.blue,
                ),
                _buildCircularStat(
                  'Distributed Products',
                  _inventory
                      .where((item) => item['ubicaciones']?.isNotEmpty ?? false)
                      .length
                      .toString(),
                  Colors.green,
                ),
              ],
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
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.1),
            border: Border.all(color: color, width: 3),
          ),
          child: Center(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final stockStatus = product['stock_status'] ?? 'normal';
    final cantidad = product['cantidad'] ?? 0;
    final alertaCantidad = product['alerta_cantidad'] ?? 5;

    Color getStatusColor() {
      switch (stockStatus) {
        case 'out_of_stock':
          return Colors.red;
        case 'low_stock':
          return Colors.orange;
        default:
          return Colors.green;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.inventory_2,
            color: getStatusColor(),
            size: 20,
          ),
        ),
        title: Text(
          product['nombre_producto'] ?? 'No name',
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        subtitle: Text(
          'Stock: $cantidad / Alert: $alertaCantidad',
          style: TextStyle(color: getStatusColor(), fontSize: 12),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: getStatusColor().withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            InventoryService.getStockStatusText(stockStatus),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: getStatusColor(),
            ),
          ),
        ),
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}