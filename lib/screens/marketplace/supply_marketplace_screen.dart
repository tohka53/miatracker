import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supply_marketplace_service.dart';
import '../../widgets/collapsible_drawer.dart';
import 'dart:io'; // ✅ AGREGAR al inicio del archivo
import '/widgets/product_image_widget.dart'; // ← AGREGAR al inicio


/// Pantalla principal del Marketplace de Proveedores
class SupplyMarketplaceScreen extends StatefulWidget {
  const SupplyMarketplaceScreen({super.key});

  @override
  State<SupplyMarketplaceScreen> createState() => _SupplyMarketplaceScreenState();
}

// ✅ AGREGADO: SingleTickerProviderStateMixin para TabController
class _SupplyMarketplaceScreenState extends State<SupplyMarketplaceScreen>
    with SingleTickerProviderStateMixin {
  // ✅ AGREGADO: TabController
  late TabController _tabController;

  List<Map<String, dynamic>> _suppliers = [];
  List<Map<String, dynamic>> _myImportedProducts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // ✅ AGREGADO: Inicializar TabController
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    // ✅ AGREGADO: Dispose del TabController
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final suppliers = await SupplyMarketplaceService.getPublicSuppliers();
      final imported = await SupplyMarketplaceService.getMyImportedProducts();

      if (mounted) {
        setState(() {
          _suppliers = suppliers;
          _myImportedProducts = imported;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/marketplace',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          leading: const SizedBox.shrink(), // Oculta el botón back
          title: const Text(
            'Supplier Marketplace',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadData,
              tooltip: 'Refresh',
            ),
          ],
          // ✅ CORREGIDO: Agregado controller al TabBar
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(icon: Icon(Icons.store), text: 'Suppliers'),
              Tab(icon: Icon(Icons.inventory), text: 'My Products'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
        )
        // ✅ CORREGIDO: Agregado controller al TabBarView
            : TabBarView(
          controller: _tabController,
          children: [
            _buildSuppliersTab(),
            _buildMyProductsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSuppliersTab() {
    if (_suppliers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.store_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'No suppliers available',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('Recargar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF6B8E3D),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _suppliers.length,
        itemBuilder: (context, index) => _buildSupplierCard(_suppliers[index]),
      ),
    );
  }

  Widget _buildSupplierCard(Map<String, dynamic> supplier) {
    final rating = supplier['rating'] ?? 0.0;
    final reviews = supplier['total_reviews'] ?? 0;
    final totalProducts = supplier['total_products'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _openSupplierCatalog(supplier),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2B5F8C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.store,
                      color: Color(0xFF2B5F8C),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplier['name'] ?? 'No name',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.star, size: 16, color: Colors.amber),
                            const SizedBox(width: 4),
                            Text(
                              '${rating.toStringAsFixed(1)} ($reviews)',
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.inventory_2,
                                size: 16, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              '$totalProducts productos',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (supplier['description'] != null &&
                  supplier['description'].toString().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  supplier['description'],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openSupplierCatalog(supplier),
                    icon: const Icon(Icons.arrow_forward, size: 18),
                    label: const Text('View Catalog'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF6B8E3D),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyProductsTab() {
    if (_myImportedProducts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              'You have not imported products yet',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Explora los proveedores y agrega productos',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0), // Ir a tab de proveedores
              icon: const Icon(Icons.store),
              label: const Text('Browse Suppliers'),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      color: const Color(0xFF6B8E3D),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _myImportedProducts.length,
        itemBuilder: (context, index) =>
            _buildMyProductCard(_myImportedProducts[index]),
      ),
    );
  }

  Widget _buildMyProductCard(Map<String, dynamic> product) {
    final imageUrl = product['imagen'];
    final price = (product['precio'] ?? 0.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null && imageUrl.toString().isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: 60,
                height: 60,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  width: 60,
                  height: 60,
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.image_not_supported),
                ),
              )
                  : Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                child: const Icon(Icons.inventory_2, size: 30),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['nombre_producto'] ?? 'No name',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B8E3D),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                Text(
                  'Stock: ${product['cantidad'] ?? 0}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B5F8C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Total: ${product['total_comprado'] ?? 0}',
                    style: const TextStyle(fontSize: 9, color: Color(0xFF2B5F8C)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSupplierCatalog(Map<String, dynamic> supplier) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SupplierCatalogScreen(supplier: supplier),
      ),
    ).then((_) => _loadData());
  }
}

/// Pantalla del Catálogo de un Proveedor
class SupplierCatalogScreen extends StatefulWidget {
  final Map<String, dynamic> supplier;

  const SupplierCatalogScreen({super.key, required this.supplier});

  @override
  State<SupplierCatalogScreen> createState() => _SupplierCatalogScreenState();
}

class _SupplierCatalogScreenState extends State<SupplierCatalogScreen> {
  List<Map<String, dynamic>> _products = [];
  List<String> _categories = [];
  String? _selectedCategory;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() => _isLoading = true);
    try {
      final supplierId = widget.supplier['id'] as int;
      final products =
      await SupplyMarketplaceService.getSupplierCatalog(supplierId);
      final categories =
      await SupplyMarketplaceService.getSupplierCategories(supplierId);

      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _filterByCategory(String? category) {
    setState(() => _selectedCategory = category);
  }

  List<Map<String, dynamic>> get _filteredProducts {
    if (_selectedCategory == null) return _products;
    return _products
        .where((p) => p['categoria'] == _selectedCategory)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E8),
      appBar: AppBar(
        title: Text(widget.supplier['name'] ?? 'Catalog'),
        backgroundColor: const Color(0xFF2B5F8C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
      )
          : Column(
        children: [
          if (_categories.isNotEmpty) _buildCategoryFilter(),
          Expanded(
            child: _filteredProducts.isEmpty
                ? _buildEmptyState()
                : _buildProductGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildCategoryChip('All', null),
          ..._categories.map((cat) => _buildCategoryChip(cat, cat)),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? value) {
    final isSelected = _selectedCategory == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => _filterByCategory(value),
        backgroundColor: Colors.grey.shade200,
        selectedColor: const Color(0xFF6B8E3D),
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No products available',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
  Widget _buildProductGrid() {
    return RefreshIndicator(
      onRefresh: _loadCatalog,
      color: const Color(0xFF6B8E3D),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, // ✅ AUMENTADO: 3 columnas en lugar de 2
          childAspectRatio: 1.4, // ✅ AJUSTADO: Más compacto verticalmente
          crossAxisSpacing: 10, // ✅ REDUCIDO: Menos espacio entre productos
          mainAxisSpacing: 10, // ✅ REDUCIDO: Menos espacio vertical
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) =>
            _buildProductCard(_filteredProducts[index]),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    // 🔥 CORREGIDO: Extraer URL de imagen correctamente
    final imagenData = product['imagen'];
    String? imageUrl;

    // Si 'imagen' es un String directo (URL)
    if (imagenData is String) {
      imageUrl = imagenData;
    }
    // Si 'imagen' es un objeto JSON con estructura
    else if (imagenData is Map) {
      imageUrl = imagenData['url'] ??
          imagenData['public_url'] ??
          imagenData['path'] ??
          imagenData['imagen'] ??
          imagenData['image_url'];
          imageUrl = imagenData['url'] ?? imagenData['image_url'];

    }

    final price = (product['precio_base'] ?? 0.0) is double
        ? product['precio_base']
        : double.tryParse(product['precio_base'].toString()) ?? 0.0;
    final stock = product['stock_disponible'] ?? 0;
    final nombreProducto = product['nombre_producto'] ?? 'No name';

    // 🔍 DEBUG - Quitar después de verificar
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('📦 Product: $nombreProducto');
    debugPrint('📊 Tipo de imagen: ${imagenData.runtimeType}');
    debugPrint('📊 Datos de imagen: $imagenData');
    debugPrint('🖼️ Extracted URL: $imageUrl');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: InkWell(
        onTap: () => _showProductDetails(product),
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ Imagen con altura FIJA (igual que inventario)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
              child: ProductImageWidget(
                imageData: imagenData, // ← Pasa el dato tal cual viene de la BD
                height: 80,
                fit: BoxFit.cover,
                errorWidget: Container(
                  height: 80,
                  color: Colors.grey.shade300,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inventory_2, size: 28, color: Colors.grey),
                      SizedBox(height: 4),
                      Text('No image', style: TextStyle(fontSize: 8, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
            ),
            // ✅ Información del producto
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nombreProducto,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B8E3D),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    stock > 0 ? 'Stock: $stock' : 'Out of stock',
                    style: TextStyle(
                      fontSize: 8,
                      color: stock > 0 ? Colors.green.shade700 : Colors.red.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ AGREGAR: Misma función que usa el inventario para cargar imágenes
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
        errorWidget: (context, url, error) {
          debugPrint('❌ Error cargando imagen: $url');
          debugPrint('❌ Error: $error');

          return Container(
            color: Colors.grey.shade200,
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 30, color: Colors.grey),
                SizedBox(height: 4),
                Text(
                  'Error',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        },
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
                Icon(Icons.image_not_supported, size: 30, color: Colors.grey),
                SizedBox(height: 4),
                Text(
                  'No disponible',
                  style: TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          );
        },
      );
    }
  }

  void _showProductDetails(Map<String, dynamic> product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  product['nombre'] ?? 'No name',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '\$${(product['precio'] ?? 0.0).toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B8E3D),
                  ),
                ),
                const SizedBox(height: 20),
                if (product['descripcion'] != null &&
                    product['descripcion'].toString().isNotEmpty) ...[
                  const Text(
                    'Description:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product['descripcion'],
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    const Icon(Icons.inventory_2,
                        size: 20, color: Color(0xFF2B5F8C)),
                    const SizedBox(width: 8),
                    Text(
                      'Stock disponible: ${product['stock_disponible'] ?? 0}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      // TODO: Agregar al carrito del marketplace
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Product added to cart'),
                          backgroundColor: Color(0xFF6B8E3D),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Add to Cart'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}