import 'package:flutter/material.dart';
import '/constants/marketplace_constants.dart';
import '/services/marketplace_service.dart';

/// Pantalla para ver detalles completos de una orden
class OrderDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> order;
  final bool isSupplierView; // true si el usuario es el proveedor

  const OrderDetailsScreen({
    super.key,
    required this.order,
    this.isSupplierView = false,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  late Map<String, dynamic> _order;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E8),
      appBar: AppBar(
        title: Text('Order ${_getOrderNumber()}'),
        actions: [
          if (widget.isSupplierView && _canUpdateStatus())
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: _showStatusMenu,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusCard(),
            const SizedBox(height: 16),
            _buildOrderInfo(),
            const SizedBox(height: 16),
            _buildItemsList(),
            const SizedBox(height: 16),
            _buildTotalCard(),
            if (_order['buyer_notes'] != null) ...[
              const SizedBox(height: 16),
              _buildNotesCard(),
            ],
            if (widget.isSupplierView) ...[
              const SizedBox(height: 24),
              _buildSupplierActions(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    final status = OrderStatus.fromString(_order['status'] ?? 'pending');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            colors: [
              Color(status.colorCode),
              Color(status.colorCode).withValues(alpha: 0.8),
            ],
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStatusIcon(status),
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Order Status',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    status.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
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

  Widget _buildOrderInfo() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              Icons.confirmation_number,
              'Order Number',
              _getOrderNumber(),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.calendar_today,
              'Date',
              MarketplaceFormatters.formatDateTime(
                DateTime.parse(_order['created_at']),
              ),
            ),
            const Divider(height: 24),
            _buildInfoRow(
              Icons.business,
              widget.isSupplierView ? 'Comprador' : 'Supplier',
              widget.isSupplierView
                  ? (_order['buyer_company_name'] ?? 'Cliente')
                  : (_order['supplier_company_name'] ?? 'Supplier'),
            ),
            if (_order['tracking_number'] != null) ...[
              const Divider(height: 24),
              _buildInfoRow(
                Icons.local_shipping,
                'Tracking Number',
                _order['tracking_number'],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFF2B5F8C)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemsList() {
    final items = _order['items'] as List<dynamic>? ?? [];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Products',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B8E3D),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${items.length} items',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...items.map((item) => _buildOrderItem(item)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItem(Map<String, dynamic> item) {
    final quantity = item['quantity'] ?? 0;
    final unitPrice = (item['unit_price'] ?? 0.0).toDouble();
    final subtotal = (item['subtotal'] ?? 0.0).toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(8),
            ),
            child: item['product_image_url'] != null
                ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                item['product_image_url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    Icon(Icons.inventory_2, color: Colors.grey[400]),
              ),
            )
                : Icon(Icons.inventory_2, color: Colors.grey[400]),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['product_name'] ?? 'Product',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$quantity x ${MarketplaceFormatters.formatPrice(unitPrice)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Text(
            MarketplaceFormatters.formatPrice(subtotal),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF6B8E3D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalCard() {
    final subtotal = (_order['subtotal'] ?? 0.0).toDouble();
    final tax = (_order['tax'] ?? 0.0).toDouble();
    final shipping = (_order['shipping_cost'] ?? 0.0).toDouble();
    final discount = (_order['discount'] ?? 0.0).toDouble();
    final total = (_order['total_amount'] ?? 0.0).toDouble();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTotalRow('Subtotal', subtotal, false),
            if (tax > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow('Impuestos', tax, false),
            ],
            if (shipping > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow('Shipping', shipping, false),
            ],
            if (discount > 0) ...[
              const SizedBox(height: 8),
              _buildTotalRow('Descuento', -discount, false),
            ],
            const Divider(height: 24),
            _buildTotalRow('Total', total, true),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, bool isTotal) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          MarketplaceFormatters.formatPrice(amount),
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: FontWeight.bold,
            color: isTotal ? const Color(0xFF6B8E3D) : Colors.black,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.note, color: Color(0xFF2B5F8C)),
                SizedBox(width: 8),
                Text(
                  'Order Notes',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _order['buyer_notes'] ?? '',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupplierActions() {
    final status = OrderStatus.fromString(_order['status'] ?? 'pending');

    return Column(
      children: [
        if (status == OrderStatus.pending)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus('confirmed'),
              icon: const Icon(Icons.check_circle),
              label: const Text('Confirm Order'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        if (status == OrderStatus.confirmed || status == OrderStatus.processing)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _updateOrderStatus('shipped'),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Marcar como Enviado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2B5F8C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        const SizedBox(height: 12),
        if (status != OrderStatus.delivered && status != OrderStatus.cancelled)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _confirmCancellation(),
              icon: const Icon(Icons.cancel),
              label: const Text('Cancel Order'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
      ],
    );
  }

  String _getOrderNumber() {
    return MarketplaceFormatters.formatOrderNumber(
      _order['order_number'] ?? 'N/A',
    );
  }

  IconData _getStatusIcon(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Icons.hourglass_empty;
      case OrderStatus.confirmed:
        return Icons.check_circle;
      case OrderStatus.processing:
        return Icons.settings;
      case OrderStatus.shipped:
        return Icons.local_shipping;
      case OrderStatus.delivered:
        return Icons.done_all;
      case OrderStatus.cancelled:
        return Icons.cancel;
      case OrderStatus.refunded:
        return Icons.money_off;
    }
  }

  bool _canUpdateStatus() {
    final status = OrderStatus.fromString(_order['status'] ?? 'pending');
    return status != OrderStatus.delivered &&
        status != OrderStatus.cancelled;
  }

  void _showStatusMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Update Status',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Color(0xFF6B8E3D)),
                title: const Text('Confirm'),
                onTap: () {
                  Navigator.pop(context);
                  _updateOrderStatus('confirmed');
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings, color: Color(0xFF2B5F8C)),
                title: const Text('Procesando'),
                onTap: () {
                  Navigator.pop(context);
                  _updateOrderStatus('processing');
                },
              ),
              ListTile(
                leading: const Icon(Icons.local_shipping, color: Colors.purple),
                title: const Text('Enviado'),
                onTap: () {
                  Navigator.pop(context);
                  _updateOrderStatus('shipped');
                },
              ),
              ListTile(
                leading: const Icon(Icons.done_all, color: Colors.green),
                title: const Text('Delivered'),
                onTap: () {
                  Navigator.pop(context);
                  _updateOrderStatus('delivered');
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.cancel, color: Colors.red),
                title: const Text('Cancel Order'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmCancellation();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateOrderStatus(String newStatus) async {
    setState(() => _isLoading = true);

    try {
      await MarketplaceService.updateOrderStatus(
        _order['id'] as int,
        newStatus,
      );

      setState(() {
        _order['status'] = newStatus;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully'),
            backgroundColor: Color(0xFF6B8E3D),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _confirmCancellation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text(
          'Are you sure you want to cancel this order? '
              'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateOrderStatus('cancelled');
            },
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}