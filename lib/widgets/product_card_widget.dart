import 'package:flutter/material.dart';

/// Widget reutilizable para mostrar un producto del marketplace
/// Puede usarse en grids, listas y detalles
class ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onFavorite;
  final bool isFavorite;
  final bool showSupplier;
  final bool compact;

  const ProductCard({
    super.key,
    required this.product,
    this.onTap,
    this.onAddToCart,
    this.onFavorite,
    this.isFavorite = false,
    this.showSupplier = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return compact ? _buildCompactCard(context) : _buildFullCard(context);
  }

  Widget _buildFullCard(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  _buildProductImage(),
                  if (onFavorite != null) _buildFavoriteButton(),
                  _buildStockBadge(),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? product['nombre'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (showSupplier) _buildSupplierInfo(),
                    const Spacer(),
                    _buildPriceAndCart(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactCard(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildProductThumbnail(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['name'] ?? product['nombre'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (showSupplier) _buildSupplierInfo(),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          '\$${_getPrice().toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B8E3D),
                          ),
                        ),
                        const Spacer(),
                        if (onAddToCart != null)
                          IconButton(
                            icon: const Icon(Icons.add_shopping_cart, size: 20),
                            onPressed: onAddToCart,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage() {
    final imageUrl = product['image_url'] ?? product['imagen'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
        child: imageUrl != null && imageUrl.toString().isNotEmpty
            ? Image.network(
          imageUrl.toString(),
          width: double.infinity,
          height: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
              ),
            );
          },
        )
            : _buildPlaceholderImage(),
      ),
    );
  }

  Widget _buildProductThumbnail() {
    final imageUrl = product['image_url'] ?? product['imagen'];

    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageUrl != null && imageUrl.toString().isNotEmpty
            ? Image.network(
          imageUrl.toString(),
          width: 80,
          height: 80,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              Icon(Icons.inventory_2, size: 40, color: Colors.grey[400]),
        )
            : Icon(Icons.inventory_2, size: 40, color: Colors.grey[400]),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Icon(
        Icons.inventory_2,
        size: 64,
        color: Colors.grey[400],
      ),
    );
  }

  Widget _buildFavoriteButton() {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: Icon(
            isFavorite ? Icons.favorite : Icons.favorite_border,
            color: isFavorite ? Colors.red : Colors.grey[700],
            size: 20,
          ),
          onPressed: onFavorite,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  Widget _buildStockBadge() {
    final stock = product['stock_quantity'] ?? product['cantidad'] ?? 0;

    if (stock <= 0) {
      return Positioned(
        top: 8,
        left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Agotado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else if (stock <= 5) {
      return Positioned(
        top: 8,
        left: 8,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Solo $stock',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSupplierInfo() {
    final supplierName = product['supplier']?['company_name'] ??
        product['proveedor_nombre'] ??
        'Proveedor';
    final rating = product['supplier']?['supplier_rating'] ?? 0.0;

    return Row(
      children: [
        Icon(Icons.store, size: 12, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            supplierName.toString(),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (rating > 0) ...[
          const SizedBox(width: 4),
          Icon(Icons.star, size: 12, color: Colors.amber[700]),
          const SizedBox(width: 2),
          Text(
            rating.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPriceAndCart(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '\$${_getPrice().toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B8E3D),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (onAddToCart != null)
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF6B8E3D),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.add_shopping_cart),
              iconSize: 18,
              color: Colors.white,
              onPressed: onAddToCart,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(),
            ),
          ),
      ],
    );
  }

  double _getPrice() {
    return (product['price'] ?? product['precio'] ?? 0.0).toDouble();
  }
}

/// Widget para mostrar una lista horizontal de productos
class ProductHorizontalList extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final String title;
  final VoidCallback? onSeeAll;
  final Function(Map<String, dynamic>)? onProductTap;
  final Function(Map<String, dynamic>)? onAddToCart;

  const ProductHorizontalList({
    super.key,
    required this.products,
    required this.title,
    this.onSeeAll,
    this.onProductTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (onSeeAll != null)
                TextButton(
                  onPressed: onSeeAll,
                  child: const Text('Ver todos'),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 240,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Container(
                width: 160,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: ProductCard(
                  product: product,
                  onTap: () => onProductTap?.call(product),
                  onAddToCart: () => onAddToCart?.call(product),
                  showSupplier: true,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Widget para mostrar un grid de productos
class ProductGrid extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>)? onProductTap;
  final Function(Map<String, dynamic>)? onAddToCart;
  final int crossAxisCount;

  const ProductGrid({
    super.key,
    required this.products,
    this.onProductTap,
    this.onAddToCart,
    this.crossAxisCount = 2,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.7,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          onTap: () => onProductTap?.call(product),
          onAddToCart: () => onAddToCart?.call(product),
        );
      },
    );
  }
}

/// Widget para mostrar una lista vertical compacta de productos
class ProductListView extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>)? onProductTap;
  final Function(Map<String, dynamic>)? onAddToCart;

  const ProductListView({
    super.key,
    required this.products,
    this.onProductTap,
    this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No se encontraron productos',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard(
          product: product,
          compact: true,
          onTap: () => onProductTap?.call(product),
          onAddToCart: () => onAddToCart?.call(product),
        );
      },
    );
  }
}