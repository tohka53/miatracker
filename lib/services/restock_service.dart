// lib/services/restock_service.dart
// VERSIÓN CORREGIDA COMPLETA - Con selección obligatoria de proveedor

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'profile_service.dart';
import 'email_service.dart'; // 🔥 NUEVO: Para enviar emails

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
      final requests = List<Map<String, dynamic>>.from(response);

      // 🔗 Enriquecer con solicitante (profiles) y proveedor (supply_company).
      // La query base no trae JOINs, así que resolvemos los nombres aquí en un
      // par de consultas por lote (evita "Unknown Product" / "User" / "N/A").
      await _enrichRequests(requests);

      if (kDebugMode) {
        print('✅ Solicitudes obtenidas: ${requests.length}');
        if (requests.isNotEmpty) {
          final f = requests.first;
          print('   Primera solicitud:');
          print('     - ID: ${f['id']}');
          print('     - Producto: ${f['nombre_producto']}');
          print('     - Solicitante: ${f['requester_name']}');
          print('     - Proveedor: ${f['supplier']?['name'] ?? "—"}');
          print('     - Status: ${f['status']}');
        }
        print('═══════════════════════════════════════════════');
      }

      return requests;

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ ERROR EN RESTOCK SERVICE');
        print('Error: $e');
        print('Stack: $stackTrace');
      }
      return [];
    }
  }

  /// Enriquecer solicitudes con el nombre del solicitante y los datos del
  /// proveedor. Hace 2 consultas por lote (profiles + supply_company) en vez de
  /// N JOINs, y adjunta a cada request:
  ///   - requester_name : String
  ///   - supplier        : {id, name, email, phone} | null
  ///   - has_supplier    : bool
  ///   - item_number     : String | null  (código de barras del producto)
  static Future<void> _enrichRequests(List<Map<String, dynamic>> requests) async {
    if (requests.isEmpty) return;

    // IDs únicos
    final userIds = requests
        .map((r) => r['user_id'])
        .where((v) => v != null)
        .map((v) => v.toString())
        .toSet()
        .toList();

    final supplierIds = requests
        .map((r) => r['id_supply_company'])
        .where((v) => v != null)
        .toSet()
        .toList();

    final productIds = requests
        .map((r) => r['id_inventario'])
        .where((v) => v != null)
        .toSet()
        .toList();

    // Solicitantes (profiles)
    final Map<String, Map<String, dynamic>> profilesById = {};
    if (userIds.isNotEmpty) {
      try {
        final profs = await _supabase
            .from('profiles')
            .select('id, full_name, username')
            .inFilter('id', userIds);
        for (final p in profs) {
          profilesById[p['id'].toString()] = Map<String, dynamic>.from(p);
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ No se pudieron cargar perfiles: $e');
      }
    }

    // Proveedores (supply_company)
    final Map<String, Map<String, dynamic>> suppliersById = {};
    if (supplierIds.isNotEmpty) {
      try {
        final sups = await _supabase
            .from('supply_company')
            .select('id, name, email, phone')
            .inFilter('id', supplierIds);
        for (final s in sups) {
          suppliersById[s['id'].toString()] = Map<String, dynamic>.from(s);
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ No se pudieron cargar proveedores: $e');
      }
    }

    // Item Number = código de barras del producto. Es la referencia que viaja
    // en los correos; se muestra también en pantalla para que coincidan.
    final Map<String, String?> itemNumbersByProduct = {};
    if (productIds.isNotEmpty) {
      try {
        final prods = await _supabase
            .from('inventario')
            .select('id_inventario, codigo_barras')
            .inFilter('id_inventario', productIds);
        for (final prod in prods) {
          itemNumbersByProduct[prod['id_inventario'].toString()] =
              EmailService.extractItemNumber(prod['codigo_barras']);
        }
      } catch (e) {
        if (kDebugMode) print('⚠️ No se pudieron cargar los códigos de barras: $e');
      }
    }

    // Adjuntar a cada solicitud
    for (final r in requests) {
      final prof = profilesById[r['user_id']?.toString()];
      r['requester_name'] =
          prof?['full_name'] ?? prof?['username'] ?? 'User';

      final sup = suppliersById[r['id_supply_company']?.toString()];
      r['supplier'] = sup; // {id, name, email, phone} | null
      r['has_supplier'] = sup != null;

      r['item_number'] = itemNumbersByProduct[r['id_inventario']?.toString()];
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

      if (response == null) return null;

      final enriched = [Map<String, dynamic>.from(response)];
      await _enrichRequests(enriched);
      return enriched.first;
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
        // `notes` = lo que escribe el solicitante (lo que lee la pantalla de
        // detalle). `internal_notes` queda reservado para el admin al aprobar
        // o rechazar; antes se pisaban entre sí.
        'notes': notes,
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

      // 2) Notificar a los tres: solicitante, jefe/admins y proveedor
      try {
        await EmailService.notifyRestockCreated(
          requestId: requestId,
          companyId: companyId,
          requesterUserId: userId,
          productName: productName,
          requestedQuantity: requestedQuantity,
          currentStock: currentStock,
          priority: priority,
          supplierId: supplierId as int?,
          notes: notes,
          productId: productId, // -> Item Number (código de barras) en el correo
        );
        if (kDebugMode) print('✅ Notificaciones enviadas');
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

      // 2. 📧 NOTIFICAR A LOS TRES: proveedor (con QR), solicitante y jefe/admins.
      //
      // NOTA: aquí antes se intentaba abrir `miatracker://restock/approved/...`
      // con canLaunchUrl y SOLO se mandaba correo si la app no abría. Ese
      // esquema nunca estuvo registrado (AndroidManifest e Info.plist solo
      // declaran `io.supabase.miatracker`), así que era código muerto que
      // además hacía el envío condicional. El correo ahora sale siempre.
      final notified = await EmailService.notifyRestockApproved(
        requestId: requestId,
        supplierId: supplierId,
        companyId: companyId,
        deliveryDate: estimatedDeliveryDate,
        internalNotes: internalNotes,
      );

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('✅ PROCESO DE APROBACIÓN COMPLETADO');
        print('   Correo al proveedor  : ${notified['supplier'] == true ? "SÍ" : "NO"}');
        print('   Correo al solicitante: ${notified['requester'] == true ? "SÍ" : "NO"}');
        print('   Correo al jefe/admins: ${notified['admins'] == true ? "SÍ" : "NO"}');
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

      // 📧 Notificar a los tres (solicitante, jefe/admins y proveedor).
      try {
        await EmailService.notifyRestockRejected(
          requestId: requestId,
          companyId: companyId,
          reason: reason,
        );
      } catch (e) {
        if (kDebugMode) print('⚠️ Rechazo guardado, pero falló el envío: $e');
      }
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
      case 'pending': return 'Pending';
      case 'approved': return 'Approved';
      case 'rejected': return 'Rejected';
      case 'completed': return 'Completed';
      case 'cancelled': return 'Cancelled';
      default: return 'Unknown';
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
      case 'low': return 'Low';
      case 'normal': return 'Normal';
      case 'high': return 'High';
      case 'urgent': return 'Urgent';
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