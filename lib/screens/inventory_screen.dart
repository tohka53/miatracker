// ============================================================================
// INVENTORY SCREEN - VERSIÓN ULTRA OPTIMIZADA Y COMPLETA
// ============================================================================
// PARTE 1: IMPORTS, VARIABLES Y MÉTODOS DE CARGA
// Copiar desde aquí →

import 'dart:async';
import 'dart:io';

import 'package:barcode_widget/barcode_widget.dart' as barcode_widget;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/cart_service.dart';
import '../services/image_service.dart';
import '../services/inventory_service.dart';
import '../services/profile_service.dart';
import '../screens/shopping_cart_screen.dart';
import '../widgets/collapsible_drawer.dart';
import '../widgets/scanned_product_dialog_with_cart.dart';

/// ===========================
///  INVENTORY SCREEN
/// ===========================
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  // 📊 DATOS
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _locations = [];
  Map<String, int> _filterCounts = {
    'all': 0,
    'normal': 0,
    'low_stock': 0,
    'out_of_stock': 0,
  };

  // 📄 PAGINACIÓN
  int _currentPage = 0;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  // 🔍 BÚSQUEDA Y FILTROS
  String _searchQuery = '';
  String _selectedFilter = 'all';
  bool _isSearching = false;

  // 🔄 ESTADO
  bool _isInitialLoading = true;
  String? _userRole;

  // 🎮 CONTROLADORES
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CartService _cartService = CartService();

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadInitialData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ========================================================================
  // CARGA INICIAL Y ROLES
  // ========================================================================

  Future<void> _loadUserRole() async {
    try {
      final profile = await ProfileService.getUserProfile();
      setState(() {
        _userRole = profile?['role'] as String?;
      });
    } catch (e) {
      if (kDebugMode) print('Error loading user role: $e');
    }
  }

  bool get _canEdit => _userRole == 'admin' || _userRole == 'supervisor';

  Future<void> _loadInitialData() async {
    setState(() => _isInitialLoading = true);

    try {
      await Future.wait([
        _loadFilterCounts(),
        _loadLocations(),
        _loadFirstPage(),
      ]);
    } finally {
      if (mounted) setState(() => _isInitialLoading = false);
    }
  }

  // ========================================================================
  // CARGA DE DATOS PAGINADOS
  // ========================================================================

  Future<void> _loadFirstPage() async {
    try {
      _currentPage = 0;
      _hasMoreData = true;

      Map<String, dynamic> result;

      if (_searchQuery.isNotEmpty) {
        result = await InventoryService.searchInventoryPaged(
          searchText: _searchQuery,
          page: 0,
          pageSize: 20,
        );
      } else if (_selectedFilter != 'all') {
        result = await InventoryService.getInventoryFiltered(
          filter: _selectedFilter,
          page: 0,
          pageSize: 20,
        );
      } else {
        result = await InventoryService.getInventoryPaged(
          page: 0,
          pageSize: 20,
          forceRefresh: true,
        );
      }

      if (mounted) {
        setState(() {
          _inventory = List<Map<String, dynamic>>.from(result['items']);
          _hasMoreData = result['hasMore'] ?? false;
        });
        _cartService.updateInventory(_inventory);
      }

      if (kDebugMode) {
        print('✅ Primera página cargada: ${_inventory.length} productos');
        print('   Hay más datos: $_hasMoreData');
      }
    } catch (e) {
      if (mounted) _showErrorSnackBar('Error loading products: $e');
      if (kDebugMode) print('❌ Error en _loadFirstPage: $e');
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);

    try {
      _currentPage++;

      Map<String, dynamic> result;

      if (_searchQuery.isNotEmpty) {
        result = await InventoryService.searchInventoryPaged(
          searchText: _searchQuery,
          page: _currentPage,
          pageSize: 20,
        );
      } else if (_selectedFilter != 'all') {
        result = await InventoryService.getInventoryFiltered(
          filter: _selectedFilter,
          page: _currentPage,
          pageSize: 20,
        );
      } else {
        result = await InventoryService.getInventoryPaged(
          page: _currentPage,
          pageSize: 20,
        );
      }

      if (mounted) {
        final newItems = List<Map<String, dynamic>>.from(result['items']);

        setState(() {
          _inventory.addAll(newItems);
          _hasMoreData = result['hasMore'] ?? false;
          _isLoadingMore = false;
        });

        _cartService.updateInventory(_inventory);

        if (kDebugMode) {
          print('✅ Página $_currentPage cargada: ${newItems.length} productos');
          print('   Total: ${_inventory.length}');
          print('   Hay más: $_hasMoreData');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _currentPage--;
        });
      }
      if (kDebugMode) print('❌ Error cargando siguiente página: $e');
    }
  }

  Future<void> _loadFilterCounts() async {
    try {
      final counts = await InventoryService.getFilterCounts();
      if (mounted) {
        setState(() => _filterCounts = counts);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading filter counts: $e');
    }
  }

  Future<void> _loadLocations() async {
    try {
      final locations = await InventoryService.getLocations();
      if (mounted) {
        setState(() => _locations = locations);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading locations: $e');
    }
  }

  // ========================================================================
  // SCROLL INFINITO
  // ========================================================================

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  // ========================================================================
  // BÚSQUEDA Y FILTROS
  // ========================================================================

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _isSearching = value.isNotEmpty;
    });
    _debounceSearch();
  }

  Timer? _searchDebounce;
  void _debounceSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _loadFirstPage();
      _loadFilterCounts();
    });
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;

    setState(() => _selectedFilter = filter);
    _loadFirstPage();
  }

  Future<void> _onRefresh() async {
    InventoryService.invalidateCache();
    await _loadInitialData();
  }

  // ← Continúa en PARTE 2
// ============================================================================
// INVENTORY SCREEN - PARTE 2: BUILD Y UI COMPLETA
// ============================================================================
// Agregar después de la PARTE 1 →

  // ========================================================================
  // UI - BUILD PRINCIPAL
  // ========================================================================

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: _buildAppBar(),
        floatingActionButton: _buildFloatingCartButton(),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          color: const Color(0xFF6B8E3D),
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 12),
              _buildFilterChips(),
              const SizedBox(height: 12),
              _buildTotalCounter(),
              const SizedBox(height: 8),
              Expanded(child: _buildInventoryList()),
            ],
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      title: const Text(
        'Inventory',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
      backgroundColor: const Color(0xFF2B5F8C),
      foregroundColor: Colors.white,
      elevation: 2,
      leading: const SizedBox.shrink(),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _showScanner,
          tooltip: 'Scan Code',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _onRefresh,
        ),
        _buildCartAppBarButton(),
        if (_canEdit)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddItemDialog,
          ),
      ],
    );
  }

  // ========================================================================
  // WIDGETS DE BÚSQUEDA Y FILTROS
  // ========================================================================

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(12),
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
      child: Row(
        children: [
          const Icon(Icons.search, color: Color(0xFF2B5F8C)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Search products...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildFilterChip('all', 'ALL', _filterCounts['all'] ?? 0),
          const SizedBox(width: 12),
          _buildFilterChip('normal', 'Normal', _filterCounts['normal'] ?? 0),
          const SizedBox(width: 12),
          _buildFilterChip('low_stock', 'Low Stock', _filterCounts['low_stock'] ?? 0),
          const SizedBox(width: 12),
          _buildFilterChip('out_of_stock', 'Out of Stock', _filterCounts['out_of_stock'] ?? 0),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, int count) {
    final isSelected = _selectedFilter == key;
    return FilterChip(
      label: Text(
        '$label ($count)',
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF2B5F8C),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => _onFilterChanged(key),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF6B8E3D),
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? const Color(0xFF6B8E3D) : Colors.grey.withOpacity(0.3),
      ),
    );
  }

  Widget _buildTotalCounter() {
    final totalProducts = _filterCounts['all'] ?? 0;
    final loadedProducts = _inventory.length;

    if (totalProducts == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2B5F8C).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2B5F8C).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2,
            size: 16,
            color: Color(0xFF2B5F8C),
          ),
          const SizedBox(width: 8),
          Text(
            _isSearching || _selectedFilter != 'all'
                ? 'Showing $loadedProducts${_hasMoreData ? '+' : ''} of $totalProducts products'
                : 'Showing $loadedProducts of $totalProducts products',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2B5F8C),
            ),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // LISTA DE INVENTARIO
  // ========================================================================

  Widget _buildInventoryList() {
    if (_isInitialLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
      );
    }

    if (_inventory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      itemCount: _inventory.length + (_hasMoreData ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _inventory.length) {
          return _buildLoadingMoreIndicator();
        }
        return _buildInventoryCard(_inventory[index]);
      },
    );
  }

  Widget _buildLoadingMoreIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF6B8E3D),
            strokeWidth: 2,
          ),
          const SizedBox(height: 8),
          Text(
            'Loading more products...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty ? Icons.search_off : Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No products found' : 'No products in inventory',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try different search terms'
                : 'Start by adding your first product',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 24),
          if (_canEdit)
            ElevatedButton.icon(
              onPressed: _searchQuery.isNotEmpty
                  ? () {
                _searchController.clear();
                _onSearchChanged('');
              }
                  : _showAddItemDialog,
              icon: Icon(_searchQuery.isNotEmpty ? Icons.clear : Icons.add),
              label: Text(_searchQuery.isNotEmpty ? 'Clear search' : 'Add Product'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ========================================================================
  // CARRITO Y BOTONES
  // ========================================================================

  Widget _buildAddToCartButton(Map<String, dynamic> item) {
    final productId = item['id_inventario'] as int;
    final stock = item['cantidad'] ?? 0;
    final cartQuantity = _cartService.getCartQuantity(productId);
    final availableStock = _cartService.getAvailableStock(productId);

    final canAddToCart = stock > 0 && availableStock > 0;
    final buttonColor = canAddToCart ? const Color(0xFF6B8E3D) : Colors.grey;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: buttonColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: buttonColor.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          IconButton(
            icon: Icon(Icons.add_shopping_cart, size: 20, color: buttonColor),
            onPressed: canAddToCart ? () => _addToCart(item) : null,
            padding: EdgeInsets.zero,
          ),
          if (cartQuantity > 0)
            Positioned(
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.all(2),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B8E3D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white, width: 1),
                ),
                child: Text(
                  cartQuantity.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCartAppBarButton() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ShoppingCartScreen()),
          ),
          tooltip: 'View Cart',
        ),
        if (_cartService.totalItems > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF6B8E3D),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white, width: 1),
              ),
              child: Text(
                _cartService.totalItems > 99 ? '99+' : _cartService.totalItems.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  FloatingActionButton _buildFloatingCartButton() {
    final itemCount = _cartService.totalItems;

    if (itemCount == 0) {
      return FloatingActionButton.extended(
        onPressed: _canEdit ? _showAddItemDialog : null,
        backgroundColor: _canEdit ? const Color(0xFF6B8E3D) : Colors.grey,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const ShoppingCartScreen()),
      ),
      backgroundColor: const Color(0xFF6B8E3D),
      foregroundColor: Colors.white,
      elevation: 8,
      icon: Stack(
        children: [
          const Icon(Icons.shopping_cart),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                itemCount > 99 ? '99+' : itemCount.toString(),
                style: const TextStyle(
                  color: Color(0xFF6B8E3D),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
      label: Text(
        '\$${_cartService.totalAmount.toStringAsFixed(2)}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  void _addToCart(Map<String, dynamic> item) {
    final success = _cartService.addToCart(item);

    if (success) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text('${item['nombre_producto']} added to cart'),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ShoppingCartScreen()),
                  );
                },
                child: const Text('View Cart', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6B8E3D),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      _showErrorSnackBar('Not enough stock available');
    }
  }

  // ← Continúa en PARTE 3
// ============================================================================
// INVENTORY SCREEN - PARTE 3: CARD DE PRODUCTO COMPLETO
// ============================================================================
// Agregar después de la PARTE 2 →

  // ========================================================================
  // CARD DE PRODUCTO CON CARGA LAZY DE DISTRIBUCIÓN
  // ========================================================================

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final stockStatus = item['stock_status'] ?? 'normal';
    final cantidad = item['cantidad'] ?? 0;
    final imageUrl = item['image_url'];
    final isLowStock = stockStatus == 'low_stock';

    Color colorFromHex(String hex) =>
        Color(int.parse(hex.replaceFirst('#', '0xFF')));

    return GestureDetector(
      onTap: isLowStock ? () => _showRestockDialog(item) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isLowStock ? const Color(0xFFFFEBEE) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: isLowStock
              ? Border.all(color: const Color(0xFFEF4444), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: isLowStock
                  ? const Color(0xFFEF4444).withOpacity(0.2)
                  : Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageUrl != null)
                        GestureDetector(
                          onTap: () => _showImagePreview(
                              imageUrl, item['nombre_producto'] ?? 'Product'),
                          child: Container(
                            width: 80,
                            height: 80,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isLowStock
                                    ? const Color(0xFFEF4444)
                                    : Colors.grey.shade200,
                                width: isLowStock ? 2 : 1,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: _buildProductImage(imageUrl),
                            ),
                          ),
                        ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['nombre_producto'] ?? 'Unnamed',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isLowStock
                                    ? const Color(0xFFEF4444)
                                    : const Color(0xFF2B5F8C),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Stock: $cantidad units',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: colorFromHex(InventoryService
                                          .getStockStatusColor(stockStatus)),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: colorFromHex(InventoryService
                                        .getStockStatusColor(stockStatus))
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    InventoryService.getStockStatusText(
                                        stockStatus),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: colorFromHex(InventoryService
                                          .getStockStatusColor(stockStatus)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          _buildAddToCartButton(item),
                          const SizedBox(height: 6),
                          _buildMenuButton(item),
                        ],
                      ),
                    ],
                  ),
                  if (item['descripcion'] != null &&
                      item['descripcion'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3E8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Description:',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2B5F8C),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatDescription(item['descripcion']),
                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                  // 🚀 DISTRIBUCIÓN CON CARGA LAZY
                  _buildDistributionSection(item),
                ],
              ),
            ),
            if (isLowStock)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(15),
                      bottomLeft: Radius.circular(15),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.touch_app, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text(
                        'Tap to Re-stock',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // SECCIÓN DE DISTRIBUCIÓN CON LAZY LOADING
  // ========================================================================

  Widget _buildDistributionSection(Map<String, dynamic> item) {
    final isLoaded = item['_ubicaciones_loaded'] == true;
    final ubicaciones = item['ubicaciones'] as List<dynamic>? ?? [];

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: GestureDetector(
        onTap: () => _handleDistributionTap(item),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3E8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF6B8E3D).withOpacity(0.3),
            ),
          ),
          child: !isLoaded
              ? _buildDistributionPlaceholder()
              : ubicaciones.isEmpty
              ? _buildNoDistribution()
              : _buildDistributionPreview(ubicaciones),
        ),
      ),
    );
  }

  Widget _buildDistributionPlaceholder() {
    return const Row(
      children: [
        Icon(Icons.location_on, size: 14, color: Color(0xFF6B8E3D)),
        SizedBox(width: 6),
        Text(
          'Tap to view locations',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
        Spacer(),
        Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF6B8E3D)),
      ],
    );
  }

  Widget _buildNoDistribution() {
    return const Row(
      children: [
        Icon(Icons.warning, color: Colors.orange, size: 14),
        SizedBox(width: 6),
        Text(
          'No distribution in locations',
          style: TextStyle(fontSize: 10, color: Colors.orange),
        ),
      ],
    );
  }

  Widget _buildDistributionPreview(List<dynamic> ubicaciones) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.location_on, size: 14, color: Color(0xFF6B8E3D)),
            const SizedBox(width: 6),
            const Text(
              'Locations:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B8E3D),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF6B8E3D),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${ubicaciones.length} locations',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios, size: 10, color: Color(0xFF6B8E3D)),
          ],
        ),
        const SizedBox(height: 6),
        ...ubicaciones.take(2).map((loc) => Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B8E3D),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${loc['lugar_fisico']}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${loc['cantidad']} units',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B8E3D),
                ),
              ),
            ],
          ),
        )),
        if (ubicaciones.length > 2) ...[
          const SizedBox(height: 3),
          Text(
            '+ ${ubicaciones.length - 2} more...',
            style: const TextStyle(
              fontSize: 9,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _handleDistributionTap(Map<String, dynamic> item) async {
    // Cargar distribución si no está cargada
    if (item['_ubicaciones_loaded'] != true) {
      final productId = item['id_inventario'] as int;

      // Mostrar loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
        ),
      );

      try {
        final ubicaciones = await InventoryService.loadProductDistribution(productId);

        // Actualizar el item en la lista
        final index = _inventory.indexWhere(
              (i) => i['id_inventario'] == productId,
        );

        if (index != -1 && mounted) {
          setState(() {
            _inventory[index]['ubicaciones'] = ubicaciones;
            _inventory[index]['_ubicaciones_loaded'] = true;
          });
        }

        if (mounted) Navigator.pop(context); // Cerrar loading

        // Mostrar diálogo
        if (mounted) _showLocationDistributionDialog(item);

      } catch (e) {
        if (mounted) {
          Navigator.pop(context);
          _showErrorSnackBar('Error loading distribution: $e');
        }
      }
    } else {
      _showLocationDistributionDialog(item);
    }
  }

  Widget _buildMenuButton(Map<String, dynamic> item) {
    return PopupMenuButton<String>(
      onSelected: (value) => _handleMenuAction(value, item),
      padding: EdgeInsets.zero,
      itemBuilder: (context) => [
        if (_canEdit) ...[
          const PopupMenuItem(
            value: 'image',
            child: Row(
              children: [
                Icon(Icons.image, size: 16),
                SizedBox(width: 8),
                Text('Image', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
        const PopupMenuItem(
          value: 'codes',
          child: Row(
            children: [
              Icon(Icons.qr_code, size: 16),
              SizedBox(width: 8),
              Text('Codes', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        if (_canEdit) ...[
          const PopupMenuItem(
            value: 'distribute',
            child: Row(
              children: [
                Icon(Icons.share_location, size: 16, color: Color(0xFF6B8E3D)),
                SizedBox(width: 8),
                Text('Distribute',
                    style: TextStyle(fontSize: 13, color: Color(0xFF6B8E3D))),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 16),
                SizedBox(width: 8),
                Text('Edit', style: TextStyle(fontSize: 13)),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 16, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red, fontSize: 13)),
              ],
            ),
          ),
        ],
      ],
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.more_vert, color: Colors.grey, size: 18),
      ),
    );
  }

  // ← Continúa en PARTE 4
// ============================================================================
// INVENTORY SCREEN - PARTE 4: UTILIDADES Y HELPERS
// ============================================================================
// Agregar después de la PARTE 3 →

  // ========================================================================
  // UTILIDADES Y HELPERS
  // ========================================================================

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6B8E3D),
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.broken_image, size: 40, color: Colors.grey),
              SizedBox(height: 8),
              Text('Error loading image',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
                SizedBox(height: 8),
                Text('Image not available',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          );
        },
      );
    }
  }

  void _showImagePreview(String imageUrl, String productName) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            Container(
              width: double.infinity,
              height: MediaQuery.of(context).size.height * 0.8,
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF2B5F8C),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.image, color: Colors.white),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            productName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildProductImage(imageUrl),
                      ),
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

  String _formatDescription(dynamic description) {
    if (description == null) return 'No description';
    if (description is Map) {
      final desc = description as Map<String, dynamic>;
      return desc.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
    }
    return description.toString();
  }

  void _handleMenuAction(String action, Map<String, dynamic> item) {
    switch (action) {
      case 'image':
        if (_canEdit) _showImageOptions(item);
        break;
      case 'codes':
        _showCodesDialog(item);
        break;
      case 'distribute':
        if (_canEdit) _showDistributeStockDialog(item);
        break;
      case 'edit':
        if (_canEdit) _showEditItemDialog(item);
        break;
      case 'delete':
        if (_canEdit) _showDeleteConfirmation(item);
        break;
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E3D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(color: Color(0xFF6B8E3D)),
              const SizedBox(width: 16),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
  }

  void _hideLoadingDialog() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ========================================================================
  // DIÁLOGO DE DISTRIBUCIÓN DE UBICACIONES (SOLO VISUALIZACIÓN)
  // ========================================================================

  void _showLocationDistributionDialog(Map<String, dynamic> item) {
    final ubicaciones = item['ubicaciones'] as List<dynamic>? ?? [];
    final totalStock = ubicaciones.fold<int>(
      0,
          (sum, loc) => sum + ((loc['cantidad'] ?? 0) as int),
    );

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF2B5F8C),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['nombre_producto'] ?? 'Product',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Total: $totalStock units',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: ubicaciones.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final loc = ubicaciones[index];
                    final cantidad = (loc['cantidad'] ?? 0) as int;
                    final percentage = totalStock > 0
                        ? (cantidad / totalStock * 100).toStringAsFixed(1)
                        : '0.0';

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F3E8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF6B8E3D).withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6B8E3D).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.store,
                                  color: Color(0xFF6B8E3D),
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      loc['lugar_fisico'] ?? 'Unnamed',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    if (loc['coordenadas'] != null)
                                      Text(
                                        InventoryService.formatCoordinates(
                                            loc['coordenadas']),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Stock',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      '$cantidad units',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6B8E3D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2B5F8C).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '$percentage%',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2B5F8C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: totalStock > 0 ? cantidad / totalStock : 0,
                              backgroundColor: Colors.grey.shade200,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF6B8E3D)),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(12)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B5F8C),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ← Continúa en PARTE 5
// ============================================================================
// INVENTORY SCREEN - PARTE 5: DIÁLOGOS DE IMÁGENES Y ELIMINACIÓN
// ============================================================================
// Agregar después de la PARTE 4 →

  // ========================================================================
  // GESTIÓN DE IMÁGENES
  // ========================================================================

  void _showImageOptions(Map<String, dynamic> item) {
    if (!_canEdit) {
      _showErrorSnackBar('You don\'t have permission to perform this action');
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Product Image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
            ),
            if (item['image_url'] != null)
              ListTile(
                leading: const Icon(Icons.visibility, color: Color(0xFF2B5F8C)),
                title: const Text('View current image'),
                onTap: () {
                  Navigator.pop(context);
                  _showImagePreview(
                    item['image_url'],
                    item['nombre_producto'] ?? 'Product',
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF6B8E3D)),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF2B5F8C)),
              title: const Text('Select from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery, item);
              },
            ),
            if (item['image_url'] != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete image'),
                onTap: () {
                  Navigator.pop(context);
                  _removeImage(item);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, Map<String, dynamic> item) async {
    try {
      _showLoadingDialog('Selecting image...');

      final XFile? image = await ImageService.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      _hideLoadingDialog();

      if (image != null) {
        _showLoadingDialog('Uploading image...');

        try {
          final imageUrl = await ImageService.uploadProductImage(
            File(image.path),
            item['id_inventario'].toString(),
          );

          await InventoryService.updateInventoryItem(
            item['id_inventario'],
            {'image_url': imageUrl},
          );

          _hideLoadingDialog();
          _showSuccessSnackBar('Image updated successfully');
          _onRefresh();
        } catch (e) {
          _hideLoadingDialog();
          _showErrorSnackBar('Error uploading image: $e');
        }
      }
    } catch (e) {
      _hideLoadingDialog();
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _removeImage(Map<String, dynamic> item) async {
    try {
      _showLoadingDialog('Deleting image...');

      if (item['image_url'] != null) {
        await ImageService.deleteProductImage(item['image_url']);
      }

      await InventoryService.updateInventoryItem(
        item['id_inventario'],
        {'image_url': null},
      );

      _hideLoadingDialog();
      _showSuccessSnackBar('Image deleted successfully');
      _onRefresh();
    } catch (e) {
      _hideLoadingDialog();
      _showErrorSnackBar('Error deleting image: $e');
    }
  }

  // ========================================================================
  // ELIMINACIÓN DE PRODUCTO
  // ========================================================================

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    if (!_canEdit) {
      _showErrorSnackBar('You don\'t have permission to perform this action');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirm Deletion'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${item['nombre_producto']}"?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await InventoryService.deleteInventoryItem(
                  item['id_inventario'],
                );
                _showSuccessSnackBar('Product deleted successfully');
                Navigator.pop(context);
                _onRefresh();
              } catch (e) {
                _showErrorSnackBar('Error deleting product: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // SCANNER Y CÓDIGOS
  // ========================================================================

  void _showScanner() async {
    final cameraAvailable = await ImageService.isCameraAvailable();
    if (!cameraAvailable) {
      _showErrorSnackBar(
        'Camera unavailable. Check permissions in Settings.',
      );
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _ScannerScreen()),
    );

    if (result != null) {
      _handleScannedCode(result);
    }
  }

  void _handleScannedCode(String code) async {
    try {
      final item = await InventoryService.getItemByQRCode(code);
      if (item != null) {
        _showScannedItemDialog(item);
      } else {
        final results = await InventoryService.searchByBarcode(
          {'barcode_data': code},
        );
        if (results.isNotEmpty) {
          _showScannedItemDialog(results.first);
        } else {
          if (_canEdit) {
            _showCreateFromCodeDialog(code);
          } else {
            _showErrorSnackBar('Product not found');
          }
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error processing code: $e');
    }
  }

  void _showScannedItemDialog(Map<String, dynamic> item) {
    showScannedProductDialogWithCart(
      context,
      item,
      onEdit: () => _showEditItemDialog(item),
      onCartUpdated: () => _onRefresh(),
    );
  }

  void _showCreateFromCodeDialog(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.qr_code_scanner, color: Color(0xFF2B5F8C)),
            SizedBox(width: 8),
            Text('Code Not Found'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'The scanned code does not match any product in your inventory.',
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                code,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Do you want to create a new product with this code?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showItemDialogWithCode(code);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Create Product'),
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // DIÁLOGOS DE PRODUCTO (AGREGAR/EDITAR)
  // ========================================================================

  void _showAddItemDialog() {
    if (!_canEdit) {
      _showErrorSnackBar('You don\'t have permission to perform this action');
      return;
    }
    _showItemDialog();
  }

  void _showEditItemDialog(Map<String, dynamic> item) {
    if (!_canEdit) {
      _showErrorSnackBar('You don\'t have permission to perform this action');
      return;
    }
    _showItemDialog(item: item);
  }

  void _showItemDialog({Map<String, dynamic>? item}) {
    showDialog(
      context: context,
      builder: (context) => _ItemFormDialog(
        item: item,
        locations: _locations,
        onSave: (itemData, isEditing) async {
          try {
            if (isEditing) {
              await InventoryService.updateInventoryItem(
                item!['id_inventario'],
                itemData,
              );
              _showSuccessSnackBar('Product updated successfully');
            } else {
              await InventoryService.createInventoryItem(itemData);
              _showSuccessSnackBar('Product added successfully');
            }
            _onRefresh();
          } catch (e) {
            _showErrorSnackBar('Error: $e');
          }
        },
        onAddLocation: _showAddLocationDialog,
      ),
    );
  }

  void _showItemDialogWithCode(String code) {
    showDialog(
      context: context,
      builder: (context) => _ItemFormDialog(
        prefilledCode: code,
        locations: _locations,
        onSave: (itemData, _) async {
          try {
            await InventoryService.createInventoryItem(itemData);
            _showSuccessSnackBar('Product created successfully');
            _onRefresh();
          } catch (e) {
            _showErrorSnackBar('Error: $e');
          }
        },
        onAddLocation: _showAddLocationDialog,
      ),
    );
  }

  void _showAddLocationDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _LocationFormDialog(),
    );

    if (result != null) {
      try {
        await InventoryService.createLocation(result);
        _showSuccessSnackBar('Location added successfully');
        await _loadLocations();
      } catch (e) {
        _showErrorSnackBar('Error creating location: $e');
      }
    }
  }

  // ← Continúa en PARTE 6
// ============================================================================
// INVENTORY SCREEN - PARTE 6: DIÁLOGOS RESTOCK Y DISTRIBUCIÓN
// ============================================================================
// Agregar después de la PARTE 5 →

  // ========================================================================
  // DIÁLOGO DE RESTOCK
  // ========================================================================

  void _showRestockDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _RestockDialog(
        item: item,
        onRestockRequested: (quantity, priority, notes) async {
          try {
            await InventoryService.createRestockRequest(
              productId: item['id_inventario'],
              requestedQuantity: quantity,
              priority: priority,
              notes: notes,
            );

            if (mounted) {
              _showSuccessSnackBar('✅ Restock request sent successfully');
              _onRefresh();
            }
          } catch (e) {
            if (mounted) {
              _showErrorSnackBar('Error sending restock request: $e');
            }
          }
        },
      ),
    );
  }

  // ========================================================================
  // DIÁLOGO DE DISTRIBUCIÓN DE STOCK
  // ========================================================================

  void _showDistributeStockDialog(Map<String, dynamic> item) async {
    if (!_canEdit) {
      _showErrorSnackBar('You don\'t have permission to perform this action');
      return;
    }

    if (_locations.isEmpty) {
      _showErrorSnackBar('You must create at least one location first');
      return;
    }

    // Cargar distribución si no está cargada
    if (item['_ubicaciones_loaded'] != true) {
      _showLoadingDialog('Loading distribution...');
      try {
        final productId = item['id_inventario'] as int;
        final ubicaciones =
        await InventoryService.loadProductDistribution(productId);

        final index = _inventory.indexWhere(
              (i) => i['id_inventario'] == productId,
        );

        if (index != -1 && mounted) {
          setState(() {
            _inventory[index]['ubicaciones'] = ubicaciones;
            _inventory[index]['_ubicaciones_loaded'] = true;
          });
        }

        _hideLoadingDialog();
      } catch (e) {
        _hideLoadingDialog();
        _showErrorSnackBar('Error loading distribution: $e');
        return;
      }
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _DistributeStockDialog(
        item: item,
        locations: _locations,
      ),
    );

    if (result == true) {
      _onRefresh();
    }
  }

  // ========================================================================
  // DIÁLOGO DE CÓDIGOS QR/BARCODE
  // ========================================================================

  void _showCodesDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => _CodesDialog(item: item),
    );
  }

// ← Continúa en PARTE 7 con los widgets de diálogos
}

// ============================================================================
// WIDGET: DIÁLOGO DE RESTOCK
// ============================================================================

class _RestockDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final Function(int quantity, String priority, String? notes)
  onRestockRequested;

  const _RestockDialog({
    required this.item,
    required this.onRestockRequested,
  });

  @override
  State<_RestockDialog> createState() => _RestockDialogState();
}

class _RestockDialogState extends State<_RestockDialog> {
  late final TextEditingController _quantityController;
  late final TextEditingController _notesController;
  String _selectedPriority = 'normal';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final alertaCantidad = widget.item['alerta_cantidad'] ?? 10;
    final cantidadActual = widget.item['cantidad'] ?? 0;
    final suggestedQuantity = (alertaCantidad * 2) - cantidadActual;

    _quantityController = TextEditingController(
      text: suggestedQuantity > 0 ? suggestedQuantity.toString() : '10',
    );
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentStock = widget.item['cantidad'] ?? 0;
    final alertStock = widget.item['alerta_cantidad'] ?? 5;
    final supplierInfo = widget.item['proveedor_nombre'];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 650),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFEF4444),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.warning_rounded,
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
                              'LOW STOCK ALERT',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.item['nombre_producto'] ?? 'Product',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                'Current Stock',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$currentStock',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        Expanded(
                          child: Column(
                            children: [
                              const Text(
                                'Alert Level',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$alertStock',
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
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (supplierInfo != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3E8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF6B8E3D).withOpacity(0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.store,
                                color: Color(0xFF6B8E3D), size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Supplier',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    supplierInfo,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF6B8E3D),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF6B8E3D),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Will be notified',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    const Text(
                      'Request Quantity',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _quantityController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Units to request',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.inventory_2),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () {
                                final current =
                                    int.tryParse(_quantityController.text) ?? 0;
                                if (current > 1) {
                                  _quantityController.text =
                                      (current - 1).toString();
                                }
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline),
                              onPressed: () {
                                final current =
                                    int.tryParse(_quantityController.text) ?? 0;
                                _quantityController.text =
                                    (current + 1).toString();
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Priority Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildPriorityChip('low', 'Low', Colors.grey),
                        _buildPriorityChip('normal', 'Normal', Colors.blue),
                        _buildPriorityChip('high', 'High', Colors.orange),
                        _buildPriorityChip('urgent', 'URGENT', Colors.red),
                      ],
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Additional Notes (Optional)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Add any special instructions or notes',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.note_alt_outlined),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: _isLoading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.send),
                      label: Text(_isLoading ? 'Sending...' : 'Send Request'),
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

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _selectedPriority == value;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : color,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPriority = value);
        }
      },
      backgroundColor: Colors.white,
      selectedColor: color,
      checkmarkColor: Colors.white,
      side: BorderSide(color: color),
    );
  }

  void _handleSubmit() async {
    final quantity = int.tryParse(_quantityController.text);

    if (quantity == null || quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid quantity'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await widget.onRestockRequested(
        quantity,
        _selectedPriority,
        _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
}

// ← Continúa en PARTE 7 final con más diálogos
// ============================================================================
// INVENTORY SCREEN - PARTE 7 FINAL: TODOS LOS DIÁLOGOS COMPLETOS
// ============================================================================
// Agregar después de la PARTE 6 →
// Esta es la parte FINAL que cierra el archivo

// ============================================================================
// WIDGET: DIÁLOGO DE DISTRIBUCIÓN DE STOCK
// ============================================================================

class _DistributeStockDialog extends StatefulWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> locations;

  const _DistributeStockDialog({
    required this.item,
    required this.locations,
  });

  @override
  State<_DistributeStockDialog> createState() => _DistributeStockDialogState();
}

class _DistributeStockDialogState extends State<_DistributeStockDialog> {
  late Map<int, int> _distribution;
  late int _totalStock;
  late int _distributedStock;
  bool _isLoading = false;
  bool _useSliders = true;

  @override
  void initState() {
    super.initState();
    _totalStock = widget.item['cantidad'] ?? 0;
    _distribution = {};
    _distributedStock = 0;
    _loadExistingDistribution();
  }

  Future<void> _loadExistingDistribution() async {
    final ubicaciones = widget.item['ubicaciones'] as List<dynamic>? ?? [];
    for (var loc in ubicaciones) {
      final idLocat = loc['id_locat'] as int;
      final cantidad = loc['cantidad'] as int;
      _distribution[idLocat] = cantidad;
    }
    _calculateDistributed();
  }

  void _calculateDistributed() {
    setState(() {
      _distributedStock = _distribution.values.fold(0, (sum, qty) => sum + qty);
    });
  }

  int get _remainingStock => _totalStock - _distributedStock;

  Color get _statusColor {
    if (_remainingStock < 0) return Colors.red;
    if (_remainingStock == 0) return const Color(0xFF6B8E3D);
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Column(
          children: [
            _buildHeader(),
            _buildStockSummary(),
            _buildToggleButton(),
            Expanded(child: _buildLocationsList()),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2B5F8C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: [
          const Icon(Icons.share_location, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.item['nombre_producto'] ?? 'Product',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  'Distribute Stock',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _statusColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStockInfo('Total Stock', _totalStock, Colors.blue),
              _buildStockInfo('Distributed', _distributedStock, const Color(0xFF6B8E3D)),
              _buildStockInfo('Remaining', _remainingStock, _statusColor),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _totalStock > 0 ? _distributedStock / _totalStock : 0,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(_statusColor),
              minHeight: 8,
            ),
          ),
          if (_remainingStock < 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Exceeded by ${-_remainingStock} units!',
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStockInfo(String label, int value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value.toString(),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text(
            'Input Method:',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment<bool>(
                value: true,
                label: Text('Sliders', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.tune, size: 16),
              ),
              ButtonSegment<bool>(
                value: false,
                label: Text('Manual', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.keyboard, size: 16),
              ),
            ],
            selected: {_useSliders},
            onSelectionChanged: (Set<bool> newSelection) {
              setState(() => _useSliders = newSelection.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLocationsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: widget.locations.length,
      itemBuilder: (context, index) {
        final location = widget.locations[index];
        final locationId = location['id_locat'] as int;
        final currentQty = _distribution[locationId] ?? 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3E8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: currentQty > 0
                  ? const Color(0xFF6B8E3D).withOpacity(0.3)
                  : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B8E3D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: Color(0xFF6B8E3D),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location['lugar_fisico'] ?? 'Unnamed',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (location['coordenadas'] != null)
                          Text(
                            InventoryService.formatCoordinates(
                                location['coordenadas']),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '$currentQty units',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B8E3D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _useSliders
                  ? _buildSliderInput(locationId, currentQty)
                  : _buildManualInput(locationId, currentQty),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliderInput(int locationId, int currentQty) {
    return Column(
      children: [
        Slider(
          value: currentQty.toDouble(),
          min: 0,
          max: _totalStock.toDouble(),
          divisions: _totalStock > 0 ? _totalStock : 1,
          activeColor: const Color(0xFF6B8E3D),
          inactiveColor: Colors.grey.shade300,
          onChanged: (value) {
            setState(() {
              _distribution[locationId] = value.toInt();
              _calculateDistributed();
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: currentQty > 0
                  ? () {
                setState(() {
                  _distribution[locationId] =
                      (currentQty - 1).clamp(0, _totalStock);
                  _calculateDistributed();
                });
              }
                  : null,
              color: const Color(0xFF6B8E3D),
            ),
            Text(
              'Adjust quantity',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: currentQty < _totalStock
                  ? () {
                setState(() {
                  _distribution[locationId] =
                      (currentQty + 1).clamp(0, _totalStock);
                  _calculateDistributed();
                });
              }
                  : null,
              color: const Color(0xFF6B8E3D),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildManualInput(int locationId, int currentQty) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: 'Quantity',
              border: const OutlineInputBorder(),
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              suffixText: '/ $_totalStock',
            ),
            controller: TextEditingController(text: currentQty.toString()),
            onChanged: (value) {
              final qty = int.tryParse(value) ?? 0;
              setState(() {
                _distribution[locationId] = qty.clamp(0, _totalStock);
                _calculateDistributed();
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () {
            setState(() {
              _distribution[locationId] = 0;
              _calculateDistributed();
            });
          },
          color: Colors.red,
          tooltip: 'Clear',
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    final canSave = _remainingStock >= 0 && _distributedStock > 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        children: [
          if (_remainingStock > 0)
            Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have $_remainingStock units not distributed',
                      style: const TextStyle(color: Colors.orange, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: canSave && !_isLoading ? _saveDistribution : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B8E3D),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                      : const Text('Save Distribution'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveDistribution() async {
    setState(() => _isLoading = true);

    try {
      final productId = widget.item['id_inventario'] as int;

      if (kDebugMode) {
        print('💾 Saving distribution...');
        print('   Product ID: $productId');
        print('   Distribution: $_distribution');
      }

      await InventoryService.distributeStockRPC(productId, _distribution);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Stock distributed successfully'),
            backgroundColor: Color(0xFF6B8E3D),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Complete error: $e');
      }

      if (mounted) {
        final errorMessage = e
            .toString()
            .replaceAll('Exception: ', '')
            .replaceAll('Error: ', '');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ← Continúa en el siguiente archivo (PARTE 7B)
// ============================================================================
// INVENTORY SCREEN - PARTE 7B: FORM DIALOG COMPLETO
// ============================================================================
// Agregar después de la PARTE 7A →

// ============================================================================
// WIDGET: DIÁLOGO DE FORMULARIO DE PRODUCTO (AGREGAR/EDITAR)
// ============================================================================

class _ItemFormDialog extends StatefulWidget {
  final Map<String, dynamic>? item;
  final List<Map<String, dynamic>> locations;
  final String? prefilledCode;
  final Function(Map<String, dynamic>, bool) onSave;
  final VoidCallback onAddLocation;

  const _ItemFormDialog({
    this.item,
    required this.locations,
    this.prefilledCode,
    required this.onSave,
    required this.onAddLocation,
  });

  @override
  State<_ItemFormDialog> createState() => _ItemFormDialogState();
}

class _ItemFormDialogState extends State<_ItemFormDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _cantidadController;
  late final TextEditingController _alertaController;
  late final TextEditingController _descripcionController;
  late final TextEditingController _qrController;
  late final TextEditingController _precioController;

  int? _selectedLocationId;
  bool _isLoading = false;
  String? _selectedImagePath;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.item?['nombre_producto'] ?? '');
    _cantidadController =
        TextEditingController(text: widget.item?['cantidad']?.toString() ?? '');
    _alertaController = TextEditingController(
        text: widget.item?['alerta_cantidad']?.toString() ?? '');
    _descripcionController =
        TextEditingController(text: _formatDescription(widget.item?['descripcion']));
    _qrController = TextEditingController(
        text: widget.prefilledCode ??
            widget.item?['codigo_barras']?['qr_data'] ??
            '');
    _precioController =
        TextEditingController(text: widget.item?['precio']?.toString() ?? '');

    if (widget.item == null) {
      _selectedLocationId = null;
    }

    _currentImageUrl = widget.item?['image_url'];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cantidadController.dispose();
    _alertaController.dispose();
    _descripcionController.dispose();
    _qrController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  String _formatDescription(dynamic description) {
    if (description == null) return '';
    if (description is Map) {
      final desc = description as Map<String, dynamic>;
      return desc.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
    }
    return description.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2B5F8C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Icon(isEditing ? Icons.edit : Icons.add, color: Colors.white),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Product',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.prefilledCode != null)
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B8E3D).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info,
                                color: Color(0xFF6B8E3D), size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Detected code: ${widget.prefilledCode}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Product image
                    const Text(
                      'Product Image',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildImageSection(),
                    const SizedBox(height: 16),

                    // Basic information
                    const Text(
                      'Product Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Product Name *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.label),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // Stock and alerts
                    const Text(
                      'Stock and Alerts',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _cantidadController,
                            decoration: const InputDecoration(
                              labelText: 'Quantity',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.inventory),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _alertaController,
                            decoration: const InputDecoration(
                              labelText: 'Stock Alert',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.warning),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Price
                    const Text(
                      'Price',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _precioController,
                      decoration: const InputDecoration(
                        labelText: 'Unit Price',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.attach_money),
                        prefixText: '\$',
                      ),
                      keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),

                    // Codes
                    const Text(
                      'Identification Codes',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qrController,
                      decoration: InputDecoration(
                        labelText: 'QR/Barcode (Optional)',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.qr_code),
                        enabled: widget.prefilledCode == null,
                        suffixIcon: widget.prefilledCode == null
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.qr_code_scanner),
                              onPressed: _scanCode,
                              tooltip: 'Scan',
                            ),
                            IconButton(
                              icon: const Icon(Icons.auto_awesome),
                              onPressed: _generateCode,
                              tooltip: 'Generate',
                            ),
                          ],
                        )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Location
                    if (!isEditing) ...[
                      const Text(
                        'Initial Location (Optional)',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2B5F8C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<int?>(
                        value: _selectedLocationId,
                        decoration: const InputDecoration(
                          labelText: 'Select Initial Location',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                          helperText: 'You can distribute later',
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('No initial location'),
                          ),
                          ...widget.locations.map(
                                (location) => DropdownMenuItem<int?>(
                              value: location['id_locat'] as int?,
                              child: Text(location['lugar_fisico'] ??
                                  'Unnamed location'),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _selectedLocationId = value),
                      ),
                      if (widget.locations.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: TextButton.icon(
                            onPressed: widget.onAddLocation,
                            icon: const Icon(Icons.add_location),
                            label: const Text('Create first location'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF6B8E3D),
                            ),
                          ),
                        ),
                    ],

                    // Distribution info when editing
                    if (isEditing) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F3E8),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0xFF6B8E3D).withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.info_outline,
                                    color: Color(0xFF6B8E3D), size: 16),
                                SizedBox(width: 8),
                                Text(
                                  'Stock Distribution',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF6B8E3D),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'To modify distribution between locations, use the "Distribute" button in the product card.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            if ((widget.item?['ubicaciones'] as List?)
                                ?.isNotEmpty ??
                                false) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Current: ${(widget.item?['ubicaciones'] as List).length} locations',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveItem,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E3D),
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : Text(isEditing ? 'Update' : 'Add'),
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

  Widget _buildImageSection() {
    return Container(
      height: 120,
      width: double.infinity,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: _selectedImagePath != null
          ? _buildSelectedImage()
          : _currentImageUrl != null
          ? _buildCurrentImage()
          : _buildImagePlaceholder(),
    );
  }

  Widget _buildSelectedImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_selectedImagePath!),
            width: double.infinity,
            height: 120,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 20),
              onPressed: () => setState(() => _selectedImagePath = null),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _currentImageUrl!.startsWith('http')
              ? CachedNetworkImage(
            imageUrl: _currentImageUrl!,
            width: double.infinity,
            height: 120,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: Colors.grey.shade200,
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF6B8E3D),
                  strokeWidth: 2,
                ),
              ),
            ),
            errorWidget: (context, url, error) => _buildImagePlaceholder(),
          )
              : Image.file(
            File(_currentImageUrl!),
            width: double.infinity,
            height: 120,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                _buildImagePlaceholder(),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white, size: 20),
              onSelected: (value) {
                switch (value) {
                  case 'change':
                    _showImagePickerOptions();
                    break;
                  case 'remove':
                    setState(() => _currentImageUrl = null);
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'change',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16),
                      SizedBox(width: 8),
                      Text('Change')
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return GestureDetector(
      onTap: _showImagePickerOptions,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.grey.shade300,
            style: BorderStyle.solid,
          ),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo, size: 32, color: Color(0xFF6B8E3D)),
            SizedBox(height: 8),
            Text(
              'Add product image',
              style: TextStyle(
                color: Color(0xFF6B8E3D),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Tap to select or take photo',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Image',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF6B8E3D)),
              title: const Text('Take photo'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading:
              const Icon(Icons.photo_library, color: Color(0xFF2B5F8C)),
              title: const Text('Select from gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await ImageService.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImagePath = image.path;
          _currentImageUrl = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _scanCode() async {
    final cameraAvailable = await ImageService.isCameraAvailable();
    if (!cameraAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera not available')),
      );
      return;
    }

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _ScannerScreen()),
    );

    if (result != null) {
      setState(() => _qrController.text = result);
    }
  }

  void _generateCode() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a product name first')),
      );
      return;
    }

    final cleanName = _nameController.text.replaceAll(' ', '').toUpperCase();
    final prefix = cleanName.length > 3 ? cleanName.substring(0, 3) : cleanName;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    final generatedCode = 'MIA$prefix$timestamp';

    setState(() => _qrController.text = generatedCode);
  }

  Future<void> _saveItem() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product name is required')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? finalImageUrl = _currentImageUrl;

      if (_selectedImagePath != null) {
        final tempId = widget.item?['id_inventario']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();

        finalImageUrl = await ImageService.uploadProductImage(
          File(_selectedImagePath!),
          tempId,
        );
      }

      final itemData = {
        'nombre_producto': _nameController.text.trim(),
        'descripcion': _descripcionController.text.trim().isEmpty
            ? null
            : {'descripcion': _descripcionController.text.trim()},
        'cantidad': int.tryParse(_cantidadController.text) ?? 0,
        'alerta_cantidad': int.tryParse(_alertaController.text) ?? 5,
        'precio': double.tryParse(_precioController.text) ?? 0.0,
        'image_url': finalImageUrl,
        'codigo_barras': _qrController.text.trim().isEmpty
            ? null
            : {
          'qr_data': _qrController.text.trim(),
          'barcode_data': _qrController.text.trim(),
          'type': widget.prefilledCode != null ? 'scanned' : 'custom',
          'generated_at': DateTime.now().toIso8601String(),
        },
      };

      if (widget.item == null && _selectedLocationId != null) {
        itemData['id_location'] = _selectedLocationId;
      }

      await widget.onSave(itemData, widget.item != null);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

// ← Continúa en PARTE 7C (Codes, Scanner, Location)
// ============================================================================
// INVENTORY SCREEN - PARTE 7C FINAL: CODES, SCANNER Y LOCATION
// ============================================================================
// Agregar después de la PARTE 7B →
// ESTA ES LA ÚLTIMA PARTE QUE CIERRA TODO EL ARCHIVO

// ============================================================================
// WIDGET: DIÁLOGO DE CÓDIGOS QR/BARCODE
// ============================================================================

class _CodesDialog extends StatelessWidget {
  final Map<String, dynamic> item;

  const _CodesDialog({required this.item});

  @override
  Widget build(BuildContext context) {
    final qrData = _getQRData();
    final barcodeData = _getBarcodeData();

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF2B5F8C),
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.qr_code, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Codes - ${item['nombre_producto']}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Flexible(
              child: DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Color(0xFF2B5F8C),
                      tabs: [
                        Tab(icon: Icon(Icons.qr_code), text: 'QR'),
                        Tab(icon: Icon(Icons.view_stream), text: 'Barcode'),
                      ],
                    ),
                    Flexible(
                      child: TabBarView(
                        children: [
                          _buildQRTab(qrData),
                          _buildBarcodeTab(barcodeData),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('QR code copied')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E3D),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: barcodeData));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Barcode copied')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy Barcode'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5F8C),
                        foregroundColor: Colors.white,
                      ),
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

  String _getQRData() {
    try {
      if (item['codigo_barras'] != null &&
          item['codigo_barras']['qr_data'] != null) {
        return item['codigo_barras']['qr_data'];
      }
      return InventoryService.generateQRData(item);
    } catch (e) {
      return 'MIA:${item['id_inventario']}:${item['nombre_producto']}';
    }
  }

  String _getBarcodeData() {
    try {
      if (item['codigo_barras'] != null &&
          item['codigo_barras']['barcode_data'] != null) {
        return item['codigo_barras']['barcode_data'];
      }
      return InventoryService.generateBarcodeData(item);
    } catch (e) {
      final id = item['id_inventario']?.toString() ?? '0';
      return 'MIA${id.padLeft(8, '0')}';
    }
  }

  Widget _buildQRTab(String qrData) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 180.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              errorStateBuilder: (context, error) {
                return Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error, color: Colors.red, size: 32),
                      SizedBox(height: 8),
                      Text(
                        'Error generating QR',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'QR Code (2D)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5F8C),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Contains complete product information',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeTab(String barcodeData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildBarcodeContainer(
            'Code128',
            barcode_widget.Barcode.code128(),
            barcodeData,
          ),
          const SizedBox(height: 16),
          _buildBarcodeContainer(
            'EAN13',
            barcode_widget.Barcode.ean13(),
            _generateEAN13(barcodeData),
          ),
          const SizedBox(height: 16),
          _buildBarcodeContainer(
            'Code39',
            barcode_widget.Barcode.code39(),
            _sanitizeCode39(barcodeData),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeContainer(
      String title,
      barcode_widget.Barcode barcode,
      String data,
      ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5F8C),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 60,
            child: barcode_widget.BarcodeWidget(
              barcode: barcode,
              data: data,
              width: 200,
              height: 60,
              style: const TextStyle(fontSize: 10),
              drawText: true,
              errorBuilder: (context, error) {
                return Container(
                  width: 200,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 16),
                      const SizedBox(height: 2),
                      Text(
                        'Error: $title',
                        style: const TextStyle(color: Colors.red, fontSize: 10),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _generateEAN13(String original) {
    String numeric = original.replaceAll(RegExp(r'[^0-9]'), '');
    if (numeric.length < 12) {
      numeric = numeric.padRight(12, '0');
    } else if (numeric.length > 12) {
      numeric = numeric.substring(0, 12);
    }

    int checksum = 0;
    for (int i = 0; i < 12; i++) {
      final digit = int.parse(numeric[i]);
      checksum += i % 2 == 0 ? digit : digit * 3;
    }
    final checkDigit = (10 - (checksum % 10)) % 10;

    return numeric + checkDigit.toString();
  }

  String _sanitizeCode39(String original) {
    final cleaned = original
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9\-\.\$\/\+%]'), '');
    return cleaned.substring(
        0, cleaned.length > 20 ? 20 : cleaned.length);
  }
}

// ============================================================================
// WIDGET: SCANNER SCREEN
// ============================================================================

class _ScannerScreen extends StatefulWidget {
  const _ScannerScreen();

  @override
  State<_ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<_ScannerScreen> {
  late MobileScannerController _controller;
  String? _lastCode;
  DateTime? _lastScanTime;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
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
        title: const Text('Scan Code'),
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
          _buildInstructions(),
          _buildManualEntryButton(),
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

  Widget _buildInstructions() {
    return Positioned(
      bottom: 120,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          children: [
            Icon(Icons.qr_code_scanner, color: Colors.white, size: 32),
            SizedBox(height: 8),
            Text(
              'Place the code inside the frame',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Supports QR, Code128, EAN13, Code39 and more',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildManualEntryButton() {
    return Positioned(
      bottom: 40,
      left: 20,
      right: 20,
      child: ElevatedButton.icon(
        onPressed: _showManualEntry,
        icon: const Icon(Icons.keyboard),
        label: const Text('Manual Entry'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final code = capture.barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        final now = DateTime.now();
        if (_lastScanTime != null &&
            now.difference(_lastScanTime!).inMilliseconds < 1000 &&
            _lastCode == code) {
          return;
        }

        setState(() {
          _lastCode = code;
          _lastScanTime = now;
        });

        HapticFeedback.mediumImpact();
        _showConfirmation(code);
      }
    }
  }

  void _showConfirmation(String code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF6B8E3D)),
            SizedBox(width: 8),
            Text('Code Detected'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                code,
                style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Use this code?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Scanning'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, code);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Use Code'),
          ),
        ],
      ),
    );
  }

  void _showManualEntry() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the code manually:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Code',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context);
                Navigator.pop(context, controller.text.trim());
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Use Code'),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// WIDGET: LOCATION FORM DIALOG
// ============================================================================

class _LocationFormDialog extends StatefulWidget {
  const _LocationFormDialog();

  @override
  State<_LocationFormDialog> createState() => _LocationFormDialogState();
}

class _LocationFormDialogState extends State<_LocationFormDialog> {
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_location, color: Color(0xFF6B8E3D)),
          SizedBox(width: 8),
          Text('Add Location'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Location Name *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  decoration: const InputDecoration(
                    labelText: 'Lat',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.explore),
                  ),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lngController,
                  decoration: const InputDecoration(
                    labelText: 'Lng',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.explore_off),
                  ),
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Coordinates are optional. You can get them from Google Maps or GPS.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Location name is required')),
              );
              return;
            }

            final locationData = {
              'lugar_fisico': _nameController.text.trim(),
              'coordenadas': (_latController.text.isNotEmpty &&
                  _lngController.text.isNotEmpty)
                  ? {
                'lat': double.tryParse(_latController.text) ?? 0.0,
                'lng': double.tryParse(_lngController.text) ?? 0.0,
              }
                  : null,
            };

            Navigator.pop(context, locationData);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B8E3D),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

// ============================================================================
// ✅ FIN DEL ARCHIVO COMPLETO
// ============================================================================
// Aquí termina inventory_screen.dart con TODAS las funciones completas