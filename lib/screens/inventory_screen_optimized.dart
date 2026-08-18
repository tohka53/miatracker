import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/cart_service.dart';
import '../services/inventory_service.dart';
import '../services/inventory_service_optimized.dart' hide InventoryService; // Nuevo servicio optimizado
import '../services/profile_service.dart';
import '../screens/shopping_cart_screen.dart';
import '../widgets/collapsible_drawer.dart';

/// ===========================
///  INVENTORY SCREEN OPTIMIZADO CON LAZY LOADING
/// ===========================
class InventoryScreenOptimized extends StatefulWidget {
  const InventoryScreenOptimized({super.key});

  @override
  State<InventoryScreenOptimized> createState() => _InventoryScreenOptimizedState();
}

class _InventoryScreenOptimizedState extends State<InventoryScreenOptimized> {
  // Lista de productos con paginación
  final List<Map<String, dynamic>> _inventory = [];
  final List<Map<String, dynamic>> _filteredInventory = [];
  List<Map<String, dynamic>> _locations = [];

  // Control de paginación
  int _currentPage = 0;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Estados
  bool _isInitialLoading = true;
  String _searchQuery = '';
  String _selectedFilter = 'all';
  String? _userRole;
  Map<String, int> _filterCounts = {};

  // Controllers
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CartService _cartService = CartService();

  // Debounce para búsqueda
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadInitialData();
    _setupScrollListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      // Cargar más cuando llegue al 80% del scroll
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent * 0.8) {
        _loadMoreProducts();
      }
    });
  }

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

  bool get _canEdit {
    return _userRole == 'admin' || _userRole == 'supervisor';
  }

  /// Carga inicial - Solo primeros 20 registros
  Future<void> _loadInitialData() async {
    try {
      setState(() {
        _isInitialLoading = true;
        _currentPage = 0;
        _inventory.clear();
        _filteredInventory.clear();
      });

      // Cargar ubicaciones en paralelo (sin bloquear)
      _loadLocations();

      // Cargar contadores de filtros (muy rápido)
      _loadFilterCounts();

      // Cargar primera página de productos
      final result = await InventoryService.getInventoryPaged(page: 0);

      if (mounted) {
        setState(() {
          _inventory.addAll(result['items'] as List<Map<String, dynamic>>);
          _filteredInventory.addAll(_inventory);
          _hasMore = result['hasMore'] as bool;
          _currentPage = 1;
          _isInitialLoading = false;
        });

        _cartService.updateInventory(_inventory);

        // Cargar detalles de productos visibles en background
        _loadVisibleProductDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        _showErrorSnackBar('Error loading inventory: $e');
      }
    }
  }

  /// Carga más productos al hacer scroll
  Future<void> _loadMoreProducts() async {
    if (!_hasMore || _isLoadingMore || _searchQuery.isNotEmpty) return;

    try {
      setState(() => _isLoadingMore = true);

      final result = await InventoryService.getInventoryPaged(
        page: _currentPage,
      );

      if (mounted) {
        setState(() {
          final newItems = result['items'] as List<Map<String, dynamic>>;
          _inventory.addAll(newItems);
          _filteredInventory.addAll(newItems);
          _hasMore = result['hasMore'] as bool;
          _currentPage++;
          _isLoadingMore = false;
        });

        _cartService.updateInventory(_inventory);
        _loadVisibleProductDetails();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingMore = false);
        if (kDebugMode) print('Error loading more: $e');
      }
    }
  }

  /// Carga detalles de productos visibles (lazy)
  Future<void> _loadVisibleProductDetails() async {
    // Determinar qué productos están visibles
    final firstVisibleIndex =
    (_scrollController.hasClients && _scrollController.position.pixels > 0)
        ? (_scrollController.position.pixels / 120).floor()
        : 0;

    final lastVisibleIndex = firstVisibleIndex + 10; // ~10 productos visibles

    for (int i = firstVisibleIndex;
    i < lastVisibleIndex && i < _filteredInventory.length;
    i++) {
      final product = _filteredInventory[i];

      // Cargar ubicaciones si no están cargadas
      if (product['_ubicaciones_loaded'] != true) {
        _loadProductLocations(product['id_inventario'], i);
      }
    }
  }

  /// Carga ubicaciones de un producto específico
  Future<void> _loadProductLocations(int productId, int index) async {
    try {
      final ubicaciones = await InventoryService.getProductLocationDistribution(
        productId,
      );

      if (mounted && index < _filteredInventory.length) {
        setState(() {
          _filteredInventory[index]['ubicaciones'] = ubicaciones;
          _filteredInventory[index]['_ubicaciones_loaded'] = true;
        });

        // Actualizar también en _inventory
        final invIndex = _inventory.indexWhere(
              (item) => item['id_inventario'] == productId,
        );
        if (invIndex != -1) {
          _inventory[invIndex]['ubicaciones'] = ubicaciones;
          _inventory[invIndex]['_ubicaciones_loaded'] = true;
        }
      }
    } catch (e) {
      if (kDebugMode) print('Error loading locations for $productId: $e');
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

  Future<void> _loadFilterCounts() async {
    try {
      final counts = await InventoryServiceOptimized.getFilterCounts();
      if (mounted) {
        setState(() => _filterCounts = counts);
      }
    } catch (e) {
      if (kDebugMode) print('Error loading filter counts: $e');
    }
  }

  /// Aplicar filtros localmente
  void _applyLocalFilter() {
    final query = _searchQuery.toLowerCase();

    setState(() {
      _filteredInventory.clear();

      _filteredInventory.addAll(_inventory.where((item) {
        // Búsqueda
        final matchesSearch = query.isEmpty ||
            item['nombre_producto']
                ?.toString()
                .toLowerCase()
                .contains(query) ==
                true ||
            item['descripcion']?.toString().toLowerCase().contains(query) ==
                true ||
            item['lugar_fisico']?.toString().toLowerCase().contains(query) ==
                true;

        // Filtro de estado
        final matchesFilter = _selectedFilter == 'all' ||
            (_selectedFilter == 'low_stock' &&
                item['stock_status'] == 'low_stock') ||
            (_selectedFilter == 'out_of_stock' &&
                item['stock_status'] == 'out_of_stock') ||
            (_selectedFilter == 'normal' && item['stock_status'] == 'normal');

        return matchesSearch && matchesFilter;
      }));
    });
  }

  /// Búsqueda con debounce
  void _onSearchChanged(String value) {
    setState(() => _searchQuery = value);

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchQuery.length >= 2) {
        _performSearch();
      } else if (_searchQuery.isEmpty) {
        _applyLocalFilter();
      }
    });
  }

  /// Búsqueda en servidor
  Future<void> _performSearch() async {
    try {
      final result = await InventoryServiceOptimized.searchInventoryPaged(
        searchText: _searchQuery,
        page: 0,
      );

      if (mounted) {
        setState(() {
          _filteredInventory.clear();
          _filteredInventory.addAll(result['items'] as List<Map<String, dynamic>>);
        });
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda: $e');
    }
  }

  /// Cambiar filtro
  void _changeFilter(String filter) {
    setState(() {
      _selectedFilter = filter;
      _searchQuery = '';
      _searchController.clear();
    });

    if (filter == 'all') {
      _applyLocalFilter();
    } else {
      _loadFilteredProducts(filter);
    }
  }

  /// Cargar productos filtrados del servidor
  Future<void> _loadFilteredProducts(String filter) async {
    try {
      setState(() {
        _isInitialLoading = true;
        _filteredInventory.clear();
      });

      final result = await InventoryServiceOptimized.getInventoryPaginated(
        filter: filter,
        page: 0,
      );

      if (mounted) {
        setState(() {
          _filteredInventory.addAll(result['items'] as List<Map<String, dynamic>>);
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
        if (kDebugMode) print('Error en filtro: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/inventory',
      child: Scaffold(
        appBar: _buildAppBar(),
        floatingActionButton: _buildFloatingCartButton(),
        body: RefreshIndicator(
          onRefresh: () async {
            InventoryServiceOptimized.invalidateCache();
            await _loadInitialData();
          },
          child: Column(
            children: [
              _buildSearchBar(),
              const SizedBox(height: 16),
              _buildFilterChips(),
              const SizedBox(height: 16),
              Expanded(child: _buildInventoryList()),
            ],
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Inventory',
        style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0),
      ),
      backgroundColor: const Color(0xFF2B5F8C),
      foregroundColor: Colors.white,
      elevation: 2,
      leading: const SizedBox.shrink(),
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: () {
            // _showScanner(); // Implementar
          },
          tooltip: 'Scan Code',
        ),
        _buildCartAppBarButton(),
        if (_canEdit)
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // _showAddItemDialog(); // Implementar
            },
          ),
      ],
    );
  }

  Widget _buildCartAppBarButton() {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ShoppingCartScreen(),
            ),
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
                _cartService.totalItems > 99
                    ? '99+'
                    : _cartService.totalItems.toString(),
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

  Widget _buildSearchBar() {
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
    final filters = [
      {
        'key': 'all',
        'label': 'ALL',
        'count': _filterCounts['all'] ?? _inventory.length
      },
      {
        'key': 'normal',
        'label': 'Normal',
        'count': _filterCounts['normal'] ?? 0
      },
      {
        'key': 'low_stock',
        'label': 'Low Stock',
        'count': _filterCounts['low_stock'] ?? 0
      },
      {
        'key': 'out_of_stock',
        'label': 'Out of Stock',
        'count': _filterCounts['out_of_stock'] ?? 0
      },
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];
          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(
                '${filter['label']} (${filter['count']})',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2B5F8C),
                  fontWeight:
                  isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) => _changeFilter(filter['key'] as String),
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF6B8E3D),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF6B8E3D)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInventoryList() {
    if (_isInitialLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6B8E3D)),
            SizedBox(height: 16),
            Text('Loading products...', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    if (_filteredInventory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: _filteredInventory.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Mostrar indicador de carga al final
        if (index == _filteredInventory.length) {
          return _buildLoadingIndicator();
        }

        final item = _filteredInventory[index];
        return _buildInventoryCard(item, index);
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      alignment: Alignment.center,
      child: const CircularProgressIndicator(
        color: Color(0xFF6B8E3D),
        strokeWidth: 2,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off
                : Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No products found'
                : 'No products in inventory',
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
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item, int index) {
    final stockStatus = item['stock_status'] ?? 'normal';
    final cantidad = item['cantidad'] ?? 0;
    final imageUrl = item['image_url'];
    final isLowStock = stockStatus == 'low_stock';

    // Cargar ubicaciones cuando la card es visible
    if (item['_ubicaciones_loaded'] != true) {
      Future.microtask(() => _loadProductLocations(
        item['id_inventario'],
        index,
      ));
    }

    Color colorFromHex(String hex) =>
        Color(int.parse(hex.replaceFirst('#', '0xFF')));

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (imageUrl != null)
                  Container(
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
                                color: colorFromHex(
                                  InventoryService.getStockStatusColor(
                                    stockStatus,
                                  ),
                                ),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: colorFromHex(
                                InventoryService.getStockStatusColor(
                                  stockStatus,
                                ),
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              InventoryService.getStockStatusText(stockStatus),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: colorFromHex(
                                  InventoryService.getStockStatusColor(
                                    stockStatus,
                                  ),
                                ),
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

            // Ubicaciones (lazy loaded)
            if (item['ubicaciones'] != null &&
                (item['ubicaciones'] as List).isNotEmpty)
              _buildLocationInfo(item['ubicaciones']),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationInfo(List ubicaciones) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3E8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF6B8E3D).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, size: 14, color: Color(0xFF6B8E3D)),
              const SizedBox(width: 6),
              Text(
                '${ubicaciones.length} location${ubicaciones.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B8E3D),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
          child: const Icon(Icons.broken_image, color: Colors.grey),
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.grey.shade200,
            child: const Icon(Icons.image_not_supported, color: Colors.grey),
          );
        },
      );
    }
  }

  FloatingActionButton _buildFloatingCartButton() {
    final itemCount = _cartService.totalItems;

    if (itemCount == 0) {
      return FloatingActionButton.extended(
        onPressed: _canEdit ? null : null, // _showAddItemDialog
        backgroundColor: _canEdit ? const Color(0xFF6B8E3D) : Colors.grey,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      );
    }

    return FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const ShoppingCartScreen(),
        ),
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}