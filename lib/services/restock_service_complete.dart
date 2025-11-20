// lib/services/restock_service_complete.dart
// SERVICIO COMPLETO DE RESTOCK CON TODAS LAS FUNCIONALIDADES

import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'inventory_service.dart';
import 'profile_service.dart';
import 'email_service.dart';

class RestockServiceComplete {
  static final _supabase = AuthService.client;

  // ========================================================================
  // VALIDAR SOLICITUD ANTES DE APROBAR
  // ========================================================================

  static Future<Map<String, dynamic>> validateRestockRequest(
      int requestId) async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        return {
          'valid': false,
          'error': 'No perteneces a ninguna compañía',
        };
      }

      // Obtener la solicitud con todos los datos necesarios
      final request = await _supabase
          .from('restock_requests')
          .select('''
            *,
            inventario!restock_requests_id_inventario_fkey (
              id_inventario,
              nombre_producto,
              id_supply_company
            ),
            supply_company!restock_requests_id_supply_company_fkey (
              id,
              name,
              email
            )
          ''')
          .eq('id', requestId)
          .eq('id_company', companyId)
          .maybeSingle();

      if (request == null) {
        return {
          'valid': false,
          'error': 'Solicitud no encontrada',
        };
      }

      if (request['status'] == 'approved') {
        return {
          'valid': false,
          'error': 'La solicitud ya está aprobada',
        };
      }

      if (request['status'] == 'completed') {
        return {
          'valid': false,
          'error': 'La solicitud ya está completada',
        };
      }

      final inventario = request['inventario'] as Map<String, dynamic>?;
      final supplier = request['supply_company'] as Map<String, dynamic>?;

      final hasSupplier = supplier != null && supplier['id'] != null;
      final hasEmail = supplier?['email'] != null &&
          (supplier!['email'] as String).isNotEmpty;

      return {
        'valid': true,
        'request': request,
        'product_id': inventario?['id_inventario'],
        'product_name': inventario?['nombre_producto'],
        'has_supplier': hasSupplier,
        'has_email': hasEmail,
        'supplier_id': supplier?['id'],
        'supplier_name': supplier?['name'],
        'supplier_email': supplier?['email'],
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error validando solicitud: $e');
      return {
        'valid': false,
        'error': 'Error al validar: $e',
      };
    }
  }

  // ========================================================================
  // APROBAR Y ENVIAR EMAIL
  // ========================================================================

  static Future<Map<String, dynamic>> approveRequestAndSendEmail({
    required int requestId,
    String? internalNotes,
    DateTime? estimatedDeliveryDate,
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

      // Validar primero
      final validation = await validateRestockRequest(requestId);
      if (validation['valid'] != true) {
        return {
          'success': false,
          'error': validation['error'],
        };
      }

      // Obtener nombre de la compañía
      final companyInfo = await _supabase
          .from('companies')
          .select('name')
          .eq('id', companyId)
          .single();

      final companyName = companyInfo['name'] ?? 'Tu Compañía';

      // Actualizar estado en la base de datos
      final updates = <String, dynamic>{
        'status': 'approved',
        'internal_notes': internalNotes,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (estimatedDeliveryDate != null) {
        updates['estimated_delivery_date'] =
            estimatedDeliveryDate.toIso8601String();
      }

      await _supabase
          .from('restock_requests')
          .update(updates)
          .eq('id', requestId)
          .eq('id_company', companyId);

      // Preparar resultado
      final result = <String, dynamic>{
        'success': true,
        'message': 'Solicitud aprobada exitosamente',
        'has_email': validation['has_email'] == true,
      };

      // Intentar enviar email si tiene proveedor con email
      if (validation['has_email'] == true) {
        final request = validation['request'] as Map<String, dynamic>;
        final supplierEmail = validation['supplier_email'] as String;
        final supplierName = validation['supplier_name'] ?? 'Proveedor';
        final productName = validation['product_name'] ?? 'Producto';
        final quantity = request['cantidad_solicitada'] ?? 0;

        if (kDebugMode) {
          print('📧 Intentando enviar email...');
          print('   Proveedor: $supplierName');
          print('   Email: $supplierEmail');
        }

        // ✅ USAR EL MÉTODO CORRECTO
        final emailResult = await EmailService.sendApprovalEmail(
          toEmail: supplierEmail,
          supplierName: supplierName,
          productName: productName,
          quantity: quantity,
          companyName: companyName,
          internalNotes: internalNotes,
          estimatedDeliveryDate: estimatedDeliveryDate?.toIso8601String(),
        );

        result['email_sent'] = emailResult['success'] == true;
        result['supplier_email'] = supplierEmail;
        result['supplier_name'] = supplierName;

        if (emailResult['success'] != true) {
          result['email_error'] = emailResult['error'];
          if (kDebugMode) {
            print('⚠️ Email no enviado: ${emailResult['error']}');
          }
        } else {
          if (kDebugMode) print('✅ Email enviado exitosamente');
        }
      } else {
        if (kDebugMode) print('⚠️ No hay email del proveedor para enviar');
      }

      return result;
    } catch (e) {
      if (kDebugMode) print('❌ Error aprobando solicitud: $e');
      return {
        'success': false,
        'error': 'Error al aprobar: $e',
      };
    }
  }

  // ========================================================================
  // RECHAZAR Y ENVIAR EMAIL
  // ========================================================================

  static Future<Map<String, dynamic>> rejectRequestAndSendEmail({
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
      final validation = await validateRestockRequest(requestId);

      if (kDebugMode) {
        print('\n❌ ===== RECHAZANDO SOLICITUD =====');
        print('   Request ID: $requestId');
        print('   Motivo: $reason');
        print('   Supplier ID recibido: $supplierId');
        print('   Supplier ID en validación: ${validation['supplier_id']}');
      }

      // Obtener nombre de la compañía
      final companyInfo = await _supabase
          .from('companies')
          .select('name')
          .eq('id', companyId)
          .single();

      final companyName = companyInfo['name'] ?? 'Tu Compañía';

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
        'has_email': false,
        'email_sent': false,
      };

      // Determinar qué supplier ID usar
      final finalSupplierId = supplierId ?? validation['supplier_id'];

      if (kDebugMode) {
        print('   Supplier ID final: $finalSupplierId');
      }

      // Intentar enviar email si tiene proveedor con email
      if (finalSupplierId != null) {
        final supplierData = await _supabase
            .from('supply_company')
            .select('*')
            .eq('id', finalSupplierId)
            .eq('id_company', companyId)
            .maybeSingle();

        if (supplierData != null && supplierData['email'] != null && (supplierData['email'] as String).isNotEmpty) {
          result['has_email'] = true;

          if (kDebugMode) {
            print('📧 Enviando email de rechazo...');
            print('   Email: ${supplierData['email']}');
            print('   Proveedor: ${supplierData['name']}');
          }

          final request = validation['request'] as Map<String, dynamic>?;
          final productName = validation['product_name'] ?? 'Producto';
          final quantity = request?['cantidad_solicitada'] ?? 0;

          final emailResult = await EmailService.sendRejectionEmail(
            toEmail: supplierData['email'],
            supplierName: supplierData['name'] ?? 'Proveedor',
            productName: productName,
            quantity: quantity,
            companyName: companyName,
            rejectionReason: reason,
          );

          result['email_sent'] = emailResult['success'] == true;
          result['supplier_email'] = supplierData['email'];
          result['supplier_name'] = supplierData['name'];

          if (emailResult['success'] != true) {
            result['email_error'] = emailResult['error'];
            if (kDebugMode) print('⚠️ Error enviando email: ${emailResult['error']}');
          } else {
            if (kDebugMode) print('✅ Email de rechazo enviado');
          }
        } else {
          if (kDebugMode) print('⚠️ Proveedor sin email configurado');
          result['warning'] = 'Solicitud rechazada pero el proveedor no tiene email';
        }
      } else {
        if (kDebugMode) print('⚠️ No hay proveedor asignado para enviar email');
        result['warning'] = 'Solicitud rechazada pero no hay proveedor para notificar';
      }

      if (kDebugMode) {
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
  // ESTADÍSTICAS
  // ========================================================================

  static Future<Map<String, dynamic>> getRestockStats() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return _emptyStats();

      final requests = await _supabase
          .from('restock_requests')
          .select('status, priority')
          .eq('id_company', companyId);

      return {
        'total': requests.length,
        'pending': requests.where((r) => r['status'] == 'pending').length,
        'approved': requests.where((r) => r['status'] == 'approved').length,
        'completed': requests.where((r) => r['status'] == 'completed').length,
        'rejected': requests.where((r) => r['status'] == 'rejected').length,
        'urgent': requests.where((r) => r['priority'] == 'urgent').length,
      };
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo stats: $e');
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
    };
  }
}