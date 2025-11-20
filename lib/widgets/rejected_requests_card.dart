// lib/services/email_service.dart
// VERSIÓN UNIFICADA - Usa Edge Function de Supabase (send-restock-email)
// ✅ Incluye TODOS los métodos necesarios

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';

class EmailService {
  // Información del remitente (visible en templates)
  static const String _fromEmail = 'mark@miatracker.com';
  static const String _fromName = 'MIA Tracker System';

  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // VERIFICAR CONFIGURACIÓN
  // ========================================================================

  static bool isConfigured() {
    return true; // Edge Function siempre disponible en Supabase
  }

  static Map<String, dynamic> getConfigInfo() {
    return {
      'configured': true,
      'from_email': _fromEmail,
      'from_name': _fromName,
      'method': 'Supabase Edge Function',
    };
  }

  // ========================================================================
  // MÉTODO PRINCIPAL: Llamar Edge Function
  // ========================================================================

  static Future<Map<String, dynamic>> sendViaEdgeFunction({
    required String toEmail,
    required String subject,
    required String html,
  }) async {
    try {
      if (kDebugMode) {
        print('📧 Llamando Edge Function: send-restock-email');
        print('   To: $toEmail');
        print('   Subject: $subject');
      }

      final res = await _supabase.functions.invoke(
        'send-restock-email',
        body: {
          'to': toEmail,
          'subject': subject,
          'html': html,
        },
      );

      if (kDebugMode) {
        print('📬 Respuesta Edge Function:');
        print('   Status: ${res.status}');
        print('   Data: ${res.data}');
      }

      if (res.status == 200 || res.status == 201) {
        return {
          'success': true,
          'response': res.data,
          'id': res.data?['id'],
        };
      } else {
        return {
          'success': false,
          'error': res.data ?? 'Edge function error (status: ${res.status})'
        };
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error llamando Edge Function: $e');
      }
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================================================
  // 1️⃣ MÉTODO: sendRestockApprovalToSupplier (usado por restock_approval_service)
  // ========================================================================

  static Future<void> sendRestockApprovalToSupplier({
    required int requestId,
    required int supplierId,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📧 sendRestockApprovalToSupplier - INICIO');
        print('   Request ID: $requestId');
        print('   Supplier ID: $supplierId');
      }

      // 1. Obtener solicitud
      final request = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      if (kDebugMode) {
        print('✅ Solicitud: ${request['nombre_producto']}');
      }

      // 2. Obtener proveedor
      final supplier = await _supabase
          .from('supply_company')
          .select('id, name, email, phone, user_id, id_company')
          .eq('id', supplierId)
          .single();

      if (kDebugMode) {
        print('✅ Proveedor: ${supplier['name']}');
        print('   Email: ${supplier['email']}');
      }

      if (supplier['email'] == null || supplier['email'].toString().isEmpty) {
        throw Exception('El proveedor no tiene email configurado');
      }

      // 3. Obtener nombre de compañía
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
          print('✅ Compañía: $companyName');
        }
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ Usando nombre por defecto');
        }
      }

      // 4. Construir HTML
      final htmlBody = _buildApprovalEmailTemplate(
        supplierName: supplier['name'],
        productName: request['nombre_producto'] ?? 'Producto',
        quantity: request['cantidad_solicitada'] ?? 0,
        companyName: companyName,
        internalNotes: request['internal_notes'],
        estimatedDeliveryDate: request['estimated_delivery_date'],
      );

      // 5. Enviar vía Edge Function
      final result = await sendViaEdgeFunction(
        toEmail: supplier['email'],
        subject: '✅ Solicitud de Restock Aprobada - ${request['nombre_producto']}',
        html: htmlBody,
      );

      if (result['success'] == true) {
        if (kDebugMode) {
          print('✅ Email enviado exitosamente');
          print('═══════════════════════════════════════════════');
        }
      } else {
        throw Exception(result['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
        print('═══════════════════════════════════════════════');
      }
      rethrow;
    }
  }

  // ========================================================================
  // 2️⃣ MÉTODO: sendApprovalEmail (wrapper simplificado)
  // ========================================================================

  static Future<Map<String, dynamic>> sendApprovalEmail({
    required String toEmail,
    required String supplierName,
    required String productName,
    required int quantity,
    required String companyName,
    String? internalNotes,
    String? estimatedDeliveryDate,
  }) async {
    try {
      final htmlBody = _buildApprovalEmailTemplate(
        supplierName: supplierName,
        productName: productName,
        quantity: quantity,
        companyName: companyName,
        internalNotes: internalNotes,
        estimatedDeliveryDate: estimatedDeliveryDate,
      );

      return await sendViaEdgeFunction(
        toEmail: toEmail,
        subject: '✅ Solicitud de Restock Aprobada - $productName',
        html: htmlBody,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error en sendApprovalEmail: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================================================
  // 3️⃣ MÉTODO: sendRejectionEmail (para rechazos)
  // ========================================================================

  static Future<Map<String, dynamic>> sendRejectionEmail({
    required String toEmail,
    required String supplierName,
    required String productName,
    required int quantity,
    required String companyName,
    required String rejectionReason,
  }) async {
    try {
      final htmlBody = _buildRejectionEmailTemplate(
        supplierName: supplierName,
        productName: productName,
        quantity: quantity,
        companyName: companyName,
        rejectionReason: rejectionReason,
      );

      return await sendViaEdgeFunction(
        toEmail: toEmail,
        subject: '❌ Solicitud de Restock Rechazada - $productName',
        html: htmlBody,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error en sendRejectionEmail: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================================================
  // 4️⃣ MÉTODO: sendRejectionEmailViaEdge (alias para compatibilidad)
  // ========================================================================

  static Future<Map<String, dynamic>> sendRejectionEmailViaEdge({
    required String toEmail,
    required String supplierName,
    required String productName,
    required int quantity,
    required String companyName,
    required String rejectionReason,
  }) async {
    return await sendRejectionEmail(
      toEmail: toEmail,
      supplierName: supplierName,
      productName: productName,
      quantity: quantity,
      companyName: companyName,
      rejectionReason: rejectionReason,
    );
  }

  // ========================================================================
  // TEMPLATES HTML
  // ========================================================================

  static String _buildApprovalEmailTemplate({
    required String supplierName,
    required String productName,
    required int quantity,
    required String companyName,
    String? internalNotes,
    String? estimatedDeliveryDate,
  }) {
    final deliverySection = estimatedDeliveryDate != null
        ? '''
        <tr>
          <td style="padding: 20px 0; border-top: 1px solid #e5e7eb;">
            <h3 style="margin: 0 0 10px 0; color: #374151; font-size: 16px;">
              📅 Fecha de Entrega Estimada
            </h3>
            <p style="margin: 0; color: #6b7280; font-size: 14px;">
              ${_formatDate(estimatedDeliveryDate)}
            </p>
          </td>
        </tr>
        '''
        : '';

    final notesSection = (internalNotes != null && internalNotes.isNotEmpty)
        ? '''
        <table role="presentation" style="width: 100%; margin-top: 25px;">
          <tr>
            <td style="padding: 20px; background-color: #eff6ff; border-left: 4px solid #3b82f6; border-radius: 4px;">
              <h3 style="margin: 0 0 10px 0; color: #1e3a8a; font-size: 16px;">
                📝 Notas Adicionales
              </h3>
              <p style="margin: 0; color: #1e40af; font-size: 14px; line-height: 1.6;">
                $internalNotes
              </p>
            </td>
          </tr>
        </table>
        '''
        : '';

    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Solicitud Aprobada</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #6B8E3D 0%, #5a7632 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">
                                ✅ Solicitud Aprobada
                            </h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">
                                MIA Tracker - Sistema de Gestión de Inventario
                            </p>
                        </td>
                    </tr>

                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">
                                Estimado/a <strong>$supplierName</strong>,
                            </p>
                            
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                Nos complace informarle que su solicitud de restock ha sido <strong style="color: #6B8E3D;">aprobada</strong> por <strong>$companyName</strong>.
                            </p>

                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #f0fdf4; border-radius: 8px; overflow: hidden; border: 1px solid #86efac;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #065f46; font-size: 16px;">
                                            📦 Detalles de la Solicitud
                                        </h3>
                                        
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px; width: 40%;">Producto:</td>
                                                <td style="padding: 8px 0; color: #064e3b; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px;">Cantidad:</td>
                                                <td style="padding: 8px 0; color: #064e3b; font-size: 14px; font-weight: 600;">$quantity unidades</td>
                                            </tr>
                                            $deliverySection
                                        </table>
                                    </td>
                                </tr>
                            </table>

                            $notesSection

                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td style="padding: 20px; background-color: #fef3c7; border-left: 4px solid #f59e0b; border-radius: 4px;">
                                        <h3 style="margin: 0 0 10px 0; color: #92400e; font-size: 16px;">💡 Próximos Pasos</h3>
                                        <p style="margin: 0; color: #78350f; font-size: 14px; line-height: 1.6;">
                                            Por favor, proceda con la preparación y envío del pedido según lo acordado.
                                        </p>
                                    </td>
                                </tr>
                            </table>

                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center">
                                        <a href="mailto:$_fromEmail" style="display: inline-block; padding: 14px 32px; background-color: #6B8E3D; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 15px;">
                                            Confirmar Recepción
                                        </a>
                                    </td>
                                </tr>
                            </table>

                            <p style="margin: 30px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.6;">
                                Si tiene alguna pregunta, no dude en contactarnos.
                            </p>

                            <p style="margin: 20px 0 0 0; color: #374151; font-size: 14px;">
                                Saludos cordiales,<br>
                                <strong>$companyName</strong>
                            </p>
                        </td>
                    </tr>

                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">Este es un correo automático generado por MIA Tracker System</p>
                            <p style="margin: 10px 0 0 0; color: #9ca3af; font-size: 12px;">© ${DateTime.now().year} MIA Tracker. Todos los derechos reservados.</p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
    ''';
  }

  static String _buildRejectionEmailTemplate({
    required String supplierName,
    required String productName,
    required int quantity,
    required String companyName,
    required String rejectionReason,
  }) {
    return '''
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Solicitud Rechazada</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #EF4444 0%, #DC2626 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">❌ Solicitud No Aprobada</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - Sistema de Gestión de Inventario</p>
                        </td>
                    </tr>

                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Estimado/a <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                Lamentamos informarle que su solicitud de restock ha sido <strong style="color: #DC2626;">rechazada</strong> por <strong>$companyName</strong>.
                            </p>

                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #fef2f2; border-radius: 8px; overflow: hidden; border: 1px solid #fecaca;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #991b1b; font-size: 16px;">📦 Detalles</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #7f1d1d; font-size: 14px; width: 40%;">Producto:</td>
                                                <td style="padding: 8px 0; color: #450a0a; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #7f1d1d; font-size: 14px;">Cantidad:</td>
                                                <td style="padding: 8px 0; color: #450a0a; font-size: 14px; font-weight: 600;">$quantity unidades</td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>

                            <table role="presentation" style="width: 100%; margin-top: 25px;">
                                <tr>
                                    <td style="padding: 20px; background-color: #fff7ed; border-left: 4px solid #f59e0b; border-radius: 4px;">
                                        <h3 style="margin: 0 0 10px 0; color: #92400e; font-size: 16px;">ℹ️ Motivo</h3>
                                        <p style="margin: 0; color: #78350f; font-size: 14px; line-height: 1.6;">$rejectionReason</p>
                                    </td>
                                </tr>
                            </table>

                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center">
                                        <a href="mailto:$_fromEmail" style="display: inline-block; padding: 14px 32px; background-color: #6B8E3D; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 15px;">
                                            Contactar para Más Información
                                        </a>
                                    </td>
                                </tr>
                            </table>

                            <p style="margin: 30px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.6;">
                                Agradecemos su interés y esperamos poder colaborar en el futuro.
                            </p>

                            <p style="margin: 20px 0 0 0; color: #374151; font-size: 14px;">
                                Atentamente,<br><strong>$companyName</strong>
                            </p>
                        </td>
                    </tr>

                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">Este es un correo automático generado por MIA Tracker System</p>
                            <p style="margin: 10px 0 0 0; color: #9ca3af; font-size: 12px;">© ${DateTime.now().year} MIA Tracker. Todos los derechos reservados.</p>
                        </td>
                    </tr>
                </table>
            </td>
        </tr>
    </table>
</body>
</html>
    ''';
  }

  // ========================================================================
  // HELPER: FORMATEAR FECHA
  // ========================================================================

  static String _formatDate(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final months = [
        'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
        'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
      ];
      return '${date.day} de ${months[date.month - 1]} de ${date.year}';
    } catch (e) {
      return isoDate;
    }
  }
}