import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/marketplace_cart_service.dart';
import '../../services/supply_marketplace_service.dart';

/// Marketplace Shopping Cart Screen
class MarketplaceCartScreen extends StatefulWidget {
  const MarketplaceCartScreen({super.key});

  @override
  State<MarketplaceCartScreen> createState() => _MarketplaceCartScreenState();
}

class _MarketplaceCartScreenState extends State<MarketplaceCartScreen> {
  final _cartService = MarketplaceCartService();
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _cartService,
      builder: (context, _) {
        final supplierIds = _cartService.supplierIds;

        return Scaffold(
          appBar: AppBar(
            title: Text('Cart (${_cartService.totalItems} items)'),
            backgroundColor: const Color(0xFF2B5F8C),
            foregroundColor: Colors.white,
            actions: [
              if (_cartService.totalItems > 0)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _confirmClearCart,
                  tooltip: 'Clear cart',
                ),
            ],
          ),
          body: supplierIds.isEmpty
              ? _buildEmptyCart()
              : _buildCartContent(supplierIds),
          bottomNavigationBar: supplierIds.isEmpty
              ? null
              : _buildCheckoutBar(),
        );
      },
    );
  }

  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 100,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 24),
          Text(
            'Your cart is empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Explore the marketplace and add products',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.store),
            label: const Text('Go to Marketplace'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartContent(List<int> supplierIds) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: supplierIds.length,
      itemBuilder: (context, index) {
        final supplierId = supplierIds[index];
        final items = _cartService.getSupplierItems(supplierId);
        final supplierTotal = _cartService.getSupplierTotal(supplierId);

        if (items.isEmpty) return const SizedBox.shrink();

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Supplier header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2B5F8C).withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.store,
                      color: Color(0xFF2B5F8C),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items.first.supplierName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF2B5F8C),
                            ),
                          ),
                          Text(
                            '${items.length} products',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      SupplyMarketplaceService.formatPrice(supplierTotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF6B8E3D),
                      ),
                    ),
                  ],
                ),
              ),
              // Product list
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, itemIndex) {
                  return _buildCartItem(items[itemIndex]);
                },
              ),
              // Place order button
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : () => _processSupplierOrder(supplierId, items),
                    icon: const Icon(Icons.shopping_bag),
                    label: const Text('Place Order to this Supplier'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: item.imagen != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: item.imagen!,
                fit: BoxFit.cover,
                placeholder: (_, __) => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (_, __, ___) => const Icon(
                  Icons.inventory,
                  color: Colors.grey,
                ),
              ),
            )
                : const Icon(Icons.inventory, color: Colors.grey),
          ),
          const SizedBox(width: 12),
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombreProducto,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${SupplyMarketplaceService.formatPrice(item.precioUnitario)} / ${item.unidadMedida}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    // Quantity controls
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: item.cantidad <= item.cantidadMinima
                                ? null
                                : () => _decreaseQuantity(item),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${item.cantidad}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add, size: 16),
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 32,
                              minHeight: 32,
                            ),
                            onPressed: (item.stockDisponible > 0 &&
                                item.cantidad >= item.stockDisponible)
                                ? null
                                : () => _increaseQuantity(item),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Subtotal
                    Text(
                      SupplyMarketplaceService.formatPrice(item.subtotal),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF6B8E3D),
                      ),
                    ),
                  ],
                ),
                if (item.cantidad == item.cantidadMinima)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Minimum quantity: ${item.cantidadMinima}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Remove button
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () => _removeItem(item),
            color: Colors.red,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  SupplyMarketplaceService.formatPrice(_cartService.totalAmount),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B8E3D),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _processAllOrders,
                icon: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Icon(Icons.check_circle),
                label: Text(
                  _isProcessing
                      ? 'Processing...'
                      : 'Place All Orders',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5F8C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _increaseQuantity(CartItem item) {
    _cartService.updateQuantity(
      item.supplierId,
      item.productId,
      item.cantidad + 1,
    );
  }

  void _decreaseQuantity(CartItem item) {
    _cartService.updateQuantity(
      item.supplierId,
      item.productId,
      item.cantidad - 1,
    );
  }

  void _removeItem(CartItem item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove product'),
        content: Text('Remove ${item.nombreProducto} from cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _cartService.removeFromCart(item.supplierId, item.productId);
              Navigator.pop(context);
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

  void _confirmClearCart() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear cart'),
        content: const Text('Are you sure you want to empty the entire cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _cartService.clearCart();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _processSupplierOrder(int supplierId, List<CartItem> items) async {
    setState(() => _isProcessing = true);

    try {
      final itemsJson = items.map((item) => item.toJson()).toList();

      final orderId = await SupplyMarketplaceService.createOrder(
        supplierId,
        itemsJson,
      );

      if (orderId != null && mounted) {
        _cartService.clearSupplierCart(supplierId);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order #$orderId created successfully'),
            backgroundColor: const Color(0xFF6B8E3D),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () {
                // Navigate to order details
              },
            ),
          ),
        );
      } else if (mounted) {
        throw Exception('Could not create order');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _processAllOrders() async {
    final supplierIds = _cartService.supplierIds;
    int successCount = 0;
    int failCount = 0;

    setState(() => _isProcessing = true);

    for (final supplierId in supplierIds) {
      final items = _cartService.getSupplierItems(supplierId);
      if (items.isEmpty) continue;

      try {
        final itemsJson = items.map((item) => item.toJson()).toList();
        final orderId = await SupplyMarketplaceService.createOrder(
          supplierId,
          itemsJson,
        );

        if (orderId != null) {
          _cartService.clearSupplierCart(supplierId);
          successCount++;
        } else {
          failCount++;
        }
      } catch (e) {
        failCount++;
      }
    }

    if (mounted) {
      setState(() => _isProcessing = false);

      String message;
      Color backgroundColor;

      if (failCount == 0) {
        message = 'All orders ($successCount) created successfully';
        backgroundColor = const Color(0xFF6B8E3D);
      } else if (successCount > 0) {
        message = '$successCount orders created, $failCount failed';
        backgroundColor = Colors.orange;
      } else {
        message = 'Error creating orders';
        backgroundColor = Colors.red;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor,
        ),
      );

      if (successCount > 0) {
        // Navigate to my orders
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    }
  }
}