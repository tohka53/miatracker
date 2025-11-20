import 'package:flutter/material.dart';
import '../widgets/collapsible_drawer.dart';
import '../services/marketplace_service.dart';
import '../constants/marketplace_constants.dart';
import 'marketplace/order_details_screen.dart';

/// Screen to view all user orders
/// Shows orders as buyer and as supplier (if applicable)
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _buyerOrders = [];
  List<Map<String, dynamic>> _supplierOrders = [];
  bool _isLoading = true;
  bool _isSupplier = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkIfSupplier();
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkIfSupplier() async {
    // TODO: Check if user is a supplier
    // final settings = await CompanySettingsService.getSettings();
    // setState(() => _isSupplier = settings?['is_supplier'] ?? false);
    setState(() => _isSupplier = false); // For now false
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      final buyerOrders = await MarketplaceService.getMyOrders();
      final supplierOrders = _isSupplier
          ? await MarketplaceService.getSupplierOrders()
          : <Map<String, dynamic>>[];

      setState(() {
        _buyerOrders = buyerOrders;
        _supplierOrders = supplierOrders;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading orders: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/orders',
      child: DefaultTabController(
        length: _isSupplier ? 2 : 1,
        child: Scaffold(
          backgroundColor: const Color(0xFFF5F3E8),
          appBar: AppBar(
            leading: const SizedBox.shrink(),
            title: const Text(
              'My Orders',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            bottom: _isSupplier
                ? TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'My Purchases'),
                Tab(text: 'Sales'),
              ],
            )
                : null,
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadOrders,
              ),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _isSupplier
              ? TabBarView(
            controller: _tabController,
            children: [
              _buildOrdersList(_buyerOrders, false),
              _buildOrdersList(_supplierOrders, true),
            ],
          )
              : _buildOrdersList(_buyerOrders, false),
        ),
      ),
    );
  }

  Widget _buildOrdersList(List<Map<String, dynamic>> orders, bool isSupplierView) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              isSupplierView ? 'No orders received' : 'No orders yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSupplierView
                  ? 'Orders you receive will appear here'
                  : 'Explore the marketplace and make your first purchase',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (!isSupplierView)
              ElevatedButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/marketplace'),
                icon: const Icon(Icons.store),
                label: const Text('Go to Marketplace'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: orders.length,
        itemBuilder: (context, index) {
          return _buildOrderCard(orders[index], isSupplierView);
        },
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, bool isSupplierView) {
    final status = OrderStatus.fromString(order['status'] ?? 'pending');
    final orderNumber = order['order_number'] ?? 'N/A';
    final totalAmount = (order['total_amount'] ?? 0.0).toDouble();
    final companyName = isSupplierView
        ? (order['buyer_company_name'] ?? 'Customer')
        : (order['supplier_company_name'] ?? 'Supplier');
    final createdAt = DateTime.parse(order['created_at']);
    final items = (order['items'] as List<dynamic>?)?.length ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: InkWell(
        onTap: () => _navigateToOrderDetails(order, isSupplierView),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${orderNumber.substring(orderNumber.length - 8)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isSupplierView ? Icons.person : Icons.store,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                companyName,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Color(status.colorCode).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Color(status.colorCode).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      status.displayName,
                      style: TextStyle(
                        color: Color(status.colorCode),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        MarketplaceFormatters.formatDate(createdAt),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$items',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '\$${totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B8E3D),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToOrderDetails(Map<String, dynamic> order, bool isSupplierView) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OrderDetailsScreen(
          order: order,
          isSupplierView: isSupplierView,
        ),
      ),
    );
  }
}