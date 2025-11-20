import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../services/supply_company_service.dart';
import '../../widgets/supplier_selector.dart';
import '../../widgets/collapsible_drawer.dart';

/// Screen to manage products without assigned supplier
class ProductsWithoutSupplierScreen extends StatefulWidget {
  const ProductsWithoutSupplierScreen({super.key});

  @override
  State<ProductsWithoutSupplierScreen> createState() =>
      _ProductsWithoutSupplierScreenState();
}

class _ProductsWithoutSupplierScreenState
    extends State<ProductsWithoutSupplierScreen> {
  List<Map<String, dynamic>> _products = [];
  List<int> _selectedProductIds = [];
  bool _isLoading = true;
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products = await InventoryService.getProductsWithoutSupplier();
      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedProductIds.clear();
      }
    });
  }

  void _toggleProductSelection(int productId) {
    setState(() {
      if (_selectedProductIds.contains(productId)) {
        _selectedProductIds.remove(productId);
      } else {
        _selectedProductIds.add(productId);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedProductIds =
          _products.map((p) => p['id_inventario'] as int).toList();
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedProductIds.clear();
    });
  }

  Future<void> _assignSupplierToSelected() async {
    if (_selectedProductIds.isEmpty) return;

    final suppliers = await SupplyCompanyService.getSuppliers();

    if (!mounted) return;

    final selectedSupplier = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _QuickSupplierPicker(suppliers: suppliers),
    );

    if (selectedSupplier == null) return;

    setState(() => _isLoading = true);

    try {
      for (final productId in _selectedProductIds) {
        await InventoryService.assignSupplierToProduct(
          productId,
          selectedSupplier['id'],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Supplier assigned to ${_selectedProductIds.length} products',
            ),
            backgroundColor: const Color(0xFF6B8E3D),
          ),
        );
        _toggleSelectionMode();
        _loadProducts();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _assignSupplierToProduct(Map<String, dynamic> product) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AssignSupplierSheet(product: product),
    );

    if (result == true) {
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/suppliers/products-without',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          title: _isSelectionMode
              ? Text('${_selectedProductIds.length} selected')
              : const Text(
            'Products Without Supplier',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 2,
          actions: [
            if (_isSelectionMode) ...[
              if (_selectedProductIds.length != _products.length)
                IconButton(
                  icon: const Icon(Icons.select_all),
                  onPressed: _selectAll,
                  tooltip: 'Select all',
                ),
              if (_selectedProductIds.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: _clearSelection,
                  tooltip: 'Clear selection',
                ),
            ],
            IconButton(
              icon: Icon(_isSelectionMode ? Icons.close : Icons.checklist),
              onPressed: _toggleSelectionMode,
              tooltip:
              _isSelectionMode ? 'Cancel' : 'Select multiple',
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadProducts,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
            child: CircularProgressIndicator(color: Color(0xFF6B8E3D)))
            : _products.isEmpty
            ? _buildEmptyState()
            : _buildProductsList(),
        floatingActionButton:
        _isSelectionMode && _selectedProductIds.isNotEmpty
            ? FloatingActionButton.extended(
          onPressed: _assignSupplierToSelected,
          backgroundColor: const Color(0xFF6B8E3D),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.business),
          label: const Text('Assign Supplier'),
        )
            : null,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 100,
            color: Colors.green[300],
          ),
          const SizedBox(height: 16),
          Text(
            'Excellent!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'All products have an assigned supplier',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildProductsList() {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_products.length} products without assigned supplier',
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
            itemCount: _products.length,
            itemBuilder: (context, index) {
              final product = _products[index];
              final isSelected = _selectedProductIds.contains(
                product['id_inventario'],
              );

              return _buildProductCard(product, isSelected);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product, bool isSelected) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: isSelected
          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3)
          : null,
      child: InkWell(
        onTap: _isSelectionMode
            ? () => _toggleProductSelection(product['id_inventario'])
            : () => _assignSupplierToProduct(product),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (_isSelectionMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) =>
                      _toggleProductSelection(product['id_inventario']),
                ),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product['image_url'] != null
                    ? Image.network(
                  product['image_url'],
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                )
                    : Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey[200],
                  child: const Icon(Icons.inventory_2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['nombre_producto'] ?? 'No name',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.inventory,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text('Stock: ${product['cantidad'] ?? 0}'),
                        const SizedBox(width: 16),
                        Icon(Icons.attach_money,
                            size: 16, color: Colors.grey[600]),
                        Text(InventoryService.formatPrice(product['precio'])),
                      ],
                    ),
                    if (product['lugar_fisico'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on,
                              size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product['lugar_fisico'],
                              style: TextStyle(color: Colors.grey[600]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (!_isSelectionMode) const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// Sheet to assign supplier to an individual product
class _AssignSupplierSheet extends StatefulWidget {
  final Map<String, dynamic> product;

  const _AssignSupplierSheet({required this.product});

  @override
  State<_AssignSupplierSheet> createState() => _AssignSupplierSheetState();
}

class _AssignSupplierSheetState extends State<_AssignSupplierSheet> {
  int? _selectedSupplierId;
  bool _isLoading = false;

  Future<void> _saveSupplier() async {
    if (_selectedSupplierId == null) return;

    setState(() => _isLoading = true);

    try {
      await InventoryService.assignSupplierToProduct(
        widget.product['id_inventario'],
        _selectedSupplierId,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Supplier assigned'),
            backgroundColor: Color(0xFF6B8E3D),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Assign Supplier',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceVariant,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.product['image_url'] != null
                        ? Image.network(
                      widget.product['image_url'],
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[300],
                      child: const Icon(Icons.inventory_2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.product['nombre_producto'] ?? 'No name',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Stock: ${widget.product['cantidad']} • ${InventoryService.formatPrice(widget.product['precio'])}',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SupplierSelector(
            selectedSupplierId: _selectedSupplierId,
            onSupplierSelected: (supplierId) {
              setState(() => _selectedSupplierId = supplierId);
            },
            label: 'Select supplier',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
              _isLoading || _selectedSupplierId == null ? null : _saveSupplier,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
              ),
              child: _isLoading
                  ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Assign Supplier'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick supplier picker for multiple selection
class _QuickSupplierPicker extends StatelessWidget {
  final List<Map<String, dynamic>> suppliers;

  const _QuickSupplierPicker({required this.suppliers});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Select Supplier',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          if (suppliers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No suppliers available'),
            )
          else
            ...suppliers.map((supplier) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                    Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      (supplier['name'] as String?)
                          ?.substring(0, 1)
                          .toUpperCase() ??
                          '?',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(supplier['name'] ?? 'No name'),
                  subtitle:
                  supplier['email'] != null ? Text(supplier['email']) : null,
                  onTap: () => Navigator.pop(context, supplier),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}