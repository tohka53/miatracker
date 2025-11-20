/// Constantes y enums para el sistema de Marketplace
/// Centraliza todos los valores constantes para fácil mantenimiento

class MarketplaceConstants {
  // ==================== ESTADO DE PRODUCTOS ====================

  static const String productStatusActive = 'active';
  static const String productStatusInactive = 'inactive';
  static const String productStatusOutOfStock = 'out_of_stock';
  static const String productStatusDiscontinued = 'discontinued';

  // ==================== ESTADO DE ÓRDENES ====================

  static const String orderStatusPending = 'pending';
  static const String orderStatusConfirmed = 'confirmed';
  static const String orderStatusProcessing = 'processing';
  static const String orderStatusShipped = 'shipped';
  static const String orderStatusDelivered = 'delivered';
  static const String orderStatusCancelled = 'cancelled';
  static const String orderStatusRefunded = 'refunded';

  // ==================== CATEGORÍAS PREDEFINIDAS ====================

  static const List<String> defaultCategories = [
    'Electrónicos',
    'Muebles',
    'Accesorios',
    'Herramientas',
    'Oficina',
    'Construcción',
    'Automotriz',
    'Industrial',
    'Tecnología',
    'Otro',
  ];

  // ==================== LÍMITES Y RANGOS ====================

  static const int minProductPrice = 0;
  static const int maxProductPrice = 1000000;
  static const int minOrderQuantity = 1;
  static const int maxOrderQuantity = 10000;
  static const int lowStockThreshold = 5;
  static const int productsPerPage = 20;
  static const int maxSearchResults = 100;

  // ==================== RATINGS ====================

  static const int minRating = 1;
  static const int maxRating = 5;
  static const double minSupplierRating = 0.0;
  static const double maxSupplierRating = 5.0;

  // ==================== MENSAJES ====================

  static const String msgProductAddedToCart = 'Producto agregado al carrito';
  static const String msgProductRemovedFromCart = 'Producto eliminado del carrito';
  static const String msgOrderCreated = 'Pedido creado exitosamente';
  static const String msgOrderCancelled = 'Pedido cancelado';
  static const String msgOrderConfirmed = 'Pedido confirmado';
  static const String msgSupplierModeEnabled = 'Modo proveedor activado';
  static const String msgSupplierModeDisabled = 'Modo proveedor desactivado';
  static const String msgSettingsSaved = 'Configuración guardada';

  static const String errorLoadingProducts = 'Error al cargar productos';
  static const String errorLoadingOrders = 'Error al cargar pedidos';
  static const String errorCreatingOrder = 'Error al crear pedido';
  static const String errorSavingSettings = 'Error al guardar configuración';
  static const String errorInsufficientStock = 'Stock insuficiente';
  static const String errorUnauthorized = 'No autorizado';

  // ==================== ICONOS ====================

  static const String iconProduct = 'inventory_2';
  static const String iconOrder = 'shopping_bag';
  static const String iconSupplier = 'business';
  static const String iconCart = 'shopping_cart';
  static const String iconFavorite = 'favorite';
  static const String iconRating = 'star';

  // ==================== COLORES (Material Color Codes) ====================

  static const int primaryColor = 0xFF2B5F8C;
  static const int secondaryColor = 0xFF6B8E3D;
  static const int accentColor = 0xFF8B5A2B;
  static const int backgroundColor = 0xFFF5F3E8;
  static const int cardColor = 0xFFE8E5D6;

  // Estados de stock
  static const int inStockColor = 0xFF4CAF50;
  static const int lowStockColor = 0xFFFF9800;
  static const int outOfStockColor = 0xFFF44336;

  // Estados de orden
  static const int pendingColor = 0xFFFF9800;
  static const int confirmedColor = 0xFF2196F3;
  static const int shippedColor = 0xFF9C27B0;
  static const int deliveredColor = 0xFF4CAF50;
  static const int cancelledColor = 0xFFF44336;
}

// ==================== ENUMS ====================

/// Estado de un producto en el marketplace
enum ProductStatus {
  active,
  inactive,
  outOfStock,
  discontinued;

  String get value {
    switch (this) {
      case ProductStatus.active:
        return MarketplaceConstants.productStatusActive;
      case ProductStatus.inactive:
        return MarketplaceConstants.productStatusInactive;
      case ProductStatus.outOfStock:
        return MarketplaceConstants.productStatusOutOfStock;
      case ProductStatus.discontinued:
        return MarketplaceConstants.productStatusDiscontinued;
    }
  }

  String get displayName {
    switch (this) {
      case ProductStatus.active:
        return 'Activo';
      case ProductStatus.inactive:
        return 'Inactivo';
      case ProductStatus.outOfStock:
        return 'Agotado';
      case ProductStatus.discontinued:
        return 'Descontinuado';
    }
  }

  static ProductStatus fromString(String value) {
    switch (value) {
      case 'active':
        return ProductStatus.active;
      case 'inactive':
        return ProductStatus.inactive;
      case 'out_of_stock':
        return ProductStatus.outOfStock;
      case 'discontinued':
        return ProductStatus.discontinued;
      default:
        return ProductStatus.inactive;
    }
  }
}

/// Estado de una orden
enum OrderStatus {
  pending,
  confirmed,
  processing,
  shipped,
  delivered,
  cancelled,
  refunded;

  String get value {
    switch (this) {
      case OrderStatus.pending:
        return MarketplaceConstants.orderStatusPending;
      case OrderStatus.confirmed:
        return MarketplaceConstants.orderStatusConfirmed;
      case OrderStatus.processing:
        return MarketplaceConstants.orderStatusProcessing;
      case OrderStatus.shipped:
        return MarketplaceConstants.orderStatusShipped;
      case OrderStatus.delivered:
        return MarketplaceConstants.orderStatusDelivered;
      case OrderStatus.cancelled:
        return MarketplaceConstants.orderStatusCancelled;
      case OrderStatus.refunded:
        return MarketplaceConstants.orderStatusRefunded;
    }
  }

  String get displayName {
    switch (this) {
      case OrderStatus.pending:
        return 'Pendiente';
      case OrderStatus.confirmed:
        return 'Confirmado';
      case OrderStatus.processing:
        return 'Procesando';
      case OrderStatus.shipped:
        return 'Enviado';
      case OrderStatus.delivered:
        return 'Entregado';
      case OrderStatus.cancelled:
        return 'Cancelado';
      case OrderStatus.refunded:
        return 'Reembolsado';
    }
  }

  int get colorCode {
    switch (this) {
      case OrderStatus.pending:
        return MarketplaceConstants.pendingColor;
      case OrderStatus.confirmed:
        return MarketplaceConstants.confirmedColor;
      case OrderStatus.processing:
        return MarketplaceConstants.confirmedColor;
      case OrderStatus.shipped:
        return MarketplaceConstants.shippedColor;
      case OrderStatus.delivered:
        return MarketplaceConstants.deliveredColor;
      case OrderStatus.cancelled:
        return MarketplaceConstants.cancelledColor;
      case OrderStatus.refunded:
        return MarketplaceConstants.cancelledColor;
    }
  }

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'processing':
        return OrderStatus.processing;
      case 'shipped':
        return OrderStatus.shipped;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      default:
        return OrderStatus.pending;
    }
  }
}

/// Tipo de filtro para productos
enum ProductSortType {
  newest,
  oldest,
  priceLowToHigh,
  priceHighToLow,
  nameAtoZ,
  nameZtoA,
  popularity;

  String get displayName {
    switch (this) {
      case ProductSortType.newest:
        return 'Más recientes';
      case ProductSortType.oldest:
        return 'Más antiguos';
      case ProductSortType.priceLowToHigh:
        return 'Precio: Menor a Mayor';
      case ProductSortType.priceHighToLow:
        return 'Precio: Mayor a Menor';
      case ProductSortType.nameAtoZ:
        return 'Nombre: A-Z';
      case ProductSortType.nameZtoA:
        return 'Nombre: Z-A';
      case ProductSortType.popularity:
        return 'Más populares';
    }
  }
}

/// Nivel de stock del producto
enum StockLevel {
  outOfStock,
  low,
  normal,
  high;

  String get displayName {
    switch (this) {
      case StockLevel.outOfStock:
        return 'Agotado';
      case StockLevel.low:
        return 'Stock Bajo';
      case StockLevel.normal:
        return 'Stock Normal';
      case StockLevel.high:
        return 'Stock Alto';
    }
  }

  int get colorCode {
    switch (this) {
      case StockLevel.outOfStock:
        return MarketplaceConstants.outOfStockColor;
      case StockLevel.low:
        return MarketplaceConstants.lowStockColor;
      case StockLevel.normal:
        return MarketplaceConstants.inStockColor;
      case StockLevel.high:
        return MarketplaceConstants.inStockColor;
    }
  }

  static StockLevel fromQuantity(int quantity) {
    if (quantity <= 0) return StockLevel.outOfStock;
    if (quantity <= MarketplaceConstants.lowStockThreshold) return StockLevel.low;
    if (quantity <= 50) return StockLevel.normal;
    return StockLevel.high;
  }
}

// ==================== VALIDACIONES ====================

class MarketplaceValidators {
  /// Validar precio del producto
  static String? validatePrice(String? value) {
    if (value == null || value.isEmpty) {
      return 'El precio es requerido';
    }

    final price = double.tryParse(value);
    if (price == null) {
      return 'Ingrese un precio válido';
    }

    if (price < MarketplaceConstants.minProductPrice) {
      return 'El precio debe ser mayor a ${MarketplaceConstants.minProductPrice}';
    }

    if (price > MarketplaceConstants.maxProductPrice) {
      return 'El precio no puede exceder ${MarketplaceConstants.maxProductPrice}';
    }

    return null;
  }

  /// Validar cantidad de stock
  static String? validateStock(String? value) {
    if (value == null || value.isEmpty) {
      return 'La cantidad es requerida';
    }

    final stock = int.tryParse(value);
    if (stock == null) {
      return 'Ingrese una cantidad válida';
    }

    if (stock < 0) {
      return 'La cantidad no puede ser negativa';
    }

    return null;
  }

  /// Validar nombre de producto
  static String? validateProductName(String? value) {
    if (value == null || value.isEmpty) {
      return 'El nombre del producto es requerido';
    }

    if (value.length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }

    if (value.length > 100) {
      return 'El nombre no puede exceder 100 caracteres';
    }

    return null;
  }

  /// Validar descripción
  static String? validateDescription(String? value) {
    if (value == null || value.isEmpty) {
      return 'La descripción es requerida';
    }

    if (value.length < 10) {
      return 'La descripción debe tener al menos 10 caracteres';
    }

    return null;
  }

  /// Validar rating
  static String? validateRating(int? value) {
    if (value == null) {
      return 'La calificación es requerida';
    }

    if (value < MarketplaceConstants.minRating ||
        value > MarketplaceConstants.maxRating) {
      return 'La calificación debe estar entre ${MarketplaceConstants.minRating} y ${MarketplaceConstants.maxRating}';
    }

    return null;
  }

  /// Validar email
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El email es requerido';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingrese un email válido';
    }

    return null;
  }

  /// Validar teléfono
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es requerido';
    }

    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
    if (!phoneRegex.hasMatch(value)) {
      return 'Ingrese un teléfono válido';
    }

    if (value.replaceAll(RegExp(r'[\s\-\(\)]'), '').length < 8) {
      return 'El teléfono debe tener al menos 8 dígitos';
    }

    return null;
  }
}

// ==================== FORMATTERS ====================

class MarketplaceFormatters {
  /// Formatear precio en moneda local
  static String formatPrice(double price, {String symbol = '\$'}) {
    return '$symbol${price.toStringAsFixed(2)}';
  }

  /// Formatear cantidad con separadores de miles
  static String formatQuantity(int quantity) {
    return quantity.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
    );
  }

  /// Formatear fecha
  static String formatDate(DateTime date) {
    final months = [
      'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
      'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
    ];

    return '${date.day} de ${months[date.month - 1]} ${date.year}';
  }

  /// Formatear fecha y hora
  static String formatDateTime(DateTime dateTime) {
    return '${formatDate(dateTime)} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  /// Formatear rating con estrellas
  static String formatRating(double rating) {
    return '${rating.toStringAsFixed(1)} ⭐';
  }

  /// Formatear número de orden
  static String formatOrderNumber(String orderNumber) {
    return orderNumber.toUpperCase();
  }
}