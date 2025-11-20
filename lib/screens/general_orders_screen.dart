// lib/screens/general_orders_screen.dart
// SCREEN FOR GENERAL ORDERS (NOT MARKETPLACE)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/order_service.dart';
import '../widgets/collapsible_drawer.dart';

class GeneralOrdersScreen extends StatefulWidget {
  const GeneralOrdersScreen({super.key});

  @override
  State<GeneralOrdersScreen> createState() => _GeneralOrdersScreenState();
}

class _GeneralOrdersScreenState extends State<GeneralOrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  String? _filterType;
  String? _filterStatus;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/general-orders',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          title: const Text(
            'Orders',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: _buildTabBar(),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildHistoryTab(),
            _buildStatisticsTab(),
            _buildScanTab(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildTabBar() {
    return TabBar(
      controller: _tabController,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: const Color(0xFF6B8E3D),
      tabs: const [
        Tab(icon: Icon(Icons.history), text: 'History'),
        Tab(icon: Icon(Icons.analytics), text: 'Statistics'),
        Tab(icon: Icon(Icons.qr_code_scanner), text: 'Scan'),
      ],
    );
  }

  // ==================== TAB: HISTORY ====================

  Widget _buildHistoryTab() {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: FutureBuilder<List<Order>>(
            future: _getFilteredOrders(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              return RefreshIndicator(
                onRefresh: () async => setState(() {}),
                color: const Color(0xFF6B8E3D),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _buildOrderCard(snapshot.data![index]);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<List<Order>> _getFilteredOrders() async {
    if (_filterType != null && _filterStatus != null) {
      // Filter by both
      final allOrders = await OrderService.getAllOrders();
      return allOrders
          .where((o) => o.orderType == _filterType && o.status == _filterStatus)
          .toList();
    } else if (_filterType != null) {
      return OrderService.getOrdersByType(_filterType!);
    } else if (_filterStatus != null) {
      return OrderService.getOrdersByStatus(_filterStatus!);
    } else {
      return OrderService.getAllOrders();
    }
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterDropdown(
              label: 'Type',
              value: _filterType,
              items: const {
                null: 'All',
                'sale': 'Sales',
                'purchase': 'Purchases',
                'entrada': 'Inbound',
                'salida': 'Outbound',
                'transferencia': 'Transfers',
                'ajuste': 'Adjustments',
              },
              onChanged: (value) => setState(() => _filterType = value),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildFilterDropdown(
              label: 'Status',
              value: _filterStatus,
              items: const {
                null: 'All',
                'pending': 'Pending',
                'completed': 'Completed',
                'cancelled': 'Cancelled',
              },
              onChanged: (value) => setState(() => _filterStatus = value),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown({
    required String label,
    required String? value,
    required Map<String?, String> items,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String?>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      items: items.entries.map((entry) {
        return DropdownMenuItem(value: entry.key, child: Text(entry.value));
      }).toList(),
      onChanged: onChanged,
    );
  }

  Widget _buildOrderCard(Order order) {
    final statusColor = _getStatusColor(order.status);
    final typeColor = _getTypeColor(order.orderType);

    return InkWell(
      onTap: () => _showOrderDetails(order),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: typeColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.formattedOrderType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(_getStatusIcon(order.status), color: statusColor, size: 20),
                  const SizedBox(width: 6),
                  Text(
                    order.formattedStatus,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.orderNumber ?? 'N/A',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B5F8C),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoRow(
                    Icons.calendar_today,
                    DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
                  ),
                  const SizedBox(height: 8),
                  _buildInfoRow(Icons.inventory_2, '${order.totalItems} items'),
                  if (order.responsable != null) ...[
                    const SizedBox(height: 8),
                    _buildInfoRow(Icons.person, order.responsable!),
                  ],
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F3E8),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Total:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '\$${order.totalAmount.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B5F8C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 80,
            color: Colors.grey.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Orders',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _filterType != null || _filterStatus != null
                ? 'No orders found with selected filters'
                : 'You don\'t have any registered orders yet',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ==================== TAB: STATISTICS ====================

  Widget _buildStatisticsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: OrderService.getOrderStatistics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
          );
        }

        final stats = snapshot.data ?? {};
        if (stats.isEmpty) {
          return const Center(child: Text('No data available'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildStatsCard(
                'Total Orders',
                (stats['total_ordenes'] ?? 0).toString(),
                Icons.receipt_long,
                const Color(0xFF2B5F8C),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatsCard(
                      'Completed',
                      (stats['ordenes_completadas'] ?? 0).toString(),
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatsCard(
                      'Pending',
                      (stats['ordenes_pendientes'] ?? 0).toString(),
                      Icons.pending,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Sales and Purchases',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                'Total Sales',
                '\$${(stats['ventas_total'] ?? 0.0).toStringAsFixed(2)}',
                Icons.trending_up,
                Colors.green[700]!,
              ),
              const SizedBox(height: 12),
              _buildStatsCard(
                'Total Purchases',
                '\$${(stats['compras_total'] ?? 0.0).toStringAsFixed(2)}',
                Icons.shopping_cart,
                Colors.blue[700]!,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatsCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
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
          ),
        ],
      ),
    );
  }

  // ==================== TAB: SCAN ====================

  Widget _buildScanTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Color(0xFF2B5F8C),
            ),
            const SizedBox(height: 24),
            const Text(
              'Scan Order Code',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Scan the QR code to view\norder details',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _scanOrderCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Code'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _enterOrderCodeManually,
              icon: const Icon(Icons.keyboard),
              label: const Text('Enter Code Manually'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2B5F8C),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== METHODS ====================

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor(String? type) {
    switch (type) {
      case 'sale':
        return Colors.green[700]!;
      case 'purchase':
        return Colors.blue[700]!;
      case 'entrada':
        return Colors.teal;
      case 'salida':
        return Colors.orange[700]!;
      case 'transferencia':
        return const Color(0xFF6B8E3D);
      case 'ajuste':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  void _showOrderDetails(Order order) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _OrderDetailScreen(order: order),
      ),
    );
  }

  Future<void> _scanOrderCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _OrderScannerScreen()),
    );

    if (result != null) {
      _handleScannedCode(result);
    }
  }

  void _enterOrderCodeManually() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Code'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Order or QR Code',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleScannedCode(codeController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Search'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScannedCode(String code) async {
    try {
      setState(() => _isLoading = true);

      // Search by QR code
      Order? order = await OrderService.getOrderByQR(code);

      // If not found by QR, search by order number
      if (order == null) {
        final allOrders = await OrderService.getAllOrders();
        order = allOrders.firstWhere(
              (o) => o.orderNumber == code,
          orElse: () => throw Exception('Order not found'),
        );
      }

      setState(() => _isLoading = false);
      _showOrderDetails(order);
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Order not found: $e');
    }
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

// ==================== SCANNER SCREEN ====================

class _OrderScannerScreen extends StatefulWidget {
  const _OrderScannerScreen();

  @override
  State<_OrderScannerScreen> createState() => _OrderScannerScreenState();
}

class _OrderScannerScreenState extends State<_OrderScannerScreen> {
  late MobileScannerController _controller;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Scan Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          _buildOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay() {
    return Container(
      decoration: BoxDecoration(color: Colors.black.withOpacity(0.5)),
      child: Center(
        child: Container(
          width: 250,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF6B8E3D), width: 3),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || capture.barcodes.isEmpty) return;

    final code = capture.barcodes.first.rawValue;
    if (code != null) {
      setState(() => _isProcessing = true);
      Navigator.pop(context, code);
    }
  }
}

// ==================== DETAIL SCREEN ====================

class _OrderDetailScreen extends StatelessWidget {
  final Order order;

  const _OrderDetailScreen({required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E8),
      appBar: AppBar(
        title: const Text('Order Details'),
        backgroundColor: const Color(0xFF2B5F8C),
        foregroundColor: Colors.white,
        actions: [
          if (order.qrCode != null)
            IconButton(
              icon: const Icon(Icons.qr_code),
              onPressed: () => _showQRCode(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(context),
            _buildDetailsSection(context),
            _buildItemsSection(context),
            if (order.direccionEnvio != null) _buildAddressSection(context),
            _buildTotalSection(context),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final statusColor = _getStatusColor();
    final typeColor = _getTypeColor();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFF2B5F8C), const Color(0xFF2B5F8C).withOpacity(0.8)],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: typeColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              order.formattedOrderType,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            order.orderNumber ?? 'N/A',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(25),
            ),
            child: Text(
              order.formattedStatus,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'General Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5F8C),
            ),
          ),
          const Divider(height: 24),
          _buildDetailRow(
            Icons.calendar_today,
            'Date',
            DateFormat('dd/MM/yyyy HH:mm').format(order.createdAt),
          ),
          if (order.responsable != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.person, 'Responsible', order.responsable!),
          ],
          if (order.observaciones != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow(Icons.notes, 'Notes', order.observaciones!),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              Text(
                value,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsSection(BuildContext context) {
    final items = order.items;
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Items (${items.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5F8C),
            ),
          ),
          const Divider(height: 24),
          ...items.map((item) => _buildItemCard(item)),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3E8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? item['nombre_producto'] ?? 'Product',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Quantity: ${item['quantity'] ?? item['cantidad'] ?? 0}',
                  style: const TextStyle(color: Colors.grey),
                ),
                if (item['unit_price'] != null || item['precio_unitario'] != null)
                  Text(
                    'Price: \$${(item['unit_price'] ?? item['precio_unitario'] ?? 0).toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.grey),
                  ),
              ],
            ),
          ),
          if (item['subtotal'] != null)
            Text(
              '\$${item['subtotal'].toStringAsFixed(2)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF2B5F8C),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAddressSection(BuildContext context) {
    final formattedAddress = order.direccionFormateada;
    if (formattedAddress == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.local_shipping, color: Color(0xFF2B5F8C)),
              SizedBox(width: 12),
              Text(
                'Shipping Address',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(formattedAddress, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildTotalSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF6B8E3D), Color(0xFF8BA853)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6B8E3D).withOpacity(0.3),
            blurRadius: 15,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'TOTAL:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            '\$${order.totalAmount.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                order.orderNumber ?? 'N/A',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (order.qrCode != null)
                QrImageView(data: order.qrCode!, version: QrVersions.auto, size: 250)
              else
                QrImageView(data: order.orderNumber ?? '', version: QrVersions.auto, size: 250),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5F8C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor() {
    switch (order.status) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getTypeColor() {
    switch (order.orderType) {
      case 'sale':
        return Colors.green[700]!;
      case 'purchase':
        return Colors.blue[700]!;
      case 'entrada':
        return Colors.teal;
      case 'salida':
        return Colors.orange[700]!;
      case 'transferencia':
        return const Color(0xFF6B8E3D);
      case 'ajuste':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}