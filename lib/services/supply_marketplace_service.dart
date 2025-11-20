import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';

/// Servicio para gestionar el marketplace de proveedores
class SupplyMarketplaceService {
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // PROVEEDORES PÚBLICOS
  // ========================================================================

  /// Obtener todos los proveedores públicos
  static Future<List<Map<String, dynamic>>> getPublicSuppliers() async {
    try {
      // 🔥 Obtener proveedores
      final suppliers = await _supabase
          .from('supply_company')
          .select('id, name, email, phone, direccion, description, rating, total_reviews, is_verified, is_public')
          .eq('is_public', true)
          .eq('status', 1)
          .order('rating', ascending: false);

      // 🔥 Para cada proveedor, contar sus productos
      final List<Map<String, dynamic>> result = [];

      for (var supplier in suppliers) {
        final supplierId = supplier['id'] as int;

        // Contar productos del proveedor
        final productsResponse = await _supabase
            .from('supply_products')
            .select('id_supply_product')
            .eq('id_supply_company', supplierId)
            .eq('status', 1)
            .eq('disponible', true);

        final productsCount = productsResponse.length;

        result.add({
          ...supplier,
          'total_products': productsCount,
        });
      }

      if (kDebugMode) {
        print('✅ Proveedores obtenidos: ${result.length}');
        if (result.isNotEmpty) {
          print('📦 Primer proveedor: ${result[0]['name']} con ${result[0]['total_products']} productos');
        }
      }

      return result;
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo proveedores: $e');
      return [];
    }
  }

  /// Obtener detalles de un proveedor
  static Future<Map<String, dynamic>?> getSupplierDetails(int supplierId) async {
    try {
      final response = await _supabase
          .from('supply_company')
          .select('*')
          .eq('id', supplierId)
          .eq('is_public', true)
          .eq('status', 1)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo detalles: $e');
      return null;
    }
  }

  // ========================================================================
  // CATÁLOGO DE PRODUCTOS DEL PROVEEDOR - ⚡ VERSIÓN CORREGIDA
  // ========================================================================

  /// Obtener catálogo completo de un proveedor
  static Future<List<Map<String, dynamic>>> getSupplierCatalog(int supplierId) async {
    try {
      if (kDebugMode) print('🔍 Buscando productos del proveedor ID: $supplierId');

      final response = await _supabase
          .from('supply_products')
          .select('''
            id_supply_product,
            id_supply_company,
            nombre_producto,
            descripcion,
            categoria,
            marca,
            imagen,
            precio_base,
            precio_mayoreo,
            stock_disponible,
            cantidad_minima,
            unidad_medida,
            codigo_producto,
            disponible,
            status
          ''')
          .eq('id_supply_company', supplierId)
          .eq('status', 1)
          .eq('disponible', true)
          .order('nombre_producto', ascending: true);

      if (kDebugMode) {
        print('✅ Productos encontrados: ${response.length}');
        if (response.isNotEmpty) {
          print('📦 Primer producto: ${response[0]}');
        }
      }

      // 🔥 Procesar descripcion JSONB a String
      final processedProducts = response.map((product) {
        // Convertir descripcion JSONB a texto simple
        String descripcionText = '';
        if (product['descripcion'] != null) {
          final desc = product['descripcion'];
          if (desc is Map) {
            descripcionText = desc['detalle']?.toString() ?? '';
          } else if (desc is String) {
            descripcionText = desc;
          }
        }

        return {
          ...product,
          'descripcion_text': descripcionText, // Agregar versión texto
        };
      }).toList();

      return processedProducts;
    } catch (e, stack) {
      if (kDebugMode) {
        print('❌ ERROR obteniendo catálogo: $e');
        print('🔍 Stack: $stack');
      }
      return [];
    }
  }

  /// Buscar productos en el catálogo del proveedor
  static Future<List<Map<String, dynamic>>> searchSupplierProducts(
      int supplierId,
      String query,
      ) async {
    try {
      final searchPattern = '%${query.toLowerCase()}%';

      final response = await _supabase
          .from('supply_products')
          .select('*')
          .eq('id_supply_company', supplierId)
          .eq('status', 1)
          .eq('disponible', true)
          .or(
          'nombre_producto.ilike.$searchPattern,'
              'descripcion.ilike.$searchPattern,'
              'codigo_producto.ilike.$searchPattern'
      )
          .order('nombre_producto', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error buscando productos: $e');
      return [];
    }
  }

  /// Obtener productos por categoría
  static Future<List<Map<String, dynamic>>> getProductsByCategory(
      int supplierId,
      String category,
      ) async {
    try {
      final response = await _supabase
          .from('supply_products')
          .select('*')
          .eq('id_supply_company', supplierId)
          .eq('categoria', category)
          .eq('status', 1)
          .eq('disponible', true)
          .order('nombre_producto', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo productos por categoría: $e');
      return [];
    }
  }

  /// Obtener todas las categorías de un proveedor
  static Future<List<String>> getSupplierCategories(int supplierId) async {
    try {
      final response = await _supabase
          .from('supply_products')
          .select('categoria')
          .eq('id_supply_company', supplierId)
          .eq('status', 1)
          .eq('disponible', true)
          .not('categoria', 'is', null);

      final categories = response
          .map((item) => item['categoria'] as String?)
          .where((cat) => cat != null && cat.isNotEmpty)
          .whereType<String>()
          .toSet()
          .toList();

      categories.sort();
      if (kDebugMode) print('✅ Categorías encontradas: $categories');
      return categories;
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo categorías: $e');
      return [];
    }
  }

  // ========================================================================
  // GESTIÓN DE MI INVENTARIO IMPORTADO
  // ========================================================================

  /// Agregar producto del proveedor a mi inventario
  static Future<bool> addProductToMyInventory(
      int supplyProductId, {
        double? precioNegociado,
      }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('Usuario no pertenece a ninguna compañía');

      // Obtener detalles del producto
      final productResponse = await _supabase
          .from('supply_products')
          .select('*')
          .eq('id_supply_product', supplyProductId)
          .single();

      // Insertar en inventario_profile
      await _supabase.from('inventario_profile').insert({
        'id_company': companyId,
        'id_supply_product': supplyProductId,
        'precio_negociado': precioNegociado,
        'cantidad_inicial': 0,
        'is_active': true,
      });

      if (kDebugMode) print('✅ Producto agregado a inventario');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Error agregando producto: $e');
      return false;
    }
  }

  /// Obtener mis productos importados de proveedores
  static Future<List<Map<String, dynamic>>> getMyImportedProducts() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return [];

      final response = await _supabase
          .from('inventario_profile')
          .select('''
            *,
            supply_products!inner(
              nombre_producto,
              precio_base,
              imagen,
              categoria,
              marca,
              unidad_medida,
              supply_company!inner(
                name,
                email
              )
            )
          ''')
          .eq('id_company', companyId)
          .eq('is_active', true)
          .order('fecha_creacion', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo productos importados: $e');
      return [];
    }
  }

  /// Actualizar información de un producto importado
  static Future<void> updateImportedProduct(
      int inventarioProfileId,
      Map<String, dynamic> updates,
      ) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('Usuario no pertenece a ninguna compañía');

      await _supabase
          .from('inventario_profile')
          .update({
        ...updates,
        'fecha_modificacion': DateTime.now().toIso8601String(),
      })
          .eq('id_inventario_profile', inventarioProfileId)
          .eq('id_company', companyId);
    } catch (e) {
      throw Exception('Error actualizando producto: $e');
    }
  }

  /// Desactivar producto importado
  static Future<void> removeFromMyInventory(int inventarioProfileId) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('Usuario no pertenece a ninguna compañía');

      await _supabase
          .from('inventario_profile')
          .update({
        'is_active': false,
        'fecha_modificacion': DateTime.now().toIso8601String(),
      })
          .eq('id_inventario_profile', inventarioProfileId)
          .eq('id_company', companyId);
    } catch (e) {
      throw Exception('Error removiendo producto: $e');
    }
  }

  // ========================================================================
  // UTILIDADES
  // ========================================================================

  /// Formatear precio
  static String formatPrice(dynamic price) {
    if (price == null) return 'Q 0.00';
    final double priceValue = price is double ? price : double.tryParse(price.toString()) ?? 0.0;
    return 'Q ${priceValue.toStringAsFixed(2)}';
  }

  /// Verificar si un producto está en mi inventario
  static Future<bool> isProductInMyInventory(int supplyProductId) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return false;

      final response = await _supabase
          .from('inventario_profile')
          .select('id_inventario_profile')
          .eq('id_company', companyId)
          .eq('id_supply_product', supplyProductId)
          .eq('is_active', true)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) print('❌ Error verificando producto: $e');
      return false;
    }
  }

  // ========================================================================
  // PEDIDOS A PROVEEDORES
  // ========================================================================

  /// Crear pedido a proveedor
  static Future<int?> createOrder(
      int supplierId,
      List<Map<String, dynamic>> items,
      ) async {
    try {
      final userId = AuthService.currentUser?.id;
      final companyId = await InventoryService.getCurrentCompanyId();

      if (userId == null || companyId == null) {
        throw Exception('Usuario no autenticado o sin compañía');
      }

      // Calcular totales
      double subtotal = 0;
      int totalProductos = 0;

      for (var item in items) {
        final cantidad = item['cantidad'] as int;
        final precio = (item['precio_unitario'] as num).toDouble();
        subtotal += cantidad * precio;
        totalProductos += cantidad;
      }

      final impuestos = subtotal * 0.12; // IVA 12%
      final total = subtotal + impuestos;

      // Generar número de orden único
      final orderNumber = 'ORD-${DateTime.now().millisecondsSinceEpoch}';

      // Crear orden
      final orderResponse = await _supabase
          .from('supply_orders')
          .insert({
        'id_company': companyId,
        'id_supply_company': supplierId,
        'order_number': orderNumber,
        'total_productos': totalProductos,
        'subtotal': subtotal,
        'impuestos': impuestos,
        'total': total,
        'status': 'pending',
        'created_by': userId,
        'created_at': DateTime.now().toIso8601String(),
      })
          .select('id_order')
          .single();

      final orderId = orderResponse['id_order'] as int;

      // Insertar items del pedido
      final orderItems = items.map((item) {
        final cantidad = item['cantidad'] as int;
        final precioUnitario = (item['precio_unitario'] as num).toDouble();
        return {
          'id_order': orderId,
          'id_supply_product': item['id_supply_product'],
          'cantidad': cantidad,
          'precio_unitario': precioUnitario,
          'subtotal': cantidad * precioUnitario,
        };
      }).toList();

      await _supabase.from('supply_order_items').insert(orderItems);

      if (kDebugMode) print('✅ Orden creada: #$orderId');
      return orderId;
    } catch (e) {
      if (kDebugMode) print('❌ Error creando orden: $e');
      return null;
    }
  }

  /// Obtener mis pedidos
  static Future<List<Map<String, dynamic>>> getMyOrders() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return [];

      final response = await _supabase
          .from('supply_orders')
          .select('''
            *,
            supply_company!inner(
              name,
              email,
              phone
            ),
            supply_order_items(count)
          ''')
          .eq('id_company', companyId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo pedidos: $e');
      return [];
    }
  }

  /// Obtener detalles de un pedido
  static Future<Map<String, dynamic>?> getOrderDetails(int orderId) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return null;

      final response = await _supabase
          .from('supply_orders')
          .select('''
            *,
            supply_company!inner(
              name,
              email,
              phone,
              direccion
            ),
            supply_order_items!inner(
              *,
              supply_products!inner(
                nombre_producto,
                imagen,
                unidad_medida
              )
            )
          ''')
          .eq('id_order', orderId)
          .eq('id_company', companyId)
          .single();

      return response;
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo detalles del pedido: $e');
      return null;
    }
  }

  /// Actualizar estado de pedido
  static Future<void> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('Usuario no pertenece a ninguna compañía');

      await _supabase
          .from('supply_orders')
          .update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id_order', orderId)
          .eq('id_company', companyId);
    } catch (e) {
      throw Exception('Error actualizando estado: $e');
    }
  }

  /// Cancelar pedido
  static Future<void> cancelOrder(int orderId) async {
    try {
      await updateOrderStatus(orderId, 'cancelled');
    } catch (e) {
      throw Exception('Error cancelando pedido: $e');
    }
  }

  /// Obtener estatus de pedido en español
  static String getOrderStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pendiente';
      case 'confirmed':
        return 'Confirmado';
      case 'shipped':
        return 'Enviado';
      case 'delivered':
        return 'Entregado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  /// Obtener color del estatus
  static int getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 0xFFF59E0B; // Amarillo
      case 'confirmed':
        return 0xFF3B82F6; // Azul
      case 'shipped':
        return 0xFF8B5CF6; // Púrpura
      case 'delivered':
        return 0xFF10B981; // Verde
      case 'cancelled':
        return 0xFFEF4444; // Rojo
      default:
        return 0xFF6B7280; // Gris
    }
  }
}