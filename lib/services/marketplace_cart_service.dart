import 'package:flutter/foundation.dart';

/// Servicio para gestionar el carrito de compras del marketplace
class MarketplaceCartService extends ChangeNotifier {
  // Singleton
  static final MarketplaceCartService _instance = MarketplaceCartService._internal();
  factory MarketplaceCartService() => _instance;
  MarketplaceCartService._internal();

  // Estructura: supplierId -> List<CartItem>
  final Map<int, List<CartItem>> _cartsBySupplier = {};

  /// Obtener todos los items del carrito agrupados por proveedor
  Map<int, List<CartItem>> get cartsBySupplier => Map.unmodifiable(_cartsBySupplier);

  /// Obtener total de items en el carrito
  int get totalItems {
    return _cartsBySupplier.values
        .fold(0, (sum, items) => sum + items.fold(0, (s, item) => s + item.cantidad));
  }

  /// Obtener total general del carrito
  double get totalAmount {
    return _cartsBySupplier.values.fold(
      0.0,
          (sum, items) => sum + items.fold(0.0, (s, item) => s + item.subtotal),
    );
  }

  /// Obtener items de un proveedor específico
  List<CartItem> getSupplierItems(int supplierId) {
    return List.unmodifiable(_cartsBySupplier[supplierId] ?? []);
  }

  /// Obtener total de un proveedor
  double getSupplierTotal(int supplierId) {
    final items = _cartsBySupplier[supplierId] ?? [];
    return items.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Obtener cantidad de items de un proveedor
  int getSupplierItemCount(int supplierId) {
    final items = _cartsBySupplier[supplierId] ?? [];
    return items.fold(0, (sum, item) => sum + item.cantidad);
  }

  /// Agregar producto al carrito
  bool addToCart(
      Map<String, dynamic> product,
      Map<String, dynamic> supplier, {
        int cantidad = 1,
      }) {
    try {
      final supplierId = supplier['id'] as int;
      final productId = product['id_supply_product'] as int;
      final cantidadMinima = product['cantidad_minima'] ?? 1;

      // Validar cantidad mínima
      if (cantidad < cantidadMinima) {
        if (kDebugMode) print('Cantidad menor a la mínima: $cantidadMinima');
        return false;
      }

      // Validar stock disponible
      final stockDisponible = product['stock_disponible'] ?? 0;
      if (stockDisponible > 0 && cantidad > stockDisponible) {
        if (kDebugMode) print('Cantidad mayor al stock disponible');
        return false;
      }

      // Inicializar lista del proveedor si no existe
      _cartsBySupplier.putIfAbsent(supplierId, () => []);

      // Buscar si el producto ya está en el carrito
      final existingIndex = _cartsBySupplier[supplierId]!
          .indexWhere((item) => item.productId == productId);

      if (existingIndex != -1) {
        // Actualizar cantidad
        final currentItem = _cartsBySupplier[supplierId]![existingIndex];
        final newCantidad = currentItem.cantidad + cantidad;

        // Validar nuevo total contra stock
        if (stockDisponible > 0 && newCantidad > stockDisponible) {
          if (kDebugMode) print('Total excede stock disponible');
          return false;
        }

        _cartsBySupplier[supplierId]![existingIndex] = currentItem.copyWith(
          cantidad: newCantidad,
        );
      } else {
        // Agregar nuevo item
        _cartsBySupplier[supplierId]!.add(
          CartItem(
            productId: productId,
            supplierId: supplierId,
            supplierName: supplier['name'] ?? 'Sin nombre',
            nombreProducto: product['nombre_producto'] ?? 'Sin nombre',
            precioUnitario: _getPrice(product),
            cantidad: cantidad,
            imagen: product['imagen'],
            unidadMedida: product['unidad_medida'] ?? 'unidad',
            cantidadMinima: cantidadMinima,
            stockDisponible: stockDisponible,
          ),
        );
      }

      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error agregando al carrito: $e');
      return false;
    }
  }

  /// Actualizar cantidad de un producto
  bool updateQuantity(int supplierId, int productId, int newCantidad) {
    try {
      final items = _cartsBySupplier[supplierId];
      if (items == null) return false;

      final index = items.indexWhere((item) => item.productId == productId);
      if (index == -1) return false;

      final item = items[index];

      // Validar cantidad mínima
      if (newCantidad < item.cantidadMinima) {
        if (kDebugMode) print('Cantidad menor a la mínima');
        return false;
      }

      // Validar stock
      if (item.stockDisponible > 0 && newCantidad > item.stockDisponible) {
        if (kDebugMode) print('Cantidad mayor al stock');
        return false;
      }

      items[index] = item.copyWith(cantidad: newCantidad);
      notifyListeners();
      return true;
    } catch (e) {
      if (kDebugMode) print('Error actualizando cantidad: $e');
      return false;
    }
  }

  /// Remover producto del carrito
  void removeFromCart(int supplierId, int productId) {
    final items = _cartsBySupplier[supplierId];
    if (items == null) return;

    items.removeWhere((item) => item.productId == productId);

    // Si no quedan items del proveedor, remover la entrada
    if (items.isEmpty) {
      _cartsBySupplier.remove(supplierId);
    }

    notifyListeners();
  }

  /// Limpiar carrito de un proveedor
  void clearSupplierCart(int supplierId) {
    _cartsBySupplier.remove(supplierId);
    notifyListeners();
  }

  /// Limpiar todo el carrito
  void clearCart() {
    _cartsBySupplier.clear();
    notifyListeners();
  }

  /// Verificar si un producto está en el carrito
  bool isInCart(int supplierId, int productId) {
    final items = _cartsBySupplier[supplierId];
    if (items == null) return false;
    return items.any((item) => item.productId == productId);
  }

  /// Obtener cantidad de un producto en el carrito
  int getProductQuantity(int supplierId, int productId) {
    final items = _cartsBySupplier[supplierId];
    if (items == null) return 0;

    final item = items.firstWhere(
          (item) => item.productId == productId,
      orElse: () => CartItem(
        productId: 0,
        supplierId: 0,
        supplierName: '',
        nombreProducto: '',
        precioUnitario: 0,
        cantidad: 0,
      ),
    );

    return item.cantidad;
  }

  /// Obtener precio según si aplica mayoreo
  double _getPrice(Map<String, dynamic> product) {
    final precioBase = product['precio_base'] ?? 0.0;
    final precioMayoreo = product['precio_mayoreo'];
    final cantidadMinima = product['cantidad_minima'] ?? 1;

    // Si hay precio mayoreo y la cantidad mínima es > 1, usar mayoreo
    if (precioMayoreo != null && cantidadMinima > 1) {
      return precioMayoreo is double
          ? precioMayoreo
          : double.tryParse(precioMayoreo.toString()) ?? precioBase;
    }

    return precioBase is double
        ? precioBase
        : double.tryParse(precioBase.toString()) ?? 0.0;
  }

  /// Obtener número de proveedores en el carrito
  int get supplierCount => _cartsBySupplier.length;

  /// Obtener lista de IDs de proveedores en el carrito
  List<int> get supplierIds => _cartsBySupplier.keys.toList();
}

/// Modelo de item del carrito
class CartItem {
  final int productId;
  final int supplierId;
  final String supplierName;
  final String nombreProducto;
  final double precioUnitario;
  final int cantidad;
  final String? imagen;
  final String unidadMedida;
  final int cantidadMinima;
  final int stockDisponible;

  CartItem({
    required this.productId,
    required this.supplierId,
    required this.supplierName,
    required this.nombreProducto,
    required this.precioUnitario,
    required this.cantidad,
    this.imagen,
    this.unidadMedida = 'unidad',
    this.cantidadMinima = 1,
    this.stockDisponible = 0,
  });

  double get subtotal => precioUnitario * cantidad;

  CartItem copyWith({
    int? productId,
    int? supplierId,
    String? supplierName,
    String? nombreProducto,
    double? precioUnitario,
    int? cantidad,
    String? imagen,
    String? unidadMedida,
    int? cantidadMinima,
    int? stockDisponible,
  }) {
    return CartItem(
      productId: productId ?? this.productId,
      supplierId: supplierId ?? this.supplierId,
      supplierName: supplierName ?? this.supplierName,
      nombreProducto: nombreProducto ?? this.nombreProducto,
      precioUnitario: precioUnitario ?? this.precioUnitario,
      cantidad: cantidad ?? this.cantidad,
      imagen: imagen ?? this.imagen,
      unidadMedida: unidadMedida ?? this.unidadMedida,
      cantidadMinima: cantidadMinima ?? this.cantidadMinima,
      stockDisponible: stockDisponible ?? this.stockDisponible,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id_supply_product': productId,
      'cantidad': cantidad,
      'precio_unitario': precioUnitario,
    };
  }
}