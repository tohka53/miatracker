// lib/services/restock_request_service.dart
// SERVICIO PARA CREAR Y VALIDAR SOLICITUDES DE RESTOCK

import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'email_service.dart'; // ⬅️ NUEVO IMPORT

class RestockRequestService {
  static final _supabase = AuthService.client;

  // ========================================================================
  // VALIDAR ANTES DE CREAR SOLICITUD
  // ========================================================================

  static Future<Map<String, dynamic>> validateBeforeCreating({
    required int productId,
    required int requestedQuantity,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) {
        return {
          'valid': false,
          'error': 'Usuario no autenticado',
        };
      }

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        return {
          'valid': false,
          'error': 'Usuario no pertenece a ninguna compaÃ±Ã­a',
        };
      }

      // Verificar que el producto existe y pertenece a la compaÃ±Ã­a
      final product = await _supabase
          .from('inventario')
          .select('id_inventario, nombre_producto, cantidad, id_supply_company')
          .eq('id_inventario', productId)
          .eq('id_company', companyId)
          .maybeSingle();

      if (product == null) {
        return {
          'valid': false,
          'error': 'Producto no encontrado o no pertenece a tu compaÃ±Ã­a',
        };
      }

      // Verificar si hay solicitudes pendientes para este producto
      final pendingRequests = await _supabase
          .from('restock_requests')
          .select('id')
          .eq('id_inventario', productId)
          .eq('id_company', companyId)
          .eq('status', 'pending')
          .limit(1);

      if (pendingRequests.isNotEmpty) {
        return {
          'valid': false,
          'warning': true,
          'error': 'Ya existe una solicitud pendiente para este producto',
        };
      }

      // Todo estÃ¡ bien
      return {
        'valid': true,
        'product': product,
        'has_supplier': product['id_supply_company'] != null,
      };

    } catch (e) {
      if (kDebugMode) print('âŒ Error validando: $e');
      return {
        'valid': false,
        'error': 'Error al validar: $e',
      };
    }
  }

  // ========================================================================
  // CREAR SOLICITUD DE RESTOCK
  // ========================================================================


  static Future<Map<String, dynamic>> createRestockRequest({
    required int productId,
    required int requestedQuantity,
    String priority = 'medium',
    String? notes,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      final companyId = await InventoryService.getCurrentCompanyId();

      if (userId == null || companyId == null) {
        return {'success': false, 'error': 'Usuario no autenticado'};
      }

      // Obtener datos del producto
      final product = await _supabase
          .from('inventario')
          .select('nombre_producto, imagen, image_url, cantidad, id_supply_company')
          .eq('id_inventario', productId)
          .eq('id_company', companyId)
          .single();

      final imagenUrl = product['image_url'] ?? product['imagen'];
      final supplierId = product['id_supply_company'];

      // 🔥 FECHA AUTOMÁTICA: Usar DateTime.now() sin pedirla
      final fechaSolicitud = DateTime.now();

      // Crear la solicitud
      final response = await _supabase
          .from('restock_requests')
          .insert({
        'user_id': userId,
        'id_company': companyId,
        'id_inventario': productId,
        'id_supply_company': supplierId,
        'nombre_producto': product['nombre_producto'],
        'imagen': imagenUrl,
        'stock_actual': product['cantidad'],
        'cantidad_solicitada': requestedQuantity,
        'priority': priority,
        'notes': notes,
        'status': 'pending',
        'fecha_solicitud': fechaSolicitud.toIso8601String(), // 🔥 AUTOMÁTICO
      })
          .select()
          .single();

      if (kDebugMode) print('✅ Solicitud creada con fecha: $fechaSolicitud');

      // 🔥 NOTIFICAR A LOS TRES: solicitante, jefe/admins y proveedor
      try {
        await EmailService.notifyRestockCreated(
          requestId: response['id'] as int,
          companyId: companyId,
          requesterUserId: userId,
          productName: (product['nombre_producto'] ?? 'Producto').toString(),
          requestedQuantity: requestedQuantity,
          currentStock: (product['cantidad'] as int?) ?? 0,
          priority: priority,
          supplierId: supplierId as int?,
          notes: notes,
          productId: productId, // -> Item Number (código de barras) en el correo
        );
      } catch (e) {
        if (kDebugMode) print('⚠️ Error enviando correos: $e');
      }

      return {
        'success': true,
        'message': 'Restock request sent',
        'request_id': response['id'],
        'has_supplier': supplierId != null,
      };

    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      return {'success': false, 'error': 'Error: $e'};
    }
  }

  // ========================================================================
  // OBTENER MIS SOLICITUDES
  // ========================================================================

  static Future<List<Map<String, dynamic>>> getMyRequests({
    String? status,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return [];

      var query = _supabase
          .from('restock_requests')
          .select('''
            *,
            inventario!restock_requests_id_inventario_fkey (
              nombre_producto,
              imagen,
              cantidad
            ),
            supply_company!restock_requests_id_supply_company_fkey (
              name,
              email
            )
          ''')
          .eq('user_id', userId)
          .eq('id_company', companyId);

      if (status != null) {
        query = query.eq('status', status);
      }

      // .order() debe ir al final, y se ejecuta con await
      final response = await query
          .order('fecha_solicitud', ascending: false);

      return List<Map<String, dynamic>>.from(response);

    } catch (e) {
      if (kDebugMode) print('âŒ Error obteniendo solicitudes: $e');
      return [];
    }
  }

  // ========================================================================
  // CANCELAR MI SOLICITUD
  // ========================================================================

  static Future<Map<String, dynamic>> cancelMyRequest(int requestId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) {
        return {
          'success': false,
          'error': 'Usuario no autenticado',
        };
      }

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        return {
          'success': false,
          'error': 'Usuario no pertenece a ninguna compaÃ±Ã­a',
        };
      }

      // Verificar que la solicitud existe y pertenece al usuario
      final request = await _supabase
          .from('restock_requests')
          .select('id, status')
          .eq('id', requestId)
          .eq('user_id', userId)
          .eq('id_company', companyId)
          .maybeSingle();

      if (request == null) {
        return {
          'success': false,
          'error': 'Solicitud no encontrada',
        };
      }

      if (request['status'] != 'pending') {
        return {
          'success': false,
          'error': 'Solo se pueden cancelar solicitudes pendientes',
        };
      }

      // Cancelar la solicitud
      await _supabase
          .from('restock_requests')
          .update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', requestId);

      if (kDebugMode) print('âœ… Solicitud cancelada');

      return {
        'success': true,
        'message': 'Solicitud cancelada exitosamente',
      };

    } catch (e) {
      if (kDebugMode) print('âŒ Error cancelando solicitud: $e');
      return {
        'success': false,
        'error': 'Error al cancelar: $e',
      };
    }
  }

  // ========================================================================
  // ESTADÃSTICAS
  // ========================================================================

  static Future<Map<String, dynamic>> getMyStats() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return _emptyStats();

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return _emptyStats();

      final requests = await _supabase
          .from('restock_requests')
          .select('status, priority')
          .eq('user_id', userId)
          .eq('id_company', companyId);

      final stats = {
        'total': requests.length,
        'pending': requests.where((r) => r['status'] == 'pending').length,
        'approved': requests.where((r) => r['status'] == 'approved').length,
        'completed': requests.where((r) => r['status'] == 'completed').length,
        'rejected': requests.where((r) => r['status'] == 'rejected').length,
        'cancelled': requests.where((r) => r['status'] == 'cancelled').length,
        'urgent': requests.where((r) => r['priority'] == 'urgent').length,
      };

      return stats;

    } catch (e) {
      if (kDebugMode) print('âŒ Error obteniendo estadÃ­sticas: $e');
      return _emptyStats();
    }
  }

  static Map<String, dynamic> _emptyStats() {
    return {
      'total': 0,
      'pending': 0,
      'approved': 0,
      'completed': 0,
      'rejected': 0,
      'cancelled': 0,
      'urgent': 0,
    };
  }

  // ========================================================================
  // UTILIDADES
  // ========================================================================

  static String getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Desconocido';
    }
  }

  static String getPriorityText(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low':
        return 'Baja';
      case 'medium':
        return 'Media';
      case 'high':
        return 'Alta';
      case 'urgent':
        return 'Urgente';
      default:
        return 'Media';
    }
  }
}