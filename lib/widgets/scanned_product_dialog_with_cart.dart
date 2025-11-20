import 'package:flutter/material.dart';
import '../services/cart_service.dart';
import '../services/inventory_service.dart';

/// =======================================
///  ENHANCED DIALOG: Scanned Product with Cart Option
/// =======================================
///
/// This dialog replaces _showScannedItemDialog() in inventory_screen.dart
/// Shows product information AND offers:
/// 1. View full details
/// 2. Edit product
/// 3. NEW: Add to shopping cart
///
class ScannedProductDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback? onCartUpdated;

  const ScannedProductDialog({
    super.key,
    required this.item,
    required this.onEdit,
    this.onCartUpdated,
  });

  @override
  State<ScannedProductDialog> createState() => _ScannedProductDialogState();
}

class _ScannedProductDialogState extends State<ScannedProductDialog> {
  final CartService _cartService = CartService();
  int _selectedQuantity = 1;
  bool _isAddingToCart = false;

  @override
  Widget build(BuildContext context) {
    final productName = widget.item['nombre_producto'] ?? 'No name';
    final currentStock = widget.item['cantidad'] ?? 0;
    final stockStatus = widget.item['stock_status'] ?? 'unknown';
    final location = widget.item['lugar_fisico'] ?? 'No location';
    final imageUrl = widget.item['imagen'];
    final description = widget.item['descripcion'];

    // Get available stock (current - already in cart)
    final availableStock = _cartService.getAvailableStock(
      widget.item['id_inventario'] as int,
    );

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with success icon
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B8E3D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF6B8E3D),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Product Found',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Product image (if exists)
              if (imageUrl != null && imageUrl.isNotEmpty) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      imageUrl,
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 150,
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 48,
                            color: Colors.grey,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Product name
              Text(
                productName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
              const SizedBox(height: 16),

              // Product information in cards
              _buildInfoCard(
                icon: Icons.inventory_2,
                label: 'Total Stock',
                value: '$currentStock units',
                color: _getStockColor(stockStatus),
              ),
              const SizedBox(height: 8),

              _buildInfoCard(
                icon: Icons.shopping_bag,
                label: 'Available for cart',
                value: '$availableStock units',
                color: availableStock > 0 ? Colors.green : Colors.orange,
              ),
              const SizedBox(height: 8),

              _buildInfoCard(
                icon: Icons.location_on,
                label: 'Location',
                value: location,
                color: const Color(0xFF6B8E3D),
              ),
              const SizedBox(height: 8),

              _buildInfoCard(
                icon: Icons.analytics,
                label: 'Status',
                value: InventoryService.getStockStatusText(stockStatus),
                color: _getStockColor(stockStatus),
              ),

              // Description (if exists)
              if (description != null && description.toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.description, size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text(
                            'Description',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description.toString(),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Quantity selector for cart (only if stock available)
              if (availableStock > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B8E3D).withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF6B8E3D).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🛒 Add to cart',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text('Quantity:'),
                          const Spacer(),
                          IconButton(
                            onPressed: _selectedQuantity > 1
                                ? () => setState(() => _selectedQuantity--)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                            color: const Color(0xFF2B5F8C),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: Text(
                              '$_selectedQuantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _selectedQuantity < availableStock
                                ? () => setState(() => _selectedQuantity++)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                            color: const Color(0xFF6B8E3D),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Message if no stock available
              if (availableStock <= 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentStock > 0
                              ? 'All stock is in the cart'
                              : 'Out of stock',
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onEdit();
                      },
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5F8C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Add to cart button (prominent)
              if (availableStock > 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isAddingToCart ? null : _addToCart,
                    icon: _isAddingToCart
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.add_shopping_cart),
                    label: Text(
                      _isAddingToCart
                          ? 'Adding...'
                          : 'Add $_selectedQuantity to cart',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D),
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
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
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

  Color _getStockColor(String status) {
    switch (status) {
      case 'normal':
        return Colors.green;
      case 'low_stock':
        return Colors.orange;
      case 'out_of_stock':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _addToCart() async {
    setState(() => _isAddingToCart = true);

    try {
      final success = _cartService.addToCart(
        widget.item,
        quantity: _selectedQuantity,
      );

      if (success) {
        if (mounted) {
          Navigator.pop(context);

          // Show confirmation
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Added: $_selectedQuantity x ${widget.item['nombre_producto']}',
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF6B8E3D),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'View Cart',
                textColor: Colors.white,
                onPressed: () {
                  // Optional: Navigate to cart
                  // Navigator.push(
                  //   context,
                  //   MaterialPageRoute(
                  //     builder: (context) => const ShoppingCartScreen(),
                  //   ),
                  // );
                },
              ),
            ),
          );

          // Callback to update inventory UI if needed
          widget.onCartUpdated?.call();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Insufficient stock to add to cart'),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding to cart: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }
}

/// =======================================
///  HELPER FUNCTION: Show enhanced dialog
/// =======================================
///
/// Replaces the call to _showScannedItemDialog() in inventory_screen.dart
///
void showScannedProductDialogWithCart(
    BuildContext context,
    Map<String, dynamic> item, {
      required VoidCallback onEdit,
      VoidCallback? onCartUpdated,
    }) {
  showDialog(
    context: context,
    builder: (context) => ScannedProductDialog(
      item: item,
      onEdit: onEdit,
      onCartUpdated: onCartUpdated,
    ),
  );
}