import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/order_service.dart';
import '../widgets/collapsible_drawer.dart';
import '../services/cart_service.dart';
import '../services/inventory_service.dart';


class ShoppingCartScreen extends StatefulWidget {
  const ShoppingCartScreen({super.key});

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  final CartService _cartService = CartService();
  List<Map<String, dynamic>> _inventory = [];
  bool _isLoading = true;
  bool _isProcessingOrder = false;

  @override
  void initState() {
    super.initState();
    _loadInventory();
    _cartService.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadInventory() async {
    try {
      setState(() => _isLoading = true);
      final inventory = await InventoryService.getInventory();

      if (mounted) {
        setState(() {
          _inventory = inventory;
          _isLoading = false;
        });

        // Update cart service with current inventory
        _cartService.updateInventory(inventory);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('Error loading inventory: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/cart',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          title: const Text(
            'Take Out Stock',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            if (_cartService.items.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: _showClearCartDialog,
                tooltip: 'Clear cart',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadInventory,
              tooltip: 'Refresh',
            ),
          ],
          automaticallyImplyLeading: false,
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
            child: Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 70, // Space for menu button
                bottom: 16,
              ),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF6B8E3D)))
                  : _buildBody(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cartService.items.isEmpty) {
      return _buildEmptyCart();
    }

    return Column(
      children: [
        // Cart summary
        _buildCartSummary(),
        const SizedBox(height: 16),

        // Product list
        Expanded(
          child: ListView.builder(
            itemCount: _cartService.items.length,
            itemBuilder: (context, index) {
              final item = _cartService.items[index];
              return _buildCartItemCard(item);
            },
          ),
        ),

        // Action buttons
        _buildActionButtons(),
      ],
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 120,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Add products from inventory\nto start your order',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacementNamed(context, '/inventory'),
            icon: const Icon(Icons.inventory_2),
            label: const Text('Go to Inventory'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF6B8E3D).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shopping_cart,
              color: Color(0xFF6B8E3D),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_cartService.totalItems} products',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total: \$${_cartService.totalAmount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (!_cartService.canProcessOrder())
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Limited stock',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartItemCard(CartItem item) {
    final availableStock = _cartService.getAvailableStock(item.productId);
    final hasStockIssue = item.quantity > availableStock;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
        border: hasStockIssue
            ? Border.all(color: Colors.orange.withOpacity(0.3), width: 2)
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product image
            const SizedBox(width: 16),

            // Product information
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B5F8C),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  if (item.description != null && item.description!.isNotEmpty)
                    Text(
                      item.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B8E3D),
                        ),
                      ),
                      const Text(' ea'),
                      const Spacer(),
                      if (hasStockIssue)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning, color: Colors.orange, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Stock: $availableStock',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.bold,
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

            // Quantity controls
            _buildQuantityControls(item),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityControls(CartItem item) {
    return Column(
      children: [
        // Delete button
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: const Icon(Icons.delete, size: 16),
            color: Colors.red,
            onPressed: () => _removeFromCart(item),
            padding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),

        // Quantity controls
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuantityButton(
                icon: Icons.remove,
                onPressed: item.quantity > 1
                    ? () => _updateQuantity(item, item.quantity - 1)
                    : null,
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              _buildQuantityButton(
                icon: Icons.add,
                onPressed: _cartService.getAvailableStock(item.productId) > 0
                    ? () => _updateQuantity(item, item.quantity + 1)
                    : null,
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),

        // Item total
        Text(
          '\$${item.totalPrice.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2B5F8C),
          ),
        ),
      ],
    );
  }

  Widget _buildQuantityButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: onPressed != null ? const Color(0xFF6B8E3D) : Colors.grey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16),
        color: Colors.white,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
          // Voucher code (optional)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B5F8C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.local_offer, color: Color(0xFF2B5F8C)),
                      SizedBox(width: 8),
                      Text(
                        'VOUCHER CODE',
                        style: TextStyle(
                          color: Color(0xFF2B5F8C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'TOTAL: ',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${_cartService.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Checkout button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _cartService.canProcessOrder() && !_isProcessingOrder
                  ? _processOrder
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isProcessingOrder
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Processing...'),
                ],
              )
                  : const Text(
                'Checkout',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateQuantity(CartItem item, int newQuantity) {
    final success = _cartService.updateQuantity(item.productId, newQuantity);
    if (!success) {
      _showErrorSnackBar('Not enough stock available');
    }
  }

  void _removeFromCart(CartItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete, color: Colors.red),
            SizedBox(width: 8),
            Text('Remove Product'),
          ],
        ),
        content: Text('Remove "${item.name}" from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _cartService.removeFromCart(item.productId);
              Navigator.pop(context);
              _showSuccessSnackBar('Product removed from cart');
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

  void _showClearCartDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.delete_sweep, color: Colors.orange),
            SizedBox(width: 8),
            Text('Clear Cart'),
          ],
        ),
        content: const Text('Are you sure you want to remove all products from the cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _cartService.clearCart();
              Navigator.pop(context);
              _showSuccessSnackBar('Cart cleared');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _processOrder() async {
    if (!_cartService.canProcessOrder()) {
      _showErrorSnackBar('Cannot process order. Check available stock.');
      return;
    }

    setState(() => _isProcessingOrder = true);

    try {
      // Prepare order data
      final orderData = await _cartService.processOrderAndUpdateStock();
      final orderSummary = orderData['order_summary'] as Map<String, dynamic>;
      final items = (orderSummary['items'] as List).cast<Map<String, dynamic>>();

      if (kDebugMode) {
        print('📦 Processing order with ${items.length} products...');
      }

      // Process order and update stock in Supabase
      final result = await OrderService.processOrder(items, orderSummary);

      if (result['success'] == true) {
        if (mounted) {
          // Reload inventory to reflect changes
          await _loadInventory();

          // Show success dialog
          _showOrderSuccessDialog(orderSummary, result['order_id']);
        }
      } else {
        throw Exception('Error processing order');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error processing order: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingOrder = false);
      }
    }
  }

  void _showOrderSuccessDialog(Map<String, dynamic> orderSummary, String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Column(
          children: [
            Icon(
              Icons.check_circle,
              color: Color(0xFF6B8E3D),
              size: 48,
            ),
            SizedBox(height: 8),
            Text(
              'Order Successful',
              style: TextStyle(
                color: Color(0xFF2B5F8C),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Your order has been processed successfully.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Order #: $orderId',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Products:'),
                      Text(
                        '${orderSummary['total_items']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total:'),
                      Text(
                        '\$${(orderSummary['total_amount'] as double).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B8E3D),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.inventory, size: 16, color: Colors.grey),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stock has been updated automatically',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cartService.clearCart();
              Navigator.pushReplacementNamed(context, '/home');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E3D),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}