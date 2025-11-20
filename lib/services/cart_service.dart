import 'package:flutter/foundation.dart';

class CartService extends ChangeNotifier {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  final List<CartItem> _items = [];
  final List<Map<String, dynamic>> _inventory = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalItems => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalAmount => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  // Actualizar inventario disponible
  void updateInventory(List<Map<String, dynamic>> inventory) {
    _inventory.clear();
    _inventory.addAll(inventory);

    // Validar items existentes en el carrito
    _validateCartItems();
    notifyListeners();
  }

  // Obtener stock disponible de un producto
  int getAvailableStock(int productId) {
    final product = _inventory.firstWhere(
          (item) => item['id_inventario'] == productId,
      orElse: () => {},
    );

    if (product.isEmpty) return 0;

    final currentStock = product['cantidad'] ?? 0;
    final cartQuantity = getCartQuantity(productId);

    return currentStock - cartQuantity;
  }

  // Obtener cantidad actual en el carrito
  int getCartQuantity(int productId) {
    final cartItem = _items.firstWhere(
          (item) => item.productId == productId,
      orElse: () => const CartItem(
        productId: 0,
        name: '',
        price: 0.0,
        quantity: 0,
        imageUrl: null,
      ),
    );

    return cartItem.productId == 0 ? 0 : cartItem.quantity;
  }

  bool addToCart(Map<String, dynamic> product, {int quantity = 1}) {
    try {
      final productId = product['id_inventario'] as int;
      final productName = product['nombre_producto'] ?? 'Producto sin nombre';
      final currentStock = product['cantidad'] ?? 0;
      final imageUrl = product['image_url'];

      // Buscar si ya existe en el carrito
      final existingIndex = _items.indexWhere((item) => item.productId == productId);

      int newQuantity = quantity;
      if (existingIndex != -1) {
        newQuantity = _items[existingIndex].quantity + quantity;
      }

      // Validar stock disponible
      if (newQuantity > currentStock) {
        if (kDebugMode) {
          print('❌ Stock insuficiente para $productName. Stock: $currentStock, Solicitado: $newQuantity');
        }
        return false;
      }

      // Obtener precio real desde la BD
      final price = _getEstimatedPrice(product);

      if (kDebugMode) {
        if (price == 0.0) {
          print('⚠️ Agregado al carrito SIN PRECIO: $productName x$quantity');
        } else {
          print('✅ Agregado al carrito: $productName x$quantity a \$${price.toStringAsFixed(2)} c/u');
        }
      }

      if (existingIndex != -1) {
        // Actualizar cantidad existente
        _items[existingIndex] = CartItem(
          productId: productId,
          name: productName,
          price: price,
          quantity: newQuantity,
          imageUrl: imageUrl,
          description: _getProductDescription(product),
        );
      } else {
        // Agregar nuevo item
        _items.add(CartItem(
          productId: productId,
          name: productName,
          price: price,
          quantity: quantity,
          imageUrl: imageUrl,
          description: _getProductDescription(product),
        ));
      }

      notifyListeners();

      if (kDebugMode) {
        print('✅ Agregado al carrito: $productName x$quantity a \$${price.toStringAsFixed(2)} c/u');
      }

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error agregando al carrito: $e');
      }
      return false;
    }
  }

  // Remover producto del carrito
  void removeFromCart(int productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  // Actualizar cantidad de un producto
  bool updateQuantity(int productId, int newQuantity) {
    try {
      if (newQuantity <= 0) {
        removeFromCart(productId);
        return true;
      }

      final product = _inventory.firstWhere(
            (item) => item['id_inventario'] == productId,
        orElse: () => {},
      );

      if (product.isEmpty) return false;

      final currentStock = product['cantidad'] ?? 0;

      if (newQuantity > currentStock) {
        if (kDebugMode) {
          print('❌ Stock insuficiente. Stock: $currentStock, Solicitado: $newQuantity');
        }
        return false;
      }

      final index = _items.indexWhere((item) => item.productId == productId);
      if (index != -1) {
        _items[index] = _items[index].copyWith(quantity: newQuantity);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error actualizando cantidad: $e');
      }
      return false;
    }
  }

  // Limpiar carrito
  void clearCart() {
    _items.clear();
    notifyListeners();
  }

  // Validar items del carrito contra inventario actual
  void _validateCartItems() {
    final itemsToRemove = <CartItem>[];

    for (final cartItem in _items) {
      final product = _inventory.firstWhere(
            (item) => item['id_inventario'] == cartItem.productId,
        orElse: () => {},
      );

      if (product.isEmpty) {
        // Producto ya no existe
        itemsToRemove.add(cartItem);
        continue;
      }

      final currentStock = product['cantidad'] ?? 0;

      if (cartItem.quantity > currentStock) {
        if (currentStock > 0) {
          // Ajustar cantidad al stock disponible
          final index = _items.indexOf(cartItem);
          _items[index] = cartItem.copyWith(quantity: currentStock);
        } else {
          // Sin stock, remover del carrito
          itemsToRemove.add(cartItem);
        }
      }
    }

    // Remover items no válidos
    for (final item in itemsToRemove) {
      _items.remove(item);
    }
  }

  // Obtener precio real del producto desde la base de datos
  double _getEstimatedPrice(Map<String, dynamic> product) {
    // Intentar obtener precio de la base de datos
    final precio = product['precio'];

    if (precio != null) {
      if (precio is num) {
        return precio.toDouble();
      } else if (precio is String) {
        return double.tryParse(precio) ?? 0.0;
      }
    }

    // Si no hay precio en la BD, retornar 0.0
    if (kDebugMode) {
      print('⚠️ Producto sin precio: ${product['nombre_producto']}');
    }
    return 0.0;
  }



  // Obtener descripción del producto
  String _getProductDescription(Map<String, dynamic> product) {
    final description = product['descripcion'];
    if (description == null) return '';

    if (description is Map<String, dynamic>) {
      return description.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' • ');
    }

    return description.toString();
  }

  // Verificar si se puede procesar el pedido
  bool canProcessOrder() {
    if (_items.isEmpty) return false;

    for (final cartItem in _items) {
      final availableStock = getAvailableStock(cartItem.productId);
      if (cartItem.quantity > availableStock) {
        return false;
      }
    }

    return true;
  }

  // Obtener resumen del pedido
  Map<String, dynamic> getOrderSummary() {
    return {
      'items': _items.map((item) => item.toMap()).toList(),
      'total_items': totalItems,
      'total_amount': totalAmount,
      'can_process': canProcessOrder(),
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  // Agregar al final de la clase CartService

// Procesar pedido y actualizar inventario
  Future<Map<String, dynamic>> processOrderAndUpdateStock() async {
    if (!canProcessOrder()) {
      throw Exception('No se puede procesar el pedido. Verifica el stock disponible.');
    }

    try {
      final orderSummary = getOrderSummary();
      final List<Map<String, dynamic>> stockUpdates = [];

      // Preparar actualizaciones de stock
      for (final item in _items) {
        final product = _inventory.firstWhere(
              (p) => p['id_inventario'] == item.productId,
          orElse: () => {},
        );

        if (product.isEmpty) {
          throw Exception('Producto ${item.name} no encontrado en inventario');
        }

        final currentStock = product['cantidad'] ?? 0;
        final newStock = currentStock - item.quantity;

        if (newStock < 0) {
          throw Exception('Stock insuficiente para ${item.name}');
        }

        stockUpdates.add({
          'id_inventario': item.productId,
          'cantidad': newStock,
        });
      }

      // Retornar datos para procesamiento
      return {
        'order_summary': orderSummary,
        'stock_updates': stockUpdates,
        'success': true,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando pedido: $e');
      }
      rethrow;
    }
  }




}

class CartItem {
  final int productId;
  final String name;
  final double price;
  final int quantity;
  final String? imageUrl;
  final String? description;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.quantity,
    this.imageUrl,
    this.description,
  });

  double get totalPrice => price * quantity;

  CartItem copyWith({
    int? productId,
    String? name,
    double? price,
    int? quantity,
    String? imageUrl,
    String? description,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'quantity': quantity,
      'total_price': totalPrice,
      'image_url': imageUrl,
      'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CartItem && other.productId == productId;
  }

  @override
  int get hashCode => productId.hashCode;

  @override
  String toString() {
    return 'CartItem(productId: $productId, name: $name, quantity: $quantity, price: $price)';
  }
}