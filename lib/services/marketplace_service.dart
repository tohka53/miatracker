import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Servicio para gestionar el Marketplace
/// Maneja productos, búsquedas y favoritos del marketplace
class MarketplaceService {
  static final _supabase = Supabase.instance.client;

  // ==================== PRODUCTOS ====================

  /// Obtener productos del marketplace con filtros
  static Future<List<Map<String, dynamic>>> getProducts({
    String? searchQuery,
    String? category,
    String? supplierId,
    double? minPrice,
    double? maxPrice,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      // Si hay búsqueda por texto, usar la función de Postgres directamente
      if (searchQuery != null && searchQuery.isNotEmpty) {
        return await searchProducts(searchQuery, limit: limit, offset: offset);
      }

      // Construir query base
      var baseQuery = _supabase
          .from('marketplace_products')
          .select('''
            *,
            supplier:company_settings!marketplace_products_supplier_user_id_fkey(
              company_name,
              supplier_rating
            )
          ''')
          .eq('status', 'active');

      // Aplicar filtro de categoría
      if (category != null && category.isNotEmpty) {
        baseQuery = baseQuery.eq('category', category);
      }

      // Aplicar filtro de proveedor
      if (supplierId != null && supplierId.isNotEmpty) {
        baseQuery = baseQuery.eq('supplier_user_id', supplierId);
      }

      // Aplicar filtro de precio mínimo
      if (minPrice != null) {
        baseQuery = baseQuery.gte('price', minPrice);
      }

      // Aplicar filtro de precio máximo
      if (maxPrice != null) {
        baseQuery = baseQuery.lte('price', maxPrice);
      }

      // Aplicar ordenamiento y paginación, luego ejecutar
      final response = await baseQuery
          .order('is_featured', ascending: false)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener productos del marketplace: $e');
      return [];
    }
  }

  /// Buscar productos usando búsqueda full-text
  static Future<List<Map<String, dynamic>>> searchProducts(
      String query, {
        int limit = 20,
        int offset = 0,
      }) async {
    try {
      final response = await _supabase.rpc('search_marketplace_products', params: {
        'search_query': query,
        'limit_count': limit,
        'offset_count': offset,
      });

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      if (kDebugMode) print('Error al buscar productos: $e');
      return [];
    }
  }

  /// Obtener un producto específico por ID
  static Future<Map<String, dynamic>?> getProductById(int productId) async {
    try {
      final response = await _supabase
          .from('marketplace_products')
          .select('''
            *,
            supplier:company_settings!marketplace_products_supplier_user_id_fkey(
              company_name,
              supplier_rating,
              phone,
              email
            )
          ''')
          .eq('id', productId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('Error al obtener producto: $e');
      return null;
    }
  }

  /// Obtener productos destacados
  static Future<List<Map<String, dynamic>>> getFeaturedProducts({int limit = 10}) async {
    try {
      final response = await _supabase
          .from('marketplace_products')
          .select('''
            *,
            supplier:company_settings!marketplace_products_supplier_user_id_fkey(
              company_name,
              supplier_rating
            )
          ''')
          .eq('status', 'active')
          .eq('is_featured', true)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener productos destacados: $e');
      return [];
    }
  }

  /// Obtener categorías disponibles
  static Future<List<String>> getCategories() async {
    try {
      final response = await _supabase
          .from('marketplace_products')
          .select('category')
          .eq('status', 'active')
          .not('category', 'is', null);

      final categories = <String>{};
      for (var item in response) {
        if (item['category'] != null) {
          categories.add(item['category'].toString());
        }
      }

      return categories.toList()..sort();
    } catch (e) {
      if (kDebugMode) print('Error al obtener categorías: $e');
      return [];
    }
  }

  // ==================== PRODUCTOS DEL PROVEEDOR ====================

  /// Crear nuevo producto en el marketplace (solo proveedores)
  static Future<Map<String, dynamic>?> createProduct({
    required String name,
    required String description,
    required double price,
    required int stockQuantity,
    String? category,
    String? brand,
    String? model,
    String? sku,
    String? imageUrl,
    Map<String, dynamic>? specifications,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('marketplace_products')
          .insert({
        'supplier_user_id': userId,
        'name': name,
        'description': description,
        'price': price,
        'stock_quantity': stockQuantity,
        'category': category,
        'brand': brand,
        'model': model,
        'sku': sku,
        'image_url': imageUrl,
        'specifications': specifications,
        'status': 'active',
      })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al crear producto: $e');
    }
  }

  /// Actualizar producto existente
  static Future<void> updateProduct(
      int productId,
      Map<String, dynamic> updates,
      ) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('marketplace_products')
          .update(updates)
          .eq('id', productId)
          .eq('supplier_user_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }

  /// Eliminar producto (cambia status a inactive)
  static Future<void> deleteProduct(int productId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('marketplace_products')
          .update({'status': 'inactive'})
          .eq('id', productId)
          .eq('supplier_user_id', userId);
    } catch (e) {
      throw Exception('Error al eliminar producto: $e');
    }
  }

  /// Obtener mis productos como proveedor
  static Future<List<Map<String, dynamic>>> getMyProducts() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('marketplace_products')
          .select('*')
          .eq('supplier_user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener mis productos: $e');
      return [];
    }
  }

  // ==================== ÓRDENES ====================

  /// Crear una orden de compra
  static Future<int?> createOrder({
    required String supplierUserId,
    required String supplierCompanyName,
    required List<Map<String, dynamic>> items,
    required double totalAmount,
    String? buyerNotes,
    Map<String, dynamic>? shippingAddress,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Crear la orden
      final order = await _supabase
          .from('marketplace_orders')
          .insert({
        'buyer_user_id': userId,
        'supplier_user_id': supplierUserId,
        'supplier_company_name': supplierCompanyName,
        'subtotal': totalAmount,
        'total_amount': totalAmount,
        'status': 'pending',
        'buyer_notes': buyerNotes,
        'shipping_address': shippingAddress,
      })
          .select()
          .single();

      final orderId = order['id'] as int;

      // Crear los items de la orden
      final orderItems = items.map((item) => {
        'order_id': orderId,
        'product_id': item['id'],
        'product_name': item['nombre'] ?? item['name'],
        'product_description': item['descripcion'] ?? item['description'],
        'product_sku': item['sku'],
        'product_image_url': item['imagen'] ?? item['image_url'],
        'quantity': item['quantity'],
        'unit_price': item['precio'] ?? item['price'],
        'subtotal': (item['quantity'] as int) *
            ((item['precio'] ?? item['price']) as double),
      }).toList();

      await _supabase.from('marketplace_order_items').insert(orderItems);

      return orderId;
    } catch (e) {
      throw Exception('Error al crear orden: $e');
    }
  }

  /// Obtener mis órdenes como comprador
  static Future<List<Map<String, dynamic>>> getMyOrders() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('marketplace_orders')
          .select('''
            *,
            items:marketplace_order_items(*)
          ''')
          .eq('buyer_user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener mis órdenes: $e');
      return [];
    }
  }

  /// Obtener órdenes recibidas como proveedor
  static Future<List<Map<String, dynamic>>> getSupplierOrders({
    String? status,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      // Construir query sin filtros opcionales primero
      var baseQuery = _supabase
          .from('marketplace_orders')
          .select('''
            *,
            items:marketplace_order_items(*)
          ''')
          .eq('supplier_user_id', userId);

      // Aplicar filtro de status si existe
      final query = (status != null && status.isNotEmpty)
          ? baseQuery.eq('status', status)
          : baseQuery;

      // Aplicar ordenamiento y ejecutar
      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener órdenes del proveedor: $e');
      return [];
    }
  }

  /// Actualizar estado de una orden (solo proveedor)
  static Future<void> updateOrderStatus(int orderId, String newStatus) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final updates = <String, dynamic>{
        'status': newStatus,
      };

      // Agregar timestamps según el estado
      switch (newStatus) {
        case 'confirmed':
          updates['confirmed_at'] = DateTime.now().toIso8601String();
          break;
        case 'shipped':
          updates['shipped_at'] = DateTime.now().toIso8601String();
          break;
        case 'delivered':
          updates['delivered_at'] = DateTime.now().toIso8601String();
          break;
        case 'cancelled':
          updates['cancelled_at'] = DateTime.now().toIso8601String();
          break;
      }

      await _supabase
          .from('marketplace_orders')
          .update(updates)
          .eq('id', orderId)
          .eq('supplier_user_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar estado de orden: $e');
    }
  }

  // ==================== FAVORITOS ====================

  /// Agregar producto a favoritos
  static Future<void> addToFavorites(int productId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase.from('marketplace_favorites').insert({
        'user_id': userId,
        'product_id': productId,
      });
    } catch (e) {
      throw Exception('Error al agregar a favoritos: $e');
    }
  }

  /// Eliminar producto de favoritos
  static Future<void> removeFromFavorites(int productId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('marketplace_favorites')
          .delete()
          .eq('user_id', userId)
          .eq('product_id', productId);
    } catch (e) {
      throw Exception('Error al eliminar de favoritos: $e');
    }
  }

  /// Obtener mis productos favoritos
  static Future<List<Map<String, dynamic>>> getMyFavorites() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('marketplace_favorites')
          .select('''
            *,
            product:marketplace_products(
              *,
              supplier:company_settings!marketplace_products_supplier_user_id_fkey(
                company_name,
                supplier_rating
              )
            )
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener favoritos: $e');
      return [];
    }
  }

  /// Verificar si un producto está en favoritos
  static Future<bool> isFavorite(int productId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return false;

      final response = await _supabase
          .from('marketplace_favorites')
          .select('id')
          .eq('user_id', userId)
          .eq('product_id', productId)
          .maybeSingle();

      return response != null;
    } catch (e) {
      if (kDebugMode) print('Error al verificar favorito: $e');
      return false;
    }
  }

  // ==================== ESTADÍSTICAS ====================

  /// Obtener estadísticas del proveedor
  static Future<Map<String, dynamic>> getSupplierStats() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase.rpc('get_supplier_stats', params: {
        'supplier_uuid': userId,
      });

      return response ?? {};
    } catch (e) {
      if (kDebugMode) print('Error al obtener estadísticas: $e');
      return {};
    }
  }
}