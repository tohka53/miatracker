// lib/services/order_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'auth_service.dart';
import 'inventory_service.dart';

class OrderService {
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // FUNCIONES PARA SHOPPING CART (USA TABLA 'orders' CON QR)
  // ========================================================================

  /// Procesar orden de compra desde el carrito
  static Future<Map<String, dynamic>> processOrder(
      List<Map<String, dynamic>> items,
      Map<String, dynamic> orderSummary, {
        Map<String, dynamic>? direccionEnvio,
      }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      if (kDebugMode) {
        print('📦 Iniciando procesamiento de orden...');
      }

      // 1. Actualizar stock de cada producto
      for (final item in items) {
        final productId = item['product_id'];
        final quantityOrdered = item['quantity'];


        final companyId = await InventoryService.getCurrentCompanyId();
        final currentProduct = await _supabase
            .from('inventario')
            .select('cantidad')
            .eq('id_inventario', productId)

            .eq('id_company', companyId!)   // ✅ correcto
            .maybeSingle();                // ✅ evita PGRST116 cuando no hay filas

        if (currentProduct == null) {
          throw Exception('Producto no encontrado (id: $productId)');
        }
        final currentStock = currentProduct['cantidad'] ?? 0;
        final newStock = currentStock - quantityOrdered;

        if (newStock < 0) {
          throw Exception(
            'Stock insuficiente para ${item['name']}. Disponible: $currentStock, Requerido: $quantityOrdered',
          );
        }

        await InventoryService.updateInventoryItem(productId, {
          'cantidad': newStock,
        });

        if (kDebugMode) {
          print('✅ Stock actualizado: ${item['name']} - $currentStock → $newStock');
        }
      }

      // 2. Crear orden con QR usando la función SQL
      final result = await createOrder(
        orderType: 'sale',
        items: items,
        totalAmount: orderSummary['total_amount']?.toDouble() ?? 0.0,
        responsable: orderSummary['customer_name'],
        observaciones: orderSummary['notes'],
        direccionEnvio: direccionEnvio,
      );

      if (kDebugMode) {
        print('✅ Orden procesada: ${result['order_number']}');
      }

      return {
        'success': true,
        'order_id': result['order_id'],
        'order_number': result['order_number'],
        'qr_code': result['qr_code'],
        'message': 'Orden procesada exitosamente',
        'items_updated': items.length,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando orden: $e');
      }
      rethrow;
    }
  }

  // ========================================================================
  // FUNCIONES PARA ÓRDENES CON QR
  // ========================================================================

  /// Crear nueva orden con QR automático
  static Future<Map<String, dynamic>> createOrder({
    required String orderType,
    required List<Map<String, dynamic>> items,
    double totalAmount = 0.0,
    int? idLocationOrigen,
    int? idLocationDestino,
    String? responsable,
    String? observaciones,
    String priority = 'normal',
    Map<String, dynamic>? direccionEnvio,
  }) async {
    try {
      // ✅ PASO 1: Verificar usuario autenticado
      final userId = AuthService.currentUser?.id;
      final userEmail = AuthService.currentUser?.email;

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📦 INICIANDO CREACIÓN DE ORDEN');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('👤 Usuario actual:');
        print('   ID: $userId');
        print('   Email: $userEmail');
        print('   ¿Autenticado?: ${userId != null}');
      }

      if (userId == null) {
        throw Exception('❌ Usuario no autenticado - AuthService.currentUser es null');
      }

      if (items.isEmpty) {
        throw Exception('❌ No hay items en la orden');
      }

      if (kDebugMode) {
        print('📊 Detalles de la orden:');
        print('   Tipo: $orderType');
        print('   Items: ${items.length}');
        print('   Total: ${totalAmount.toStringAsFixed(2)}');
        print('   Responsable: $responsable');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      // ✅ PASO 2: Preparar parámetros para RPC
      final params = {
        'user_uuid': userId, // ⚡ IMPORTANTE: Para quién es la orden (mismo usuario)
        'p_order_type': orderType,
        'p_items': items,
        'p_total_amount': totalAmount,
        'p_responsable': responsable,
        'p_observaciones': observaciones,
        'p_priority': priority,
        'p_id_location_origen': idLocationOrigen,
        'p_id_location_destino': idLocationDestino,
        'p_direccion_envio': direccionEnvio,
      };

      if (kDebugMode) {
        print('🔧 Parámetros RPC:');
        print('   user_uuid: ${params['user_uuid']}');
        print('   order_type: ${params['p_order_type']}');
        print('   items count: ${items.length}');
        print('   total_amount: ${params['p_total_amount']}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      // ✅ PASO 3: Llamar a la función RPC
      if (kDebugMode) {
        print('📡 Llamando a create_order_with_qr...');
      }

      final response = await _supabase.rpc(
        'create_order_with_qr',
        params: params,
      );

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('📥 RESPUESTA DE SUPABASE:');
        print('   Type: ${response.runtimeType}');
        print('   Content: $response');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      // ✅ PASO 4: Validar respuesta
      if (response == null) {
        throw Exception('❌ Respuesta nula de RPC');
      }

      // Convertir respuesta a Map
      Map<String, dynamic> result;
      if (response is Map<String, dynamic>) {
        result = response;
      } else if (response is List && response.isNotEmpty) {
        result = response.first as Map<String, dynamic>;
      } else {
        throw Exception('❌ Formato de respuesta inválido: ${response.runtimeType}');
      }

      // ✅ PASO 5: Verificar éxito
      final success = result['success'] ?? false;

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        if (success == true) {
          print('✅ ORDEN CREADA EXITOSAMENTE');
          print('   Número: ${result['order_number']}');
          print('   QR: ${result['qr_code']}');
          print('   Items: ${result['total_items']}');
        } else {
          print('❌ ERROR EN RPC');
          print('   Message: ${result['message']}');
          print('   Debug Info: ${result['debug_info']}');
        }
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (success == true) {
        return result;
      } else {
        final errorMsg = result['message'] ?? 'Error desconocido';
        final debugInfo = result['debug_info'];
        throw Exception('$errorMsg${debugInfo != null ? '\nDebug: $debugInfo' : ''}');
      }

    } on PostgrestException catch (e) {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('❌ ERROR POSTGREST');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Code: ${e.code}');
        print('Message: ${e.message}');
        print('Details: ${e.details}');
        print('Hint: ${e.hint}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      if (e.code == 'PGRST116') {
        throw Exception(
            '❌ Error PGRST116: La función RPC no retornó resultados.\n'
                'Verifica que create_order_with_qr esté correctamente instalada.'
        );
      }

      throw Exception('Error Postgrest (${e.code}): ${e.message}');

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('❌ ERROR GENERAL');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Error: $e');
        print('StackTrace: $stackTrace');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      rethrow;
    }
  }


  // ========================================================================
// CÓDIGO CORREGIDO PARA processCheckout
// ========================================================================

  static Future<Map<String, dynamic>> processCheckout({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> orderSummary,
    Map<String, dynamic>? direccionEnvio,
  }) async {
    try {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🛒 PROCESANDO CHECKOUT');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Items: ${items.length}');
        print('Total: ${orderSummary['total_amount']}');
      }

      // ✅ PASO 1: Validar y actualizar stock
      for (var item in items) {
        final productId = item['product_id'] ??
            item['productId'] ??
            item['id_inventario'];

        final quantity = item['quantity'] ??
            item['cantidad'] ??
            1;

        if (productId == null) {
          throw Exception('❌ Item sin product_id: $item');
        }

        // Obtener producto actual
        final product = await InventoryService.getProductById(productId);

        if (product == null) {
          throw Exception('❌ Producto no encontrado: $productId');
        }

        final currentStock = product['cantidad'] ?? 0;
        final productName = product['nombre_producto'] ?? 'Producto sin nombre';
        final newStock = currentStock - quantity;

        if (newStock < 0) {
          throw Exception(
              '❌ Stock insuficiente para $productName\n'
                  'Disponible: $currentStock, Requerido: $quantity'
          );
        }

        // Actualizar stock
        await InventoryService.updateInventoryItem(productId, {
          'cantidad': newStock,
        });

        if (kDebugMode) {
          print('✅ Stock actualizado: $productName ($currentStock → $newStock)');
        }
      }

      // ✅ PASO 2: Crear orden con QR
      final orderResult = await createOrder(
        orderType: 'sale',
        items: items,
        totalAmount: orderSummary['total_amount']?.toDouble() ?? 0.0,
        responsable: orderSummary['customer_name'],
        observaciones: orderSummary['notes'],
        direccionEnvio: direccionEnvio,
      );

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('✅ CHECKOUT COMPLETADO');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      return {
        'success': true,
        'order_id': orderResult['order_id'],
        'order_number': orderResult['order_number'],
        'qr_code': orderResult['qr_code'],
        'message': '✅ Orden procesada exitosamente',
        'items_updated': items.length,
      };

    } catch (e) {
      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('❌ ERROR EN CHECKOUT');
        print('Error: $e');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }
      rethrow;
    }
  }
  static Future<Map<String, dynamic>> checkAuthStatus() async {
    try {
      final session = _supabase.auth.currentSession;
      final user = _supabase.auth.currentUser;

      final status = {
        'has_session': session != null,
        'has_user': user != null,
        'user_id': user?.id,
        'user_email': user?.email,
        'session_expired': session != null
            ? session.expiresAt! < DateTime.now().millisecondsSinceEpoch / 1000
            : null,
      };

      if (kDebugMode) {
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('🔐 ESTADO DE AUTENTICACIÓN');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        print('Has Session: ${status['has_session']}');
        print('Has User: ${status['has_user']}');
        print('User ID: ${status['user_id']}');
        print('User Email: ${status['user_email']}');
        print('Session Expired: ${status['session_expired']}');
        print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      }

      return status;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error verificando auth status: $e');
      }
      return {'error': e.toString()};
    }
  }




  /// Obtener todas las órdenes del usuario
  static Future<List<Order>> getAllOrders() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).map((data) => Order.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo órdenes: $e');
      }
      return [];
    }
  }



  /// Obtener órdenes por estado
  static Future<List<Order>> getOrdersByStatus(String status) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .eq('status', status)
          .order('created_at', ascending: false);

      return (response as List).map((data) => Order.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo órdenes por estado: $e');
      }
      return [];
    }
  }

  /// Obtener órdenes por tipo
  static Future<List<Order>> getOrdersByType(String orderType) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .eq('order_type', orderType)
          .order('created_at', ascending: false);

      return (response as List).map((data) => Order.fromJson(data)).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo órdenes por tipo: $e');
      }
      return [];
    }
  }

  /// Buscar orden por código QR
  static Future<Order?> getOrderByQR(String qrCode) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase.rpc('search_order_by_qr', params: {
        'user_uuid': userId,
        'qr_code_value': qrCode,
      });

      if (response != null && response.isNotEmpty) {
        return Order.fromJson(response[0]);
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error buscando orden por QR: $e');
      }
      return null;
    }
  }

  /// Obtener orden por ID
  static Future<Order?> getOrderById(String orderId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('orders')
          .select()
          .eq('id', orderId)
          .eq('user_id', userId)
          .single();

      return Order.fromJson(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo orden: $e');
      }
      return null;
    }
  }

  /// Actualizar estado de orden
  static Future<void> updateOrderStatus(String orderId, String newStatus) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase.from('orders').update({
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      }).match({'id': orderId, 'user_id': userId});

      if (kDebugMode) {
        print('✅ Estado actualizado a: $newStatus');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error actualizando estado: $e');
      }
      rethrow;
    }
  }

  /// Actualizar dirección de envío de una orden
  static Future<void> updateOrderAddress(
      String orderId,
      Map<String, dynamic> direccionEnvio,
      ) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase.from('orders').update({
        'direccion_envio': direccionEnvio,
        'updated_at': DateTime.now().toIso8601String(),
      }).match({'id': orderId, 'user_id': userId});

      if (kDebugMode) {
        print('✅ Dirección actualizada');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error actualizando dirección: $e');
      }
      rethrow;
    }
  }

  /// Obtener estadísticas de órdenes
  static Future<Map<String, dynamic>> getOrderStatistics() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return {};

      final response = await _supabase.rpc('get_order_statistics', params: {
        'user_uuid': userId,
      });

      return Map<String, dynamic>.from(response ?? {});
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo estadísticas: $e');
      }
      return {};
    }
  }

  // ========================================================================
  // FUNCIONES DE COMPATIBILIDAD (LEGACY)
  // ========================================================================

  /// Obtener historial de órdenes (alias para compatibilidad)
  static Future<List<Map<String, dynamic>>> getUserOrders() async {
    try {
      final orders = await getAllOrders();
      return orders.map((order) => order.toJson()).toList();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo órdenes: $e');
      }
      return [];
    }
  }

  /// Obtener detalles de orden (alias para compatibilidad)
  static Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final order = await getOrderById(orderId);
      return order?.toJson();
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo detalles: $e');
      }
      return null;
    }
  }

  // ========================================================================
  // FUNCIONES NUEVAS USANDO LAS FUNCIONES SQL
  // ========================================================================

  /// Obtener historial usando la función SQL get_order_history
  static Future<List<Order>> getOrderHistorySQL({
    String? orderType,
    String? status,
    int limit = 50,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase.rpc(
        'get_order_history',
        params: {
          'user_uuid': userId,
          'p_order_type': orderType,
          'p_status': status,
          'p_limit': limit,
        },
      );

      if (response == null) return [];

      final List<dynamic> data = response is List ? response : [response];
      return data.map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error al obtener historial de órdenes: $e');
      return [];
    }
  }

  /// Buscar orden por número usando la función SQL get_order_by_number
  static Future<Order?> getOrderByNumberSQL(String orderNumber) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase.rpc(
        'get_order_by_number',
        params: {
          'user_uuid': userId,
          'p_order_number': orderNumber,
        },
      );

      if (response == null || (response is List && response.isEmpty)) {
        return null;
      }

      final data = response is List ? response.first : response;
      return Order.fromJson(data);
    } catch (e) {
      if (kDebugMode) print('❌ Error al buscar orden: $e');
      return null;
    }
  }

  /// Obtener estadísticas usando la función SQL get_order_stats
  static Future<OrderStats?> getOrderStatsSQL() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase.rpc(
        'get_order_stats',
        params: {'user_uuid': userId},
      );

      if (response == null || (response is List && response.isEmpty)) {
        return null;
      }

      final data = response is List ? response.first : response;
      return OrderStats.fromJson(data);
    } catch (e) {
      if (kDebugMode) print('❌ Error al obtener estadísticas: $e');
      return null;
    }
  }

  /// Generar número de orden usando la función SQL generate_order_number
  static Future<String> generateOrderNumber(String orderType) async {
    try {
      final response = await _supabase.rpc(
        'generate_order_number',
        params: {'p_order_type': orderType},
      );

      return response as String;
    } catch (e) {
      if (kDebugMode) print('❌ Error al generar número de orden: $e');
      // Fallback: generar manualmente
      final prefix = _getOrderPrefix(orderType);
      final timestamp = DateTime.now();
      final random = (DateTime.now().millisecondsSinceEpoch % 10000)
          .toString()
          .padLeft(4, '0');
      return '$prefix-${DateFormat('yyyyMMdd').format(timestamp)}-$random';
    }
  }

  static String _getOrderPrefix(String orderType) {
    switch (orderType) {
      case 'sale':
        return 'VTA';
      case 'purchase':
        return 'CMP';
      case 'entrada':
        return 'ENT';
      case 'salida':
        return 'SAL';
      case 'transferencia':
        return 'TRF';
      case 'ajuste':
        return 'AJU';
      default:
        return 'ORD';
    }
  }

  /// Obtener órdenes por rango de fechas
  static Future<List<Order>> getOrdersByDateRange(
      DateTime startDate,
      DateTime endDate, {
        String? orderType,
      }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      // ✅ SOLUCIÓN 1: Sin variables intermedias, todo en una cadena
      final response = orderType != null
          ? await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .eq('order_type', orderType)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false)
          : await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', endDate.toIso8601String())
          .order('created_at', ascending: false);

      return (response as List).map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error al obtener órdenes por fecha: $e');
      return [];
    }
  }
  /// Obtener órdenes del mes actual
  static Future<List<Order>> getCurrentMonthOrders() async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    return getOrdersByDateRange(startOfMonth, endOfMonth);
  }

  /// Obtener órdenes pendientes
  static Future<List<Order>> getPendingOrders() async {
    return getOrdersByStatus('pending');
  }

  /// Obtener órdenes completadas
  static Future<List<Order>> getCompletedOrders() async {
    return getOrdersByStatus('completed');
  }

  /// Buscar órdenes por responsable
  static Future<List<Order>> getOrdersByResponsable(String responsable) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('orders')
          .select()
          .eq('user_id', userId)
          .ilike('responsable', '%$responsable%')
          .order('created_at', ascending: false);

      return (response as List).map((json) => Order.fromJson(json)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error al buscar por responsable: $e');
      return [];
    }
  }

  /// Cancelar orden
  static Future<void> cancelOrder(String orderId) async {
    try {
      await updateOrderStatus(orderId, 'cancelled');
    } catch (e) {
      throw Exception('Error al cancelar orden: $e');
    }
  }
}

// ========================================================================
// MODELOS
// ========================================================================

class Order {
  final String id;
  final String userId;
  final String? orderNumber;
  final String? qrCode;
  final String orderType;
  final String status;
  final String? priority;
  final int? idLocationOrigen;
  final int? idLocationDestino;
  final String? responsable;
  final String? observaciones;
  final int totalItems;
  final double totalAmount;
  final Map<String, dynamic> orderDetails;
  final Map<String, dynamic>? direccionEnvio;
  final DateTime createdAt;
  final DateTime updatedAt;

  Order({
    required this.id,
    required this.userId,
    this.orderNumber,
    this.qrCode,
    required this.orderType,
    required this.status,
    this.priority,
    this.idLocationOrigen,
    this.idLocationDestino,
    this.responsable,
    this.observaciones,
    required this.totalItems,
    required this.totalAmount,
    required this.orderDetails,
    this.direccionEnvio,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'],
      userId: json['user_id'],
      orderNumber: json['order_number'],
      qrCode: json['qr_code'],
      orderType: json['order_type'] ?? 'sale',
      status: json['status'] ?? 'completed',
      priority: json['priority'],
      idLocationOrigen: json['id_location_origen'],
      idLocationDestino: json['id_location_destino'],
      responsable: json['responsable'],
      observaciones: json['observaciones'],
      totalItems: json['total_items'] ?? 0,
      totalAmount: (json['total_amount'] ?? 0).toDouble(),
      orderDetails: json['order_details'] ?? {},
      direccionEnvio: json['direccion_envio'] != null
          ? Map<String, dynamic>.from(json['direccion_envio'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'order_number': orderNumber,
      'qr_code': qrCode,
      'order_type': orderType,
      'status': status,
      'priority': priority,
      'id_location_origen': idLocationOrigen,
      'id_location_destino': idLocationDestino,
      'responsable': responsable,
      'observaciones': observaciones,
      'total_items': totalItems,
      'total_amount': totalAmount,
      'order_details': orderDetails,
      'direccion_envio': direccionEnvio,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Métodos auxiliares
  List<Map<String, dynamic>> get items {
    if (orderDetails['items'] != null) {
      return List<Map<String, dynamic>>.from(orderDetails['items']);
    }
    return [];
  }

  // Getter para dirección formateada
  String? get direccionFormateada {
    if (direccionEnvio == null) return null;

    List<String> partes = [];

    if (direccionEnvio!['nombre_contacto'] != null) {
      partes.add(direccionEnvio!['nombre_contacto']);
    }
    if (direccionEnvio!['telefono'] != null) {
      partes.add('Tel: ${direccionEnvio!['telefono']}');
    }
    if (direccionEnvio!['direccion_completa'] != null) {
      partes.add(direccionEnvio!['direccion_completa']);
    }
    if (direccionEnvio!['ciudad'] != null) {
      String ciudad = direccionEnvio!['ciudad'];
      if (direccionEnvio!['departamento'] != null) {
        ciudad += ', ${direccionEnvio!['departamento']}';
      }
      partes.add(ciudad);
    }
    if (direccionEnvio!['referencias'] != null) {
      partes.add('Ref: ${direccionEnvio!['referencias']}');
    }

    return partes.isEmpty ? null : partes.join('\n');
  }

  String get formattedStatus {
    switch (status) {
      case 'pending':
        return 'Pendiente';
      case 'completed':
        return 'Completada';
      case 'cancelled':
        return 'Cancelada';
      default:
        return status;
    }
  }

  String get formattedOrderType {
    switch (orderType) {
      case 'sale':
        return 'Venta';
      case 'purchase':
        return 'Compra';
      case 'entrada':
        return 'Entrada';
      case 'salida':
        return 'Salida';
      case 'transferencia':
        return 'Transferencia';
      case 'ajuste':
        return 'Ajuste';
      default:
        return orderType;
    }
  }
}

// ========================================================================
// MODELO DE ESTADÍSTICAS
// ========================================================================

class OrderStats {
  final int totalOrdenes;
  final int ordenesPendientes;
  final int ordenesCompletadas;
  final int ordenesCanceladas;
  final double ventasTotal;
  final double comprasTotal;
  final int transferenciasTotal;
  final int mesActualOrdenes;
  final double mesActualMonto;

  OrderStats({
    required this.totalOrdenes,
    required this.ordenesPendientes,
    required this.ordenesCompletadas,
    required this.ordenesCanceladas,
    required this.ventasTotal,
    required this.comprasTotal,
    required this.transferenciasTotal,
    required this.mesActualOrdenes,
    required this.mesActualMonto,
  });

  factory OrderStats.fromJson(Map<String, dynamic> json) {
    return OrderStats(
      totalOrdenes: json['total_ordenes'] as int? ?? 0,
      ordenesPendientes: json['ordenes_pendientes'] as int? ?? 0,
      ordenesCompletadas: json['ordenes_completadas'] as int? ?? 0,
      ordenesCanceladas: json['ordenes_canceladas'] as int? ?? 0,
      ventasTotal: (json['ventas_total'] is String)
          ? double.parse(json['ventas_total'])
          : (json['ventas_total'] as num?)?.toDouble() ?? 0.0,
      comprasTotal: (json['compras_total'] is String)
          ? double.parse(json['compras_total'])
          : (json['compras_total'] as num?)?.toDouble() ?? 0.0,
      transferenciasTotal: json['transferencias_total'] as int? ?? 0,
      mesActualOrdenes: json['mes_actual_ordenes'] as int? ?? 0,
      mesActualMonto: (json['mes_actual_monto'] is String)
          ? double.parse(json['mes_actual_monto'])
          : (json['mes_actual_monto'] as num?)?.toDouble() ?? 0.0,
    );
  }
}