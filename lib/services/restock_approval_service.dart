// lib/services/restock_approval_service.dart
// SERVICIO COMPLETO DE APROBACIÓN CON ASIGNACIÓN AUTOMÁTICA DE PROVEEDOR

import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'profile_service.dart';
import 'email_service.dart';

class RestockApprovalService {
  static final _supabase = AuthService.client;

  // ========================================================================
  // APROBAR SOLICITUD (CON ASIGNACIÓN AUTOMÁTICA DE PROVEEDOR)
  // ========================================================================

  static Future<Map<String, dynamic>> approveRequest({
    required int requestId,
    String? internalNotes,
    DateTime? estimatedDeliveryDate,
    bool autoAssignSupplier = true, // ✅ Por defecto SÍ asigna automáticamente
  }) async {
    try {
      if (kDebugMode) {
        print('\n🚀 ===== INICIANDO APROBACIÓN DE SOLICITUD =====');
        print('   Request ID: $requestId');
        print('   Auto-asignar proveedor: $autoAssignSupplier');
        print('===============================================\n');
      }

      // PASO 1: VERIFICAR PERMISOS DE ADMIN
      final isAdmin = await ProfileService.isUserAdmin();
      if (!isAdmin) {
        return {
          'success': false,
          'error': 'No tienes permisos de administrador',
        };
      }

      // PASO 2: OBTENER COMPANY ID
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        return {
          'success': false,
          'error': 'No perteneces a ninguna compañía',
        };
      }

      // PASO 3: OBTENER DATOS DE LA SOLICITUD
      final requestData = await _getRequestWithDetails(requestId, companyId);
      if (requestData == null) {
        return {
          'success': false,
          'error': 'Solicitud no encontrada',
        };
      }

      if (kDebugMode) {
        print('📋 Solicitud encontrada:');
        print('   Producto: ${requestData['nombre_producto']}');
        print('   Cantidad: ${requestData['cantidad_solicitada']}');
        print('   ID Inventario: ${requestData['id_inventario']}');
        print('   ID Supply Company actual: ${requestData['id_supply_company']}');
      }

      // PASO 4: VALIDAR ESTADO DE LA SOLICITUD
      if (requestData['status'] == 'approved') {
        return {
          'success': false,
          'error': 'La solicitud ya está aprobada',
        };
      }

      if (requestData['status'] == 'completed') {
        return {
          'success': false,
          'error': 'La solicitud ya está completada',
        };
      }

      // PASO 5: VERIFICAR SI TIENE PROVEEDOR ASIGNADO
      final currentSupplierId = requestData['id_supply_company'];
      final productId = requestData['id_inventario'];

      Map<String, dynamic>? supplierData;
      bool supplierWasAssigned = false;

      if (currentSupplierId == null) {
        if (kDebugMode) {
          print('\n⚠️ PRODUCTO SIN PROVEEDOR ASIGNADO');
          print('   Auto-asignar está ${autoAssignSupplier ? 'ACTIVADO' : 'DESACTIVADO'}');
        }

        if (!autoAssignSupplier) {
          // Si autoAssignSupplier es false, retornar indicando que falta proveedor
          return {
            'success': false,
            'needs_supplier': true,
            'product_id': productId,
            'product_name': requestData['nombre_producto'],
            'error': 'El producto no tiene proveedor asignado. Por favor asigna uno antes de aprobar.',
          };
        }

        // PASO 5A: OBTENER PROVEEDORES DISPONIBLES
        if (kDebugMode) print('🔍 Buscando proveedores disponibles...');

        final availableSuppliers = await _getAvailableSuppliers(companyId);

        if (availableSuppliers.isEmpty) {
          return {
            'success': false,
            'needs_supplier': true,
            'product_id': productId,
            'product_name': requestData['nombre_producto'],
            'error': 'No hay proveedores disponibles. Crea un proveedor primero.',
          };
        }

        // PASO 5B: ASIGNAR AUTOMÁTICAMENTE EL PRIMER PROVEEDOR
        supplierData = availableSuppliers.first;
        final supplierId = supplierData['id'];

        if (kDebugMode) {
          print('✅ Asignando proveedor automáticamente:');
          print('   ID: $supplierId');
          print('   Nombre: ${supplierData['name']}');
          print('   Email: ${supplierData['email']}');
        }

        // Asignar proveedor al producto
        await _assignSupplierToProduct(productId, supplierId, companyId);

        // Actualizar también la solicitud
        await _supabase
            .from('restock_requests')
            .update({'id_supply_company': supplierId})
            .eq('id', requestId)
            .eq('id_company', companyId);

        supplierWasAssigned = true;

        if (kDebugMode) {
          print('✅ Proveedor asignado exitosamente al producto y solicitud');
        }
      } else {
        // Ya tiene proveedor asignado
        if (kDebugMode) {
          print('✅ Producto ya tiene proveedor asignado: $currentSupplierId');
        }

        // Obtener datos del proveedor
        supplierData = await _supabase
            .from('supply_company')
            .select('*')
            .eq('id', currentSupplierId)
            .eq('id_company', companyId)
            .maybeSingle();

        if (supplierData == null) {
          return {
            'success': false,
            'error': 'El proveedor asignado no existe o no pertenece a tu compañía',
          };
        }
      }

      // PASO 6: ACTUALIZAR ESTADO DE LA SOLICITUD A "APPROVED"
      if (kDebugMode) print('\n📝 Actualizando solicitud a estado APPROVED...');

      final updates = <String, dynamic>{
        'status': 'approved',
        'internal_notes': internalNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (estimatedDeliveryDate != null) {
        updates['estimated_delivery_date'] = estimatedDeliveryDate.toIso8601String();
      }

      await _supabase
          .from('restock_requests')
          .update(updates)
          .eq('id', requestId)
          .eq('id_company', companyId);

      if (kDebugMode) print('✅ Solicitud actualizada a APPROVED');

      // PASO 7: NOTIFICAR A LOS TRES (proveedor con QR, solicitante y jefe)
      final result = <String, dynamic>{
        'success': true,
        'message': 'Solicitud aprobada exitosamente',
        'supplier_was_assigned': supplierWasAssigned,
        'supplier_name': supplierData['name'],
        'supplier_id': supplierData['id'],
        'has_email': false,
        'email_sent': false,
      };

      final supplierEmail = supplierData['email'];
      result['has_email'] =
          supplierEmail is String && supplierEmail.trim().isNotEmpty;

      final notified = await EmailService.notifyRestockApproved(
        requestId: requestId,
        supplierId: supplierData['id'] as int,
        companyId: companyId,
        deliveryDate: estimatedDeliveryDate,
        internalNotes: internalNotes,
      );

      result['email_sent'] = notified['supplier'] == true;
      result['notified_requester'] = notified['requester'] == true;
      result['notified_admins'] = notified['admins'] == true;
      result['supplier_email'] = supplierEmail;

      if (result['has_email'] != true) {
        result['warning'] =
        'Solicitud aprobada pero el proveedor no tiene email configurado';
      }

      if (kDebugMode) {
        print('\n✅ ===== APROBACIÓN COMPLETADA =====');
        print('   Proveedor asignado : ${result['supplier_was_assigned']}');
        print('   Correo proveedor   : ${result['email_sent']}');
        print('   Correo solicitante : ${result['notified_requester']}');
        print('   Correo jefe/admins : ${result['notified_admins']}');
        print('===================================\n');
      }

      return result;

    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('\n❌ ===== ERROR EN APROBACIÓN =====');
        print('   Error: $e');
        print('   Stack: $stackTrace');
        print('==================================\n');
      }

      return {
        'success': false,
        'error': 'Error al aprobar solicitud: $e',
      };
    }
  }

  // ========================================================================
  // RECHAZAR SOLICITUD
  // ========================================================================

  static Future<Map<String, dynamic>> rejectRequest({
    required int requestId,
    required String reason,
    int? supplierId, // ✅ AGREGADO: Proveedor opcional
  }) async {
    try {
      final isAdmin = await ProfileService.isUserAdmin();
      if (!isAdmin) {
        return {
          'success': false,
          'error': 'No tienes permisos de administrador',
        };
      }

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        return {
          'success': false,
          'error': 'No perteneces a ninguna compañía',
        };
      }

      // Obtener datos de la solicitud
      final requestData = await _getRequestWithDetails(requestId, companyId);
      if (requestData == null) {
        return {
          'success': false,
          'error': 'Solicitud no encontrada',
        };
      }

      if (kDebugMode) {
        print('\n❌ ===== RECHAZANDO SOLICITUD =====');
        print('   Request ID: $requestId');
        print('   Motivo: $reason');
        print('   Supplier ID recibido: $supplierId');
        print('   Supplier ID en solicitud: ${requestData['id_supply_company']}');
      }

      // Actualizar estado
      await _supabase
          .from('restock_requests')
          .update({
        'status': 'rejected',
        'internal_notes': reason,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', requestId)
          .eq('id_company', companyId);

      if (kDebugMode) print('✅ Solicitud actualizada a REJECTED');

      final result = <String, dynamic>{
        'success': true,
        'message': 'Solicitud rechazada',
        'email_sent': false,
      };

      // Determinar qué supplier ID usar
      final finalSupplierId = supplierId ?? requestData['id_supply_company'];

      if (kDebugMode) {
        print('   Supplier ID final: $finalSupplierId');
      }

      // 📧 Notificar a los tres: solicitante (con el motivo), jefe/admins y
      // proveedor. Antes solo se avisaba al proveedor, y si no había proveedor
      // no salía ningún correo: quien pidió la orden nunca se enteraba.
      final notified = await EmailService.notifyRestockRejected(
        requestId: requestId,
        companyId: companyId,
        reason: reason,
        supplierId: finalSupplierId as int?,
      );

      result['email_sent'] = notified['supplier'] == true;
      result['notified_requester'] = notified['requester'] == true;
      result['notified_admins'] = notified['admins'] == true;

      if (finalSupplierId == null) {
        result['warning'] =
        'Solicitud rechazada; no hay proveedor asignado al que notificar';
      } else if (notified['supplier'] != true) {
        result['warning'] =
        'Solicitud rechazada pero no se pudo notificar al proveedor';
      }

      if (kDebugMode) {
        print('   Correo proveedor   : ${result['email_sent']}');
        print('   Correo solicitante : ${result['notified_requester']}');
        print('   Correo jefe/admins : ${result['notified_admins']}');
        print('===================================\n');
      }

      return result;

    } catch (e) {
      if (kDebugMode) print('❌ Error rechazando solicitud: $e');
      return {
        'success': false,
        'error': 'Error al rechazar: $e',
      };
    }
  }

  // ========================================================================
  // MÉTODOS PRIVADOS
  // ========================================================================

  static Future<Map<String, dynamic>?> _getRequestWithDetails(
      int requestId, int companyId) async {
    try {
      final response = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .eq('id_company', companyId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo solicitud: $e');
      return null;
    }
  }

  static Future<List<Map<String, dynamic>>> _getAvailableSuppliers(
      int companyId) async {
    try {
      final response = await _supabase
          .from('supply_company')
          .select('*')
          .eq('id_company', companyId)
          .eq('status', 1)
          .order('name');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo proveedores: $e');
      return [];
    }
  }

  static Future<void> _assignSupplierToProduct(
      int productId, int supplierId, int companyId) async {
    try {
      await _supabase
          .from('inventario')
          .update({'id_supply_company': supplierId})
          .eq('id_inventario', productId)
          .eq('id_company', companyId);

      if (kDebugMode) {
        print('✅ Proveedor $supplierId asignado al producto $productId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error asignando proveedor: $e');
      throw Exception('Error asignando proveedor: $e');
    }
  }

  // ========================================================================
  // OBTENER SOLICITUD POR ID
  // ========================================================================

  static Future<Map<String, dynamic>?> getRequestById(int requestId) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return null;

      final response = await _supabase
          .from('restock_requests')
          .select('''
            *,
            inventario!restock_requests_id_inventario_fkey (
              id_inventario,
              nombre_producto,
              imagen,
              cantidad,
              id_supply_company
            ),
            supply_company!restock_requests_id_supply_company_fkey (
              id,
              name,
              email,
              phone
            )
          ''')
          .eq('id', requestId)
          .eq('id_company', companyId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo solicitud: $e');
      return null;
    }
  }

  // ========================================================================
  // OBTENER TODAS LAS SOLICITUDES
  // ========================================================================

  static Future<List<Map<String, dynamic>>> getAllRequests() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return [];

      final response = await _supabase
          .from('restock_requests')
          .select('''
            *,
            inventario!restock_requests_id_inventario_fkey (
              nombre_producto,
              imagen
            ),
            supply_company!restock_requests_id_supply_company_fkey (
              name,
              email
            )
          ''')
          .eq('id_company', companyId)
          .order('fecha_solicitud', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo solicitudes: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getPendingRequests() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return [];

      final response = await _supabase
          .from('restock_requests')
          .select('''
            *,
            inventario!restock_requests_id_inventario_fkey (
              nombre_producto,
              imagen
            ),
            supply_company!restock_requests_id_supply_company_fkey (
              name,
              email
            )
          ''')
          .eq('id_company', companyId)
          .eq('status', 'pending')
          .order('fecha_solicitud', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo solicitudes pendientes: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> getApprovedRequests() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return [];

      final response = await _supabase
          .from('restock_requests')
          .select('''
            *,
            inventario!restock_requests_id_inventario_fkey (
              nombre_producto,
              imagen
            ),
            supply_company!restock_requests_id_supply_company_fkey (
              name,
              email
            )
          ''')
          .eq('id_company', companyId)
          .eq('status', 'approved')
          .order('fecha_solicitud', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo solicitudes aprobadas: $e');
      return [];
    }
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

  static String getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return '#F59E0B';
      case 'approved':
        return '#3B82F6';
      case 'rejected':
        return '#EF4444';
      case 'completed':
        return '#6B8E3D';
      case 'cancelled':
        return '#6B7280';
      default:
        return '#6B7280';
    }
  }

  static String getPriorityText(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low':
        return 'Baja';
      case 'normal':
        return 'Normal';
      case 'high':
        return 'Alta';
      case 'urgent':
        return 'Urgente';
      default:
        return 'Normal';
    }
  }

  static String getPriorityColor(String? priority) {
    switch (priority?.toLowerCase()) {
      case 'low':
        return '#10B981';
      case 'normal':
        return '#3B82F6';
      case 'high':
        return '#F59E0B';
      case 'urgent':
        return '#EF4444';
      default:
        return '#3B82F6';
    }
  }
}