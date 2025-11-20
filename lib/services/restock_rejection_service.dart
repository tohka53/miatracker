// lib/services/restock_rejection_service.dart
// SERVICIO COMPLETO PARA RECHAZAR SOLICITUDES Y ENVIAR EMAIL AL PROVEEDOR

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'profile_service.dart';
import 'inventory_service.dart';
import 'email_service.dart';

class RestockRejectionService {
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // RECHAZAR SOLICITUD CON ENVÍO DE EMAIL AUTOMÁTICO
  // ========================================================================

  /// Rechaza una solicitud de restock y envía email automático al proveedor
  static Future<Map<String, dynamic>> rejectRequestWithEmail({
    required int requestId,
    required String rejectionReason,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('❌ INICIO - Rechazo de Solicitud con Email');
        print('   Request ID: $requestId');
        print('   Razón: $rejectionReason');
      }

      // 1. Validar permisos de admin
      final isAdmin = await ProfileService.isUserAdmin();
      if (!isAdmin) {
        throw Exception('No tienes permisos de administrador');
      }

      // 2. Obtener company_id
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        throw Exception('No perteneces a ninguna compañía');
      }

      // 3. Obtener datos completos de la solicitud
      final request = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .eq('id_company', companyId)
          .single();

      if (kDebugMode) {
        print('✅ Solicitud obtenida:');
        print('   Producto: ${request['nombre_producto']}');
        print('   ID Supply Company: ${request['id_supply_company']}');
      }

      // 4. Verificar que hay un proveedor asignado
      if (request['id_supply_company'] == null) {
        throw Exception(
            'Esta solicitud no tiene un proveedor asignado. '
                'Asigna un proveedor al producto antes de rechazar.'
        );
      }

      // 5. Obtener datos del proveedor
      final supplier = await _supabase
          .from('supply_company')
          .select('id, name, email, phone')
          .eq('id', request['id_supply_company'])
          .eq('id_company', companyId)
          .single();

      if (kDebugMode) {
        print('✅ Proveedor obtenido:');
        print('   Nombre: ${supplier['name']}');
        print('   Email: ${supplier['email']}');
      }

      // 6. Validar que el proveedor tiene email
      final supplierEmail = supplier['email'];
      if (supplierEmail == null || supplierEmail.toString().isEmpty) {
        throw Exception('El proveedor "${supplier['name']}" no tiene email configurado');
      }

      // 7. Actualizar estado de la solicitud en base de datos
      await _supabase
          .from('restock_requests')
          .update({
        'status': 'rejected',
        'internal_notes': rejectionReason,
        'fecha_respuesta': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', requestId)
          .eq('id_company', companyId);

      if (kDebugMode) {
        print('✅ Estado actualizado a "rejected" en BD');
      }

      // 8. Obtener nombre de la compañía para el email
      String companyName = 'Sistema MIA Tracker';
      try {
        final userProfile = await _supabase
            .from('profiles')
            .select('full_name, company')
            .eq('id', request['user_id'])
            .maybeSingle();

        if (userProfile != null && userProfile['company'] != null) {
          companyName = userProfile['company'];
        } else if (userProfile != null && userProfile['full_name'] != null) {
          companyName = userProfile['full_name'];
        }

        if (kDebugMode) {
          print('✅ Nombre de compañía: $companyName');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ No se pudo obtener nombre de compañía, usando default');
        }
      }

      // 9. Enviar email de rechazo al proveedor
      if (kDebugMode) {
        print('📧 Enviando email de rechazo...');
      }

      final emailResult = await EmailService.sendRejectionEmail(
        toEmail: supplierEmail,
        supplierName: supplier['name'],
        productName: request['nombre_producto'] ?? 'Producto',
        quantity: request['cantidad_solicitada'] ?? 0,
        companyName: companyName,
        rejectionReason: rejectionReason,
      );

      if (emailResult['success'] == true) {
        if (kDebugMode) {
          print('✅ Email de rechazo enviado exitosamente');
          print('   Email ID: ${emailResult['id']}');
          print('═══════════════════════════════════════════════');
        }

        return {
          'success': true,
          'message': 'Solicitud rechazada y email enviado',
          'email_sent': true,
          'email_id': emailResult['id'],
        };
      } else {
        // Email falló pero la solicitud ya fue rechazada en BD
        if (kDebugMode) {
          print('⚠️ Solicitud rechazada pero falló el envío de email');
          print('   Error: ${emailResult['error']}');
          print('═══════════════════════════════════════════════');
        }

        return {
          'success': true, // La solicitud SÍ fue rechazada
          'message': 'Solicitud rechazada pero no se pudo enviar email',
          'email_sent': false,
          'email_error': emailResult['error'],
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ ERROR en rechazo de solicitud: $e');
        print('═══════════════════════════════════════════════');
      }
      rethrow;
    }
  }

  // ========================================================================
  // MÉTODO SIMPLE (sin email) - Mantiene compatibilidad
  // ========================================================================

  /// Rechaza una solicitud sin enviar email (útil para casos especiales)
  static Future<void> rejectRequestOnly({
    required int requestId,
    required String reason,
  }) async {
    try {
      final isAdmin = await ProfileService.isUserAdmin();
      if (!isAdmin) {
        throw Exception('No tienes permisos de administrador');
      }

      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        throw Exception('No perteneces a ninguna compañía');
      }

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

      if (kDebugMode) {
        print('❌ Solicitud rechazada (sin email)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error al rechazar solicitud: $e');
      }
      rethrow;
    }
  }

  // ========================================================================
  // REENVIAR EMAIL DE RECHAZO (por si falló originalmente)
  // ========================================================================

  /// Reenvía el email de rechazo a un proveedor (útil si falló anteriormente)
  static Future<Map<String, dynamic>> resendRejectionEmail({
    required int requestId,
  }) async {
    try {
      if (kDebugMode) {
        print('📧 Reenviando email de rechazo...');
      }

      // Obtener datos de la solicitud
      final request = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      // Validar que está rechazada
      if (request['status'] != 'rejected') {
        throw Exception('Esta solicitud no está en estado "rejected"');
      }

      // Verificar que hay un proveedor asignado
      if (request['id_supply_company'] == null) {
        throw Exception('Esta solicitud no tiene un proveedor asignado');
      }

      // Obtener datos del proveedor
      final supplier = await _supabase
          .from('supply_company')
          .select('id, name, email, phone')
          .eq('id', request['id_supply_company'])
          .single();

      // Validar email del proveedor
      final supplierEmail = supplier['email'];
      if (supplierEmail == null || supplierEmail.toString().isEmpty) {
        throw Exception('El proveedor "${supplier['name']}" no tiene email configurado');
      }

      // Obtener nombre de compañía
      String companyName = 'Sistema MIA Tracker';
      try {
        final userProfile = await _supabase
            .from('profiles')
            .select('full_name, company')
            .eq('id', request['user_id'])
            .maybeSingle();

        if (userProfile != null && userProfile['company'] != null) {
          companyName = userProfile['company'];
        } else if (userProfile != null && userProfile['full_name'] != null) {
          companyName = userProfile['full_name'];
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Usando nombre de compañía por defecto');
        }
      }

      // Enviar email
      final emailResult = await EmailService.sendRejectionEmail(
        toEmail: supplierEmail,
        supplierName: supplier['name'],
        productName: request['nombre_producto'] ?? 'Producto',
        quantity: request['cantidad_solicitada'] ?? 0,
        companyName: companyName,
        rejectionReason: request['internal_notes'] ?? 'No especificado',
      );

      if (emailResult['success'] == true) {
        if (kDebugMode) {
          print('✅ Email reenviado exitosamente');
        }
        return {
          'success': true,
          'message': 'Email reenviado exitosamente',
          'email_id': emailResult['id'],
        };
      } else {
        throw Exception(emailResult['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error reenviando email: $e');
      }
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // ========================================================================
  // OBTENER SOLICITUDES RECHAZADAS
  // ========================================================================

  /// Obtiene todas las solicitudes rechazadas de la compañía
  static Future<List<Map<String, dynamic>>> getRejectedRequests() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) return [];

      final requests = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id_company', companyId)
          .eq('status', 'rejected')
          .order('fecha_respuesta', ascending: false);

      // Enriquecer con datos del proveedor
      final enrichedRequests = <Map<String, dynamic>>[];

      for (var request in requests) {
        final enrichedRequest = Map<String, dynamic>.from(request);

        if (request['id_supply_company'] != null) {
          try {
            final supplier = await _supabase
                .from('supply_company')
                .select('id, name, email, phone')
                .eq('id', request['id_supply_company'])
                .maybeSingle();

            enrichedRequest['supply_company'] = supplier ?? {
              'id': null,
              'name': 'Sin proveedor',
              'email': null,
              'phone': null,
            };
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error obteniendo proveedor para request ${request['id']}: $e');
            }
            enrichedRequest['supply_company'] = {
              'id': null,
              'name': 'Sin proveedor',
              'email': null,
              'phone': null,
            };
          }
        } else {
          enrichedRequest['supply_company'] = {
            'id': null,
            'name': 'Sin proveedor',
            'email': null,
            'phone': null,
          };
        }

        enrichedRequests.add(enrichedRequest);
      }

      return enrichedRequests;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo solicitudes rechazadas: $e');
      }
      return [];
    }
  }

  // ========================================================================
  // ESTADÍSTICAS DE RECHAZOS
  // ========================================================================

  /// Obtiene estadísticas sobre solicitudes rechazadas
  static Future<Map<String, dynamic>> getRejectionStats() async {
    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        return {
          'total_rejected': 0,
          'rejected_this_month': 0,
          'most_rejected_supplier': null,
        };
      }

      final rejected = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id_company', companyId)
          .eq('status', 'rejected');

      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);

      final rejectedThisMonth = rejected.where((r) {
        final date = DateTime.parse(r['fecha_respuesta'] ?? r['updated_at']);
        return date.isAfter(firstDayOfMonth);
      }).length;

      return {
        'total_rejected': rejected.length,
        'rejected_this_month': rejectedThisMonth,
      };
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error obteniendo estadísticas: $e');
      }
      return {
        'total_rejected': 0,
        'rejected_this_month': 0,
      };
    }
  }
}