import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/supply_marketplace_service.dart';
import '../../widgets/collapsible_drawer.dart';

/// Pantalla del Catálogo de un Proveedor - ⚡ VERSIÓN CORREGIDA
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
      // 🔥 Obtener el ID correcto del proveedor
      final supplierId = widget.supplier['id'] as int;

      debugPrint('🔍 Cargando catálogo del proveedor: $supplierId');
      debugPrint('📦 Nombre del proveedor: ${widget.supplier['name']}');

      // Cargar productos
      final products = await SupplyMarketplaceService.getSupplierCatalog(supplierId);

      debugPrint('✅ Productos cargados: ${products.length}');
      if (products.isNotEmpty) {
        debugPrint('📦 Primer producto: ${products[0]}');
      }

      // Cargar categorías
      final categories = await SupplyMarketplaceService.getSupplierCategories(supplierId);

      debugPrint('🏷️ Categorías encontradas: $categories');

      if (mounted) {
        setState(() {
          _products = products;
          _categories = categories;
          _isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error cargando catálogo: $e');
      debugPrint('🔍 Stack trace: $stackTrace');

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _loadCatalog,
            ),
          ),
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.supplier['name'] ?? 'Catálogo',
              style: const TextStyle(fontSize: 18),
            ),
            if (!_isLoading)
              Text(
                '${_filteredProducts.length} productos',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
              ),
          ],
        ),
        backgroundColor: const Color(0xFF2B5F8C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCatalog,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6B8E3D)),
            SizedBox(height: 16),
            Text('Cargando productos...'),
          ],
        ),
      )
          : Column(
        children: [
          // Filtro de categorías
          if (_categories.isNotEmpty) _buildCategoryFilter(),

          // Lista de productos
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
          _buildCategoryChip('Todos', null),
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
            _selectedCategory != null
                ? 'No hay productos en esta categoría'
                : 'No hay productos disponibles',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            'Este proveedor aún no ha publicado productos',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
          if (_selectedCategory != null) ...[
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => _filterByCategory(null),
              icon: const Icon(Icons.clear),
              label: const Text('Ver todos'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B8E3D),
              ),
            ),
          ],
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
          crossAxisCount: 2,
          childAspectRatio: 0.75,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _filteredProducts.length,
        itemBuilder: (context, index) =>
            _buildProductCard(_filteredProducts[index]),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    // 🔥 Usar el nombre correcto de la columna
    final imageUrl = product['imagen'];
    final price = (product['precio_base'] ?? 0.0) is double
        ? product['precio_base']
        : double.tryParse(product['precio_base'].toString()) ?? 0.0;
    final stock = product['stock_disponible'] ?? 0;
    final nombreProducto = product['nombre_producto'] ?? 'Sin nombre';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showProductDetails(product),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen del producto
            Expanded(
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(12)),
                child: imageUrl != null && imageUrl.toString().isNotEmpty
                    ? CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.grey.shade200,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image_not_supported, size: 40),
                  ),
                )
                    : Container(
                  color: Colors.grey.shade200,
                  child: const Center(
                    child: Icon(Icons.inventory_2, size: 40),
                  ),
                ),
              ),
            ),
            // Información del producto
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nombreProducto,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Q ${price.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B8E3D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        stock > 0 ? Icons.check_circle : Icons.cancel,
                        size: 12,
                        color: stock > 0 ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stock > 0 ? 'Stock: $stock' : 'Sin stock',
                        style: TextStyle(
                          fontSize: 11,
                          color: stock > 0 ? Colors.green : Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProductDetails(Map<String, dynamic> product) {
    final price = (product['precio_base'] ?? 0.0) is double
        ? product['precio_base']
        : double.tryParse(product['precio_base'].toString()) ?? 0.0;
    final nombreProducto = product['nombre_producto'] ?? 'Sin nombre';
    final descripcion = product['descripcion'] ?? '';
    final stock = product['stock_disponible'] ?? 0;
    final categoria = product['categoria'];
    final marca = product['marca'];

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
                // Handle
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

                // Nombre del producto
                Text(
                  nombreProducto,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Precio
                Text(
                  'Q ${price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B8E3D),
                  ),
                ),
                const SizedBox(height: 20),

                // Información adicional
                if (categoria != null && categoria.toString().isNotEmpty)
                  _buildInfoRow(Icons.category, 'Categoría', categoria),
                if (marca != null && marca.toString().isNotEmpty)
                  _buildInfoRow(Icons.branding_watermark, 'Marca', marca),
                _buildInfoRow(
                  Icons.inventory_2,
                  'Stock disponible',
                  stock > 0 ? '$stock unidades' : 'Sin stock',
                  textColor: stock > 0 ? Colors.green : Colors.red,
                ),

                // Descripción
                if (descripcion.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Descripción:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    descripcion,
                    style: const TextStyle(fontSize: 14),
                  ),
                ],

                const SizedBox(height: 30),

                // Botón Agregar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: stock > 0
                        ? () async {
                      Navigator.pop(context);
                      await _addToInventory(product);
                    }
                        : null,
                    icon: const Icon(Icons.add_shopping_cart),
                    label: const Text('Agregar a Mi Inventario'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
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

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
                    color: Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addToInventory(Map<String, dynamic> product) async {
    try {
      final productId = product['id_supply_product'] as int;
      final success = await SupplyMarketplaceService.addProductToMyInventory(productId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? '✅ Producto agregado a tu inventario'
                  : '❌ Error al agregar producto',
            ),
            backgroundColor: success ? const Color(0xFF6B8E3D) : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}