// lib/services/restock_service.dart
// VERSIÓN CORREGIDA COMPLETA - Con selección obligatoria de proveedor

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'profile_service.dart';
import 'email_service.dart'; // 🔥 NUEVO: Para enviar emails
import 'package:url_launcher/url_launcher.dart';  // 🔥 AGREGAR ESTA LÍNEA

class RestockService {
  static final SupabaseClient _supabase = AuthService.client;

  /// Obtener todas las solicitudes de restock de la compañía
  static Future<List<Map<String, dynamic>>> getAllRequests({
    String? status,
    String? priority,
  }) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('🔍 RESTOCK: getAllRequests');
        print('   Company ID: $companyId');
      }

      if (companyId == null) {
        if (kDebugMode) print('❌ No company ID');
        return [];
      }

      // Query SIMPLE sin JOINs - todos los datos ya están en restock_requests
      var query = _supabase
          .from('restock_requests')
          .select('*')  // Solo datos de la tabla principal
          .eq('id_company', companyId);

      if (status != null) {
        query = query.eq('status', status);
      }

      if (priority != null) {
        query = query.eq('priority', priority);
      }

      final response = await query.order('fecha_solicitud', ascending: false);

      if (kDebugMode) {
        print('✅ Solicitudes obtenidas: ${response.length}');
        if (response.isNotEmpty) {
          print('   Primera solicitud:');
          print('     - ID: ${response.first['id']}');
          print('     - Producto: ${response.first['nombre_producto']}');
          print('     - Status: ${response.first['status']}');
          print('     - Cantidad: ${response.first['cantidad_solicitada']}');
        }
        print('═══════════════════════════════════════════════');
      }

      return List<Map<String, dynamic>>.from(response);

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ ERROR EN RESTOCK SERVICE');
        print('Error: $e');
        print('Stack: $stackTrace');
      }
      return [];
    }
  }

  /// Obtener solicitudes pendientes
  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    return getAllRequests(status: 'pending');
  }

  /// Obtener solicitudes aprobadas
  static Future<List<Map<String, dynamic>>> getApprovedRequests() async {
    return getAllRequests(status: 'approved');
  }

  /// Obtener detalle de una solicitud específica
  static Future<Map<String, dynamic>?> getRequestById(int requestId) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return null;

      final response = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .eq('id_company', companyId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo detalle: $e');
      return null;
    }
  }

  // =========================================================================
  // CREACIÓN (dispara correo a admins)
  // =========================================================================

  static Future<Map<String, dynamic>> createRestockRequest({
    required int productId,
    required String productName,
    required int requestedQuantity,
    required String priority, // 'low' | 'normal' | 'high' | 'urgent'
    String? notes,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('🆕 createRestockRequest - INICIO');
        print('   productId: $productId');
        print('   productName: $productName');
        print('   requestedQuantity: $requestedQuantity');
        print('   priority: $priority');
      }

      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('No perteneces a ninguna compañía');

      // (Opcional) Traer stock actual para el correo
      final current = await _supabase
          .from('inventario')
          .select('cantidad, imagen, id_supply_company')
          .eq('id_inventario', productId)
          .eq('id_company', companyId)
          .maybeSingle();

      final currentStock = (current?['cantidad'] as int?) ?? 0;
      final imagen = current?['imagen'];
      final supplierId = current?['id_supply_company'];

      // 1) Insertar solicitud
      final insertPayload = {
        'id_company': companyId,
        'id_inventario': productId,
        'nombre_producto': productName,
        'imagen': imagen,
        'stock_actual': currentStock, // 🔥 AGREGADO: campo requerido
        'cantidad_solicitada': requestedQuantity,
        'priority': priority,
        'status': 'pending',
        'user_id': userId,
        'internal_notes': notes,
        'id_supply_company': supplierId, // Proveedor si existe
        'fecha_solicitud': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      final inserted = await _supabase
          .from('restock_requests')
          .insert(insertPayload)
          .select('*')
          .single();

      final requestId = inserted['id'] as int;

      if (kDebugMode) {
        print('✅ Solicitud creada con ID: $requestId');
      }

      // 2) Enviar correos a administradores de la compañía
      try {
        print('📧 Llamando sendRestockRequestToAdmins...');
        await EmailService.sendRestockRequestToAdmins(
          requestId: requestId,
          productId: productId,
          productName: productName,
          requestedQuantity: requestedQuantity,
          currentStock: currentStock,
          priority: priority,
          companyId: companyId,
          notes: notes,
        );
        if (kDebugMode) print('✅ Notificación a admins enviada');
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ La solicitud se creó, pero falló el envío de email: $e');
        }
        // No hacemos throw para no romper el flujo de creación
      }

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('🆕 createRestockRequest - FIN OK');
        print('═══════════════════════════════════════════════');
      }

      return Map<String, dynamic>.from(inserted);
    } catch (e, st) {
      if (kDebugMode) {
        print('❌ ERROR createRestockRequest: $e');
        print(st);
      }
      rethrow;
    }
  }

  // ========================================================================
  // ACCIONES DE ADMIN
  // ========================================================================

  // lib/services/restock_service.dart

  static Future<void> approveRequest({
    required int requestId,
    required int supplierId,
    String? internalNotes,
    DateTime? estimatedDeliveryDate,
  }) async {
    try {
      final isAdmin = await ProfileService.isUserAdmin();
      if (!isAdmin) throw Exception('No tienes permisos de administrador');

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('No perteneces a ninguna compañía');

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('✅ APROBANDO SOLICITUD');
        print('   Request ID: $requestId');
        print('   Supplier ID: $supplierId');
      }

      // 1. Actualizar solicitud a "approved"
      await _supabase
          .from('restock_requests')
          .update({
        'status': 'approved',
        'id_supply_company': supplierId,
        'internal_notes': internalNotes,
        'estimated_delivery_date': estimatedDeliveryDate?.toIso8601String(),
        'fecha_aprobacion': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', requestId)
          .eq('id_company', companyId);

      if (kDebugMode) print('✅ Solicitud actualizada a approved');

      // 🔥 2. GENERAR DEEP LINK PARA EL PROVEEDOR
      final deepLink = 'miatracker://restock/approved/$requestId';
      final qrData = 'miatracker://restock/complete/$requestId';

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📱 INTENTANDO ABRIR APP DEL PROVEEDOR');
        print('   Deep Link: $deepLink');
        print('   Supplier ID: $supplierId');
      }

      // 🔥 3. INTENTAR ABRIR LA APP DEL PROVEEDOR
      bool appOpened = false;

      try {
        final Uri deepLinkUri = Uri.parse(deepLink);

        // Verificar si se puede abrir la app
        if (await canLaunchUrl(deepLinkUri)) {
          await launchUrl(
            deepLinkUri,
            mode: LaunchMode.externalApplication,
          );

          appOpened = true;

          if (kDebugMode) {
            print('✅ App del proveedor abierta exitosamente');
            print('   No se enviará email (app abierta correctamente)');
          }
        } else {
          if (kDebugMode) {
            print('⚠️ No se puede abrir la app del proveedor');
            print('   La app no está instalada o el deep link no está configurado');
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error intentando abrir app: $e');
        }
      }

      // 🔥 4. SI LA APP NO SE ABRIÓ, ENVIAR EMAIL
      if (!appOpened) {
        if (kDebugMode) {
          print('═══════════════════════════════════════════════');
          print('📧 APP NO ABIERTA - ENVIANDO EMAIL DE RESPALDO');
          print('   Motivo: App no instalada o deep link falló');
        }

        try {
          await EmailService.sendApprovalEmailWithQR(
            requestId: requestId,
            supplierId: supplierId,
            deliveryDate: estimatedDeliveryDate,
            internalNotes: internalNotes,
            qrData: qrData,
          );

          if (kDebugMode) {
            print('✅ Email de respaldo enviado exitosamente');
          }
        } catch (emailError) {
          if (kDebugMode) {
            print('❌ Error enviando email de respaldo: $emailError');
          }
          // No relanzar el error - la aprobación ya se guardó en BD
        }
      }

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('✅ PROCESO DE APROBACIÓN COMPLETADO');
        print('   App abierta: ${appOpened ? "SÍ" : "NO"}');
        print('   Email enviado: ${!appOpened ? "SÍ" : "NO (no necesario)"}');
        print('═══════════════════════════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ERROR CRÍTICO en approveRequest: $e');
        print('═══════════════════════════════════════════════');
      }
      rethrow;
    }
  }

// 🔥 MÉTODO AUXILIAR: Notificación de respaldo (opcional - por si quieres usarlo en otro lugar)
  static Future<void> _sendFallbackNotification(
      int requestId,
      int supplierId, {
        DateTime? deliveryDate,
        String? internalNotes,
      }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📧 Enviando notificación de respaldo...');
      }

      final qrData = 'miatracker://restock/complete/$requestId';

      await EmailService.sendApprovalEmailWithQR(
        requestId: requestId,
        supplierId: supplierId,
        deliveryDate: deliveryDate,
        internalNotes: internalNotes ?? 'Aprobación notificada vía sistema',
        qrData: qrData,
      );

      if (kDebugMode) {
        print('✅ Notificación de respaldo enviada exitosamente');
        print('═══════════════════════════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en notificación de respaldo: $e');
        print('═══════════════════════════════════════════════');
      }
    }
  }

  static Future<void> rejectRequest({
    required int requestId,
    required String reason,
  }) async {
    try {
      final isAdmin = await ProfileService.isUserAdmin();
      if (!isAdmin) throw Exception('No tienes permisos');

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('No perteneces a ninguna compañía');

      await _supabase
          .from('restock_requests')
          .update({
        'status': 'rejected',
        'internal_notes': reason,
        'fecha_respuesta': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', requestId)
          .eq('id_company', companyId);

      if (kDebugMode) print('❌ Solicitud rechazada');
    } catch (e) {
      if (kDebugMode) print('❌ Error al rechazar: $e');
      throw Exception('Error al rechazar: $e');
    }
  }

  // lib/services/restock_service.dart

  static Future<void> completeRestockAndUpdateInventory({
    required int requestId,
  }) async {
    try {
      final isAdmin = await ProfileService.isUserAdmin();
      if (!isAdmin) throw Exception('No tienes permisos');

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('No perteneces a ninguna compañía');

      final request = await getRequestById(requestId);
      if (request == null) throw Exception('Solicitud no encontrada');
      if (request['status'] != 'approved') {
        throw Exception('Solo se pueden completar solicitudes aprobadas');
      }

      final productId = request['id_inventario'] as int;
      final cantidad = request['cantidad_solicitada'] as int;

      // 1. Obtener stock actual
      final currentProduct = await _supabase
          .from('inventario')
          .select('cantidad')
          .eq('id_inventario', productId)
          .eq('id_company', companyId)
          .single();

      final currentStock = currentProduct['cantidad'] as int? ?? 0;
      final newStock = currentStock + cantidad;

      // 2. Actualizar inventario
      await _supabase
          .from('inventario')
          .update({
        'cantidad': newStock,
        'fecha_modificacion': DateTime.now().toIso8601String(),
      })
          .eq('id_inventario', productId)
          .eq('id_company', companyId);

      // 3. Actualizar solicitud a "completed"
      final fechaCompletado = DateTime.now();
      await _supabase
          .from('restock_requests')
          .update({
        'status': 'completed',
        'fecha_completado': fechaCompletado.toIso8601String(),
        'updated_at': fechaCompletado.toIso8601String(),
      })
          .eq('id', requestId)
          .eq('id_company', companyId);

      // 4. 🔥 ENVIAR EMAILS AL COMPLETAR (SUPPLY_COMPANY + ADMINS)
      try {
        if (kDebugMode) print('📧 Enviando emails de completado...');

        await EmailService.sendOrderCompletedEmails(
          requestId: requestId,
          companyId: companyId,
        );

        if (kDebugMode) print('✅ Emails de completado enviados');
      } catch (e) {
        if (kDebugMode) print('⚠️ Error enviando emails: $e');
        // No lanzar error - la orden ya se completó
      }

      if (kDebugMode) print('✅ Restock completado exitosamente');
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      throw Exception('Error: $e');
    }
  }

  static Future<void> cancelRequest(int requestId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) throw Exception('No perteneces a ninguna compañía');

      final isAdmin = await ProfileService.isUserAdmin();
      final request = await getRequestById(requestId);

      if (!isAdmin && request?['user_id'] != userId) {
        throw Exception('No tienes permisos');
      }

      await _supabase
          .from('restock_requests')
          .update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', requestId)
          .eq('id_company', companyId);

      if (kDebugMode) print('🚫 Solicitud cancelada');
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      throw Exception('Error: $e');
    }
  }

  // ========================================================================
  // ESTADÍSTICAS
  // ========================================================================

  static Future<Map<String, dynamic>> getRestockStats() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return _emptyStats();

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📊 getRestockStats - Company ID: $companyId');
      }

      final allRequests = await _supabase
          .from('restock_requests')
          .select('status, priority')
          .eq('id_company', companyId);

      if (kDebugMode) {
        print('📊 Total requests found: ${allRequests.length}');
      }

      final stats = {
        'total': allRequests.length,
        'pending': allRequests.where((r) => r['status'] == 'pending').length,
        'approved': allRequests.where((r) => r['status'] == 'approved').length,
        'completed': allRequests.where((r) => r['status'] == 'completed').length,
        'rejected': allRequests.where((r) => r['status'] == 'rejected').length,
        'urgent': allRequests.where((r) => r['priority'] == 'urgent').length,
        'cancelled': allRequests.where((r) => r['status'] == 'cancelled').length,
      };

      if (kDebugMode) {
        print('📊 Stats: $stats');
        print('═══════════════════════════════════════════════');
      }

      return stats;
    } catch (e) {
      if (kDebugMode) print('❌ Error en stats: $e');
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
      'urgent': 0,
      'cancelled': 0,
    };
  }

  // ========================================================================
  // UTILIDADES
  // ========================================================================

  static String getStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending': return 'Pendiente';
      case 'approved': return 'Aprobada';
      case 'rejected': return 'Rechazada';
      case 'completed': return 'Completada';
      case 'cancelled': return 'Cancelada';
      default: return 'Desconocido';
    }
  }

  static String getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending': return '#F59E0B';
      case 'approved': return '#3B82F6';
      case 'rejected': return '#EF4444';
      case 'completed': return '#6B8E3D';
      case 'cancelled': return '#6B7280';
      default: return '#6B7280';
    }
  }

  static String getPriorityText(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low': return 'Baja';
      case 'normal': return 'Normal';
      case 'high': return 'Alta';
      case 'urgent': return 'Urgente';
      default: return 'Normal';
    }
  }

  static String getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low': return '#6B7280';
      case 'normal': return '#3B82F6';
      case 'high': return '#F59E0B';
      case 'urgent': return '#EF4444';
      default: return '#3B82F6';
    }
  }
}