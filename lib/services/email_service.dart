// lib/services/email_service.dart

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class EmailService {
  static const String _fromEmail = 'mark@miatracker.com';
  static const String _fromName = 'MIA Tracker System';
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // VERIFICAR CONFIGURACIÓN
  // ========================================================================

  static bool isConfigured() => true;

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
      final session = _supabase.auth.currentSession;
      final authHeader = session?.accessToken != null
          ? 'Bearer ${session!.accessToken}'
          : null;

      if (kDebugMode) {
        print('📧 Llamando Edge Function: send-restock-email');
        print('   To: $toEmail');
        print('   Subject: $subject');
        print('   Auth header: ${authHeader != null ? "user JWT" : "anon"}');
      }

      final res = await _supabase.functions.invoke(
        'send-restock-email',
        body: {
          'to': toEmail,
          'subject': subject,
          'html': html,
        },
        headers: authHeader != null ? {'Authorization': authHeader} : null,
      );

      if (kDebugMode) {
        print('📬 Edge Response');
        print('   Status: ${res.status}');
        print('   Data  : ${res.data}');
      }

      if (res.status == 200 || res.status == 201) {
        final data = res.data;
        return {
          'success': true,
          'response': data,
          'id': (data is Map && data['id'] != null) ? data['id'] : null,
        };
      } else {
        final errText = (res.data is String)
            ? res.data
            : (res.data is Map && (res.data as Map)['error'] != null)
            ? (res.data as Map)['error'].toString()
            : 'Edge function error (status: ${res.status})';
        return {'success': false, 'error': errText};
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error llamando Edge Function: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================================================
  // 1️⃣ MÉTODO: sendRestockApprovalToSupplier
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

      final request = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      if (kDebugMode) print('✅ Solicitud: ${request['nombre_producto']}');

      final supplier = await _supabase
          .from('supply_company')
          .select('id, name, email, phone, user_id, id_company')
          .eq('id', supplierId)
          .single();

      if (kDebugMode) {
        print('✅ Supplier: ${supplier['name']}');
        print('   Email: ${supplier['email']}');
      }

      if (supplier['email'] == null || supplier['email'].toString().isEmpty) {
        throw Exception('The provider does not have email configured.');
      }

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

        if (kDebugMode) print('✅ Company: $companyName');
      } catch (e) {
        if (kDebugMode) print('⚠️ Usando nombre por defecto');
      }

      final htmlBody = _buildApprovalEmailTemplate(
        supplierName: supplier['name'],
        productName: request['nombre_producto'] ?? 'Producto',
        quantity: request['cantidad_solicitada'] ?? 0,
        companyName: companyName,
        internalNotes: request['internal_notes'],
        estimatedDeliveryDate: request['estimated_delivery_date'],
      );

      final result = await sendViaEdgeFunction(
        toEmail: supplier['email'],
        subject: '✅ Restock Request Approved - ${request['nombre_producto']}',
        html: htmlBody,
      );

      if (result['success'] == true) {
        if (kDebugMode) {
          print('✅ Email sent successfully');
          print('═══════════════════════════════════════════════');
        }
      } else {
        throw Exception(result['error'] ?? 'Unknown error');
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
  // 2️⃣ MÉTODO: sendApprovalEmail
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
        subject: '✅ Restock Request Approved - $productName',
        html: htmlBody,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error en sendApprovalEmail: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================================================
  // 3️⃣ MÉTODO: sendRejectionEmail
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
        subject: '❌ Restock Request Rejected - $productName',
        html: htmlBody,
      );
    } catch (e) {
      if (kDebugMode) print('❌ Error en sendRejectionEmail: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================================================
  // 4️⃣ MÉTODO: sendRejectionEmailViaEdge
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
  // 5️⃣ MÉTODO: sendNewRestockRequestToSupplier
  // ========================================================================

  static Future<void> sendNewRestockRequestToSupplier({
    required int requestId,
    required int supplierId,
    required String productName,
    required int quantity,
    required int companyId,
    String? notes,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📧 sendNewRestockRequestToSupplier - INICIO');
      }

      final supplier = await _supabase
          .from('supply_company')
          .select('id, name, email, phone')
          .eq('id', supplierId)
          .eq('id_company', companyId)
          .single();

      if (supplier['email'] == null || supplier['email'].toString().isEmpty) {
        throw Exception('Proveedor sin email configurado');
      }

      String companyName = 'Sistema MIA Tracker';
      try {
        final companyInfo = await _supabase
            .from('company')
            .select('company_name')
            .eq('id_company', companyId)
            .single();
        companyName = companyInfo['company_name'] ?? companyName;
      } catch (e) {
        if (kDebugMode) print('⚠️ Usando nombre default');
      }

      final htmlBody = _buildNewRestockRequestTemplate(
        supplierName: supplier['name'],
        productName: productName,
        quantity: quantity,
        companyName: companyName,
        notes: notes,
        requestId: requestId,
      );

      final result = await sendViaEdgeFunction(
        toEmail: supplier['email'],
        subject: '🔔 New Restock Request - $productName',
        html: htmlBody,
      );

      if (result['success'] == true) {
        if (kDebugMode) print('✅ Email enviado exitosamente');
      } else {
        throw Exception(result['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error: $e');
      rethrow;
    }
  }

  // ========================================================================
  // 🔥 6️⃣ MÉTODO: sendApprovalEmailWithQR (CON QR CODE)
  // ========================================================================

  static Future<void> sendApprovalEmailWithQR({
    required int requestId,
    required int supplierId,
    DateTime? deliveryDate,
    String? internalNotes,
    required String qrData,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📧 sendApprovalEmailWithQR - INICIO');
        print('   Request ID: $requestId');
        print('   Supplier ID: $supplierId');
        print('   QR Data: $qrData');
      }

      // 1. Obtener solicitud
      final request = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      // 2. Obtener proveedor
      final supplier = await _supabase
          .from('supply_company')
          .select('*')
          .eq('id', supplierId)
          .single();

      if (supplier['email'] == null || supplier['email'].toString().isEmpty) {
        throw Exception('Proveedor sin email configurado');
      }

      // 3. Obtener compañía
      String companyName = 'MIA Tracker';
      try {
        final company = await _supabase
            .from('company')
            .select('company_name')
            .eq('id_company', request['id_company'])
            .single();
        companyName = company['company_name'] ?? companyName;
      } catch (e) {
        if (kDebugMode) print('⚠️ Usando nombre default para compañía');
      }

      // 4. 🔥 GENERAR URL DEL QR
      final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$qrData';

      if (kDebugMode) print('✅ QR Image URL: $qrImageUrl');

      // 5. Construir HTML con QR
      final htmlBody = _buildApprovalWithQRTemplate(
        supplierName: supplier['name'],
        productName: request['nombre_producto'],
        quantity: request['cantidad_solicitada'],
        companyName: companyName,
        deliveryDate: deliveryDate,
        internalNotes: internalNotes,
        qrImageUrl: qrImageUrl,
        requestId: requestId,
      );

      // 6. Enviar email
      final result = await sendViaEdgeFunction(
        toEmail: supplier['email'],
        subject: '✅ Restock Request Approved - ${request['nombre_producto']}',
        html: htmlBody,
      );

      if (result['success'] == true) {
        if (kDebugMode) {
          print('✅ Email con QR enviado exitosamente');
          print('═══════════════════════════════════════════════');
        }
      } else {
        throw Exception(result['error'] ?? 'Error desconocido');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en sendApprovalEmailWithQR: $e');
        print('═══════════════════════════════════════════════');
      }
      rethrow;
    }
  }
// ========================================================================
// 🔥 7️⃣ MÉTODO ACTUALIZADO: sendRestockRequestToAdmins (CON QR)
// ========================================================================

  static Future<void> sendRestockRequestToAdmins({
    required int requestId,
    required int productId,
    required String productName,
    required int requestedQuantity,
    required int currentStock,
    required String priority,
    required int companyId,
    String? notes,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📧 sendRestockRequestToAdmins - INICIO');
        print('   Request ID: $requestId');
        print('   Product: $productName');
        print('   Company ID: $companyId');
        print('   Priority: $priority');
      }

      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      if (kDebugMode) print('✅ User ID: $userId');

      final userProfile = await _supabase
          .from('profiles')
          .select('full_name, company')
          .eq('id', userId)
          .single();

      final requesterName = userProfile['full_name'] ?? 'Usuario';
      final companyName = userProfile['company'] ?? 'Compañía';

      if (kDebugMode) {
        print('✅ Requester: $requesterName');
        print('✅ Company Name: $companyName');
        print('🔍 Buscando administradores...');
      }

      final admins = await _supabase.rpc(
        'get_company_admins',
        params: {'p_company_id': companyId},
      );

      if (kDebugMode) {
        print('📊 Consulta admins completada');
        print('   Resultados: ${admins.length}');
      }

      if (admins.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No se encontraron administradores en la compañía $companyId');
        }
        return;
      }

      if (kDebugMode) {
        print('✅ Administradores encontrados: ${admins.length}');
        for (var admin in admins) {
          print('   - ID: ${admin['id']}');
          print('     Nombre: ${admin['full_name'] ?? admin['username']}');
        }
      }

      final List<String> adminEmails = [];
      final List<String> failedAdmins = [];

      for (var admin in admins) {
        try {
          if (kDebugMode) {
            print('───────────────────────────────────────────────');
            print('📧 Obteniendo email de: ${admin['full_name']}');
            print('   ID: ${admin['id']}');
          }

          final dynamic emailResult = await _supabase.rpc(
            'get_user_email',
            params: {'user_uuid': admin['id']},
          );

          final String? adminEmail = emailResult as String?;

          if (kDebugMode) print('   Email obtenido: ${adminEmail ?? "NULL"}');

          if (adminEmail == null || adminEmail.isEmpty) {
            if (kDebugMode) {
              print('⚠️ Admin ${admin['full_name']} no tiene email configurado');
            }
            failedAdmins.add('${admin['full_name']}: sin email');
            continue;
          }

          adminEmails.add(adminEmail);
          if (kDebugMode) print('✅ Email agregado: $adminEmail');
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error obteniendo email de ${admin['full_name']}: $e');
          }
          failedAdmins.add('${admin['full_name']}: $e');
        }
      }

      if (adminEmails.isEmpty) {
        if (kDebugMode) {
          print('❌ No se pudo obtener ningún email válido');
          print('   Razones: $failedAdmins');
        }
        return;
      }

      final String recipientsString = adminEmails.join(';');

      // 🔥 GENERAR QR DATA
      final qrData = 'miatracker://restock/complete/$requestId';
      final qrImageUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=$qrData';

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📧 ENVIANDO EMAIL AGRUPADO CON QR');
        print('   Destinatarios: $recipientsString');
        print('   Total admins: ${adminEmails.length}');
        print('   QR Data: $qrData');
        print('   QR URL: $qrImageUrl');
      }

      // 🔥 CONSTRUIR HTML CON QR
      final htmlBody = _buildNewRequestEmailTemplateWithQR(
        adminName: 'Administradores',
        requesterName: requesterName,
        productName: productName,
        requestedQuantity: requestedQuantity,
        currentStock: currentStock,
        priority: priority,
        companyName: companyName,
        notes: notes,
        requestId: requestId,
        qrImageUrl: qrImageUrl, // 🔥 NUEVO PARÁMETRO
      );

      if (kDebugMode) {
        print('✅ Template HTML con QR generado');
        print('📧 Llamando Edge Function...');
      }

      final result = await sendViaEdgeFunction(
        toEmail: recipientsString,
        subject: '🔔 New Restock Request - $productName',
        html: htmlBody,
      );

      if (kDebugMode) {
        print('📬 Respuesta Edge Function:');
        print('   Success: ${result['success']}');
        print('   Response: ${result['response']}');
        if (result['error'] != null) print('   Error: ${result['error']}');
      }

      if (result['success'] == true) {
        if (kDebugMode) {
          print('═══════════════════════════════════════════════');
          print('📊 RESUMEN DE ENVÍO');
          print('   Email enviado a: ${adminEmails.length} administradores');
          print('   Destinatarios: ${adminEmails.join(", ")}');
          if (failedAdmins.isNotEmpty) {
            print('   Advertencias:');
            for (var warning in failedAdmins) {
              print('     - $warning');
            }
          }
          print('═══════════════════════════════════════════════');
          print('✅ Notificación con QR enviada exitosamente');
        }
      } else {
        if (kDebugMode) print('❌ Error enviando email: ${result['error']}');
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('❌ ERROR CRÍTICO en sendRestockRequestToAdmins');
        print('   Error: $e');
        print('   Stack: $stackTrace');
        print('═══════════════════════════════════════════════');
      }
    }
  }


  // ========================================================================
// 🔥 NUEVO TEMPLATE HTML: Nueva solicitud para admins CON QR
// ========================================================================

  static String _buildNewRequestEmailTemplateWithQR({
    required String adminName,
    required String requesterName,
    required String productName,
    required int requestedQuantity,
    required int currentStock,
    required String priority,
    required String companyName,
    String? notes,
    required int requestId,
    required String qrImageUrl, // 🔥 NUEVO PARÁMETRO
  }) {
    final Map<String, Map<String, String>> priorityColors = {
      'low': {'bg': '#f0fdf4', 'border': '#86efac', 'text': '#065f46'},
      'medium': {'bg': '#eff6ff', 'border': '#93c5fd', 'text': '#1e40af'},
      'high': {'bg': '#fef3c7', 'border': '#fcd34d', 'text': '#92400e'},
      'urgent': {'bg': '#fee2e2', 'border': '#fca5a5', 'text': '#991b1b'},
    };

    final colors = priorityColors[priority.toLowerCase()] ?? priorityColors['medium']!;
    final priorityLabel = priority.toUpperCase();
    final priorityIcon = priority.toLowerCase() == 'urgent'
        ? '🚨'
        : priority.toLowerCase() == 'high'
        ? '⚠️'
        : '📋';

    final notesSection = (notes != null && notes.isNotEmpty)
        ? '''
      <table role="presentation" style="width: 100%; margin-top: 20px;">
        <tr>
          <td style="padding: 15px; background-color: #f9fafb; border-left: 4px solid #9ca3af; border-radius: 4px;">
            <h3 style="margin: 0 0 8px 0; color: #4b5563; font-size: 14px;">📝 Additional Notes</h3>
            <p style="margin: 0; color: #6b7280; font-size: 13px; line-height: 1.6;">$notes</p>
          </td>
        </tr>
      </table>
      '''
        : '';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Restock Request</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">🔔 New Restock Request</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - $companyName</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Hello <strong>$adminName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                <strong>$requesterName</strong> has created a new restock request that requires your review and approval.
                            </p>
                            
                            <!-- Priority Badge -->
                            <table role="presentation" style="width: 100%; margin-bottom: 25px;">
                                <tr>
                                    <td align="center">
                                        <div style="display: inline-block; padding: 8px 20px; background-color: ${colors['bg']}; border: 2px solid ${colors['border']}; border-radius: 20px;">
                                            <span style="color: ${colors['text']}; font-weight: 700; font-size: 14px;">
                                                $priorityIcon Priority: $priorityLabel
                                            </span>
                                        </div>
                                    </td>
                                </tr>
                            </table>

                            <!-- Request Details -->
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #f9fafb; border-radius: 8px; overflow: hidden; border: 1px solid #e5e7eb;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #111827; font-size: 16px;">📦 Request Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px; width: 45%;">Product:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Requested Quantity:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$requestedQuantity units</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Current Stock:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$currentStock units</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Requested by:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$requesterName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Request ID:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">#$requestId</td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>

                            $notesSection

                            <!-- 🔥 QR CODE SECTION FOR ADMINS -->
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center" style="padding: 30px; background-color: #EFF6FF; border-radius: 8px; border: 2px solid #3b82f6;">
                                        <h3 style="margin: 0 0 15px 0; color: #1e40af; font-size: 18px; font-weight: 700;">📱 QR Code for Completion</h3>
                                        <img src="$qrImageUrl" alt="QR Code" style="width: 200px; height: 200px; border: 3px solid #3b82f6; border-radius: 8px; display: block; margin: 0 auto;" />
                                        <p style="margin: 15px 0 0 0; color: #1e40af; font-size: 13px; font-weight: 600;">
                                            Use this QR to complete the order when delivered
                                        </p>
                                        <p style="margin: 5px 0 0 0; color: #6b7280; font-size: 11px;">Request ID: #$requestId</p>
                                    </td>
                                </tr>
                            </table>

                            <!-- Action Required -->
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td style="padding: 20px; background-color: #dbeafe; border-left: 4px solid #3b82f6; border-radius: 4px;">
                                        <h3 style="margin: 0 0 10px 0; color: #1e40af; font-size: 16px;">👉 Action Required</h3>
                                        <p style="margin: 0; color: #1e40af; font-size: 14px; line-height: 1.6;">
                                            Please review this request in your MIA Tracker dashboard and approve or reject it as appropriate.
                                        </p>
                                    </td>
                                </tr>
                            </table>

                            <!-- CTA Button -->
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center">
                                        <a href="https://miatracker.com/restock-requests" style="display: inline-block; padding: 14px 32px; background-color: #2563eb; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 15px;">
                                            Review Request in Dashboard
                                        </a>
                                    </td>
                                </tr>
                            </table>

                            <p style="margin: 30px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.6;">
                                If you have any questions about this request, please contact $requesterName directly.
                            </p>

                            <p style="margin: 20px 0 0 0; color: #374151; font-size: 14px;">
                                Best regards,<br><strong>MIA Tracker System</strong>
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">This is an automated email generated by MIA Tracker</p>
                            <p style="margin: 10px 0 0 0; color: #9ca3af; font-size: 12px;">© ${DateTime.now().year} MIA Tracker. All rights reserved.</p>
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
  // 🔥 8️⃣ MÉTODO: sendOrderCompletedEmails (SUPPLY COMPANY + ADMINS)
  // ========================================================================

  static Future<void> sendOrderCompletedEmails({
    required int requestId,
    required int companyId,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📧 sendOrderCompletedEmails - INICIO');
        print('   Request ID: $requestId');
        print('   Company ID: $companyId');
      }

      // 1. Obtener solicitud
      final request = await _supabase
          .from('restock_requests')
          .select('*')
          .eq('id', requestId)
          .single();

      // 2. Obtener proveedor
      final supplier = await _supabase
          .from('supply_company')
          .select('*')
          .eq('id', request['id_supply_company'])
          .single();

      // 3. Obtener admins
      final admins = await _supabase.rpc(
        'get_company_admins',
        params: {'p_company_id': companyId},
      );

      // 4. Obtener compañía
      String companyName = 'MIA Tracker';
      try {
        final company = await _supabase
            .from('company')
            .select('company_name')
            .eq('id_company', companyId)
            .single();
        companyName = company['company_name'] ?? companyName;
      } catch (e) {}

      // 5. Construir HTML
      final htmlBody = _buildOrderCompletedTemplate(
        productName: request['nombre_producto'],
        quantity: request['cantidad_solicitada'],
        companyName: companyName,
        completedDate: request['fecha_completado'] ?? DateTime.now().toIso8601String(),
        requestId: requestId,
      );

      // 6. 🔥 ENVIAR A PROVEEDOR
      if (supplier['email'] != null && supplier['email'].toString().isNotEmpty) {
        if (kDebugMode) print('📧 Enviando email a proveedor: ${supplier['email']}');

        await sendViaEdgeFunction(
          toEmail: supplier['email'],
          subject: '✅ Order Completed - ${request['nombre_producto']}',
          html: htmlBody,
        );

        if (kDebugMode) print('✅ Email enviado al proveedor');
      }

      // 7. 🔥 ENVIAR A ADMINS
      final List<String> adminEmails = [];
      for (var admin in admins) {
        try {
          final emailResult = await _supabase.rpc(
            'get_user_email',
            params: {'user_uuid': admin['id']},
          );
          if (emailResult != null) adminEmails.add(emailResult);
        } catch (e) {
          if (kDebugMode) print('⚠️ Error obteniendo email de admin: $e');
        }
      }

      if (adminEmails.isNotEmpty) {
        if (kDebugMode) {
          print('📧 Enviando email a ${adminEmails.length} admins');
          print('   Destinatarios: ${adminEmails.join(", ")}');
        }

        await sendViaEdgeFunction(
          toEmail: adminEmails.join(';'),
          subject: '✅ Restock Completed - ${request['nombre_producto']}',
          html: htmlBody,
        );

        if (kDebugMode) print('✅ Email enviado a admins');
      }

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('✅ Emails de completado enviados exitosamente');
        print('   - Proveedor: ${supplier['email']}');
        print('   - Admins: ${adminEmails.length}');
        print('═══════════════════════════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error en sendOrderCompletedEmails: $e');
        print('═══════════════════════════════════════════════');
      }
      rethrow;
    }
  }

  // ========================================================================
  // TEMPLATE HTML: APROBACIÓN (SIN QR)
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
            <h3 style="margin: 0 0 10px 0; color: #374151; font-size: 16px;">📅 Estimated Delivery Date</h3>
            <p style="margin: 0; color: #6b7280; font-size: 14px;">${_formatDate(estimatedDeliveryDate)}</p>
          </td>
        </tr>
        '''
        : '';

    final notesSection = (internalNotes != null && internalNotes.isNotEmpty)
        ? '''
        <table role="presentation" style="width: 100%; margin-top: 25px;">
          <tr>
            <td style="padding: 20px; background-color: #eff6ff; border-left: 4px solid #3b82f6; border-radius: 4px;">
              <h3 style="margin: 0 0 10px 0; color: #1e3a8a; font-size: 16px;">📝 Additional Notes</h3>
              <p style="margin: 0; color: #1e40af; font-size: 14px; line-height: 1.6;">$internalNotes</p>
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
    <title>Application Approved</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #6B8E3D 0%, #5a7632 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">✅ Application Approved</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - Maintenance Inventory Asset Tracker</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Dear <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                We are pleased to inform you that your restock request has been <strong style="color: #6B8E3D;">approved</strong> by <strong>$companyName</strong>.
                            </p>
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #f0fdf4; border-radius: 8px; overflow: hidden; border: 1px solid #86efac;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #065f46; font-size: 16px;">📦 Application Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px; width: 40%;">Product:</td>
                                                <td style="padding: 8px 0; color: #064e3b; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px;">Amount:</td>
                                                <td style="padding: 8px 0; color: #064e3b; font-size: 14px; font-weight: 600;">$quantity units</td>
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
                                        <h3 style="margin: 0 0 10px 0; color: #92400e; font-size: 16px;">💡 Next Steps</h3>
                                        <p style="margin: 0; color: #78350f; font-size: 14px; line-height: 1.6;">
                                            Please proceed with the preparation and shipment of the order as agreed.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center">
                                        <a href="mailto:$_fromEmail" style="display: inline-block; padding: 14px 32px; background-color: #6B8E3D; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 15px;">
                                            Confirm Receipt
                                        </a>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 30px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.6;">
                                If you have any questions, please feel free to contact us.
                            </p>
                            <p style="margin: 20px 0 0 0; color: #374151; font-size: 14px;">
                                Saludos cordiales,<br><strong>$companyName</strong>
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">This is an automated email generated by the MIA Tracker System</p>
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
  // TEMPLATE HTML: RECHAZO
  // ========================================================================

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
    <title>Application Rejected</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #EF4444 0%, #DC2626 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">❌ Application Not Approved</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - Maintenance Inventory Asset Tracker</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Estimado/a <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                We regret to inform you that your restock request has been <strong style="color: #DC2626;">rejected</strong> by <strong>$companyName</strong>.
                            </p>
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #fef2f2; border-radius: 8px; overflow: hidden; border: 1px solid #fecaca;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #991b1b; font-size: 16px;">📦 Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #7f1d1d; font-size: 14px; width: 40%;">Product:</td>
                                                <td style="padding: 8px 0; color: #450a0a; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #7f1d1d; font-size: 14px;">Amount:</td>
                                                <td style="padding: 8px 0; color: #450a0a; font-size: 14px; font-weight: 600;">$quantity units</td>
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
                                            Contact for More Information
                                        </a>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 30px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.6;">
                               Thank you for your interest and we look forward to collaborating in the future.
                            </p>
                            <p style="margin: 20px 0 0 0; color: #374151; font-size: 14px;">
                                Sincerely,<br><strong>$companyName</strong>
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">This is an automated email generated by the MIA Tracker System</p>
                            <p style="margin: 10px 0 0 0; color: #9ca3af; font-size: 12px;">© ${DateTime.now().year} MIA Tracker. All rights reserved.</p>
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
  // TEMPLATE HTML: NUEVA SOLICITUD PARA ADMINS
  // ========================================================================

  static String _buildNewRequestEmailTemplate({
    required String adminName,
    required String requesterName,
    required String productName,
    required int requestedQuantity,
    required int currentStock,
    required String priority,
    required String companyName,
    String? notes,
    required int requestId,
  }) {
    final Map<String, Map<String, String>> priorityColors = {
      'low': {'bg': '#f0fdf4', 'border': '#86efac', 'text': '#065f46'},
      'medium': {'bg': '#eff6ff', 'border': '#93c5fd', 'text': '#1e40af'},
      'high': {'bg': '#fef3c7', 'border': '#fcd34d', 'text': '#92400e'},
      'urgent': {'bg': '#fee2e2', 'border': '#fca5a5', 'text': '#991b1b'},
    };

    final colors = priorityColors[priority.toLowerCase()] ?? priorityColors['medium']!;
    final priorityLabel = priority.toUpperCase();
    final priorityIcon = priority.toLowerCase() == 'urgent'
        ? '🚨'
        : priority.toLowerCase() == 'high'
        ? '⚠️'
        : '📋';

    final notesSection = (notes != null && notes.isNotEmpty)
        ? '''
        <table role="presentation" style="width: 100%; margin-top: 20px;">
          <tr>
            <td style="padding: 15px; background-color: #f9fafb; border-left: 4px solid #9ca3af; border-radius: 4px;">
              <h3 style="margin: 0 0 8px 0; color: #4b5563; font-size: 14px;">📝 Additional Notes</h3>
              <p style="margin: 0; color: #6b7280; font-size: 13px; line-height: 1.6;">$notes</p>
            </td>
          </tr>
        </table>
        '''
        : '';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Restock Request</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">🔔 New Restock Request</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - $companyName</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Hello <strong>$adminName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                <strong>$requesterName</strong> has created a new restock request that requires your review and approval.
                            </p>
                            <table role="presentation" style="width: 100%; margin-bottom: 25px;">
                                <tr>
                                    <td align="center">
                                        <div style="display: inline-block; padding: 8px 20px; background-color: ${colors['bg']}; border: 2px solid ${colors['border']}; border-radius: 20px;">
                                            <span style="color: ${colors['text']}; font-weight: 700; font-size: 14px;">
                                                $priorityIcon Priority: $priorityLabel
                                            </span>
                                        </div>
                                    </td>
                                </tr>
                            </table>
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #f9fafb; border-radius: 8px; overflow: hidden; border: 1px solid #e5e7eb;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #111827; font-size: 16px;">📦 Request Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px; width: 45%;">Product:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Requested Quantity:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$requestedQuantity units</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Current Stock:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$currentStock units</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Requested by:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">$requesterName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #6b7280; font-size: 14px;">Request ID:</td>
                                                <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">#$requestId</td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            $notesSection
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td style="padding: 20px; background-color: #dbeafe; border-left: 4px solid #3b82f6; border-radius: 4px;">
                                        <h3 style="margin: 0 0 10px 0; color: #1e40af; font-size: 16px;">👉 Action Required</h3>
                                        <p style="margin: 0; color: #1e40af; font-size: 14px; line-height: 1.6;">
                                            Please review this request in your MIA Tracker dashboard and approve or reject it as appropriate.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center">
                                        <a href="https://miatracker.com/restock-requests" style="display: inline-block; padding: 14px 32px; background-color: #2563eb; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 15px;">
                                            Review Request in Dashboard
                                        </a>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 30px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.6;">
                                If you have any questions about this request, please contact $requesterName directly.
                            </p>
                            <p style="margin: 20px 0 0 0; color: #374151; font-size: 14px;">
                                Best regards,<br><strong>MIA Tracker System</strong>
                            </p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">This is an automated email generated by MIA Tracker</p>
                            <p style="margin: 10px 0 0 0; color: #9ca3af; font-size: 12px;">© ${DateTime.now().year} MIA Tracker. All rights reserved.</p>
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
  // TEMPLATE HTML: NUEVA SOLICITUD PARA SUPPLY COMPANY
  // ========================================================================

  static String _buildNewRestockRequestTemplate({
    required String supplierName,
    required String productName,
    required int quantity,
    required String companyName,
    String? notes,
    required int requestId,
  }) {
    final notesSection = (notes != null && notes.isNotEmpty)
        ? '''
        <table role="presentation" style="width: 100%; margin-top: 20px;">
          <tr>
            <td style="padding: 15px; background-color: #f9fafb; border-left: 4px solid #9ca3af; border-radius: 4px;">
              <h3 style="margin: 0 0 8px 0; color: #4b5563; font-size: 14px;">📝 Additional Notes</h3>
              <p style="margin: 0; color: #6b7280; font-size: 13px; line-height: 1.6;">$notes</p>
            </td>
          </tr>
        </table>
        '''
        : '';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>New Restock Request</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #3B82F6 0%, #2563EB 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">🔔 New Restock Request</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - $companyName</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Dear <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                <strong>$companyName</strong> has created a new restock request for your products.
                            </p>
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #EFF6FF; border-radius: 8px; overflow: hidden; border: 1px solid #93C5FD;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #1E40AF; font-size: 16px;">📦 Request Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #1E40AF; font-size: 14px; width: 40%;">Product:</td>
                                                <td style="padding: 8px 0; color: #1E3A8A; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #1E40AF; font-size: 14px;">Quantity:</td>
                                                <td style="padding: 8px 0; color: #1E3A8A; font-size: 14px; font-weight: 600;">$quantity units</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #1E40AF; font-size: 14px;">Request ID:</td>
                                                <td style="padding: 8px 0; color: #1E3A8A; font-size: 14px; font-weight: 600;">#$requestId</td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            $notesSection
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td style="padding: 20px; background-color: #FEF3C7; border-left: 4px solid #F59E0B; border-radius: 4px;">
                                        <h3 style="margin: 0 0 10px 0; color: #92400E; font-size: 16px;">💡 Next Steps</h3>
                                        <p style="margin: 0; color: #78350F; font-size: 14px; line-height: 1.6;">
                                            Please review this request and confirm availability. We will notify you when approved.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 30px 0 0 0; color: #374151; font-size: 14px;">Best regards,<br><strong>$companyName</strong></p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">Automated email from MIA Tracker System</p>
                            <p style="margin: 10px 0 0 0; color: #9ca3af; font-size: 12px;">© ${DateTime.now().year} MIA Tracker. All rights reserved.</p>
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
  // 🔥 TEMPLATE HTML: APROBACIÓN CON QR CODE
  // ========================================================================

  static String _buildApprovalWithQRTemplate({
    required String supplierName,
    required String productName,
    required int quantity,
    required String companyName,
    DateTime? deliveryDate,
    String? internalNotes,
    required String qrImageUrl,
    required int requestId,
  }) {
    final deliverySection = deliveryDate != null
        ? '''
        <tr>
          <td style="padding: 20px 0; border-top: 1px solid #e5e7eb;">
            <h3 style="margin: 0 0 10px 0; color: #374151; font-size: 16px;">🚚 Estimated Delivery Date</h3>
            <p style="margin: 0; color: #6b7280; font-size: 16px; font-weight: bold;">
              ${DateFormat('dd/MM/yyyy').format(deliveryDate)}
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
              <h3 style="margin: 0 0 10px 0; color: #1e3a8a; font-size: 16px;">📝 Additional Notes</h3>
              <p style="margin: 0; color: #1e40af; font-size: 14px; line-height: 1.6;">$internalNotes</p>
            </td>
          </tr>
        </table>
        '''
        : '';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Request Approved</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #6B8E3D 0%, #5a7632 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">✅ Request Approved</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px;">Dear <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px;">
                                Your restock request has been <strong style="color: #6B8E3D;">approved</strong> by <strong>$companyName</strong>.
                            </p>
                            <table role="presentation" style="width: 100%; background-color: #f0fdf4; border-radius: 8px; border: 1px solid #86efac;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #065f46; font-size: 16px;">📦 Order Details</h3>
                                        <table role="presentation" style="width: 100%;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px; width: 40%;">Product:</td>
                                                <td style="padding: 8px 0; color: #064e3b; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px;">Quantity:</td>
                                                <td style="padding: 8px 0; color: #064e3b; font-size: 14px; font-weight: 600;">$quantity units</td>
                                            </tr>
                                            $deliverySection
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            $notesSection
                            <!-- 🔥 QR CODE SECTION -->
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center" style="padding: 30px; background-color: #f9fafb; border-radius: 8px; border: 2px solid #3b82f6;">
                                        <h3 style="margin: 0 0 15px 0; color: #1e40af; font-size: 18px; font-weight: 700;">📱 Scan to Complete Order</h3>
                                        <img src="$qrImageUrl" alt="QR Code" style="width: 250px; height: 250px; border: 3px solid #3b82f6; border-radius: 8px; display: block; margin: 0 auto;" />
                                        <p style="margin: 15px 0 0 0; color: #6b7280; font-size: 13px; font-weight: 500;">
                                            Present this QR code to the receiving team when delivery is complete
                                        </p>
                                        <p style="margin: 5px 0 0 0; color: #9ca3af; font-size: 11px;">Request ID: #$requestId</p>
                                    </td>
                                </tr>
                            </table>
                            <table role="presentation" style="width: 100%; margin-top: 25px;">
                                <tr>
                                    <td style="padding: 15px; background-color: #FEF3C7; border-left: 4px solid #F59E0B; border-radius: 4px;">
                                        <h3 style="margin: 0 0 10px 0; color: #92400E; font-size: 16px;">💡 Important</h3>
                                        <p style="margin: 0; color: #78350F; font-size: 14px; line-height: 1.6;">
                                            The QR code must be scanned by an administrator to confirm receipt and update inventory automatically.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 30px 0 0 0; color: #374151; font-size: 14px;">Best regards,<br><strong>$companyName</strong></p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">Automated email from MIA Tracker</p>
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
  // 🔥 TEMPLATE HTML: ORDEN COMPLETADA
  // ========================================================================

  static String _buildOrderCompletedTemplate({
    required String productName,
    required int quantity,
    required String companyName,
    required String completedDate,
    required int requestId,
  }) {
    return '''
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Order Completed</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table style="width: 600px; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #10B981 0%, #059669 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px;">✅ Order Completed</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px;">Dear Team,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px;">
                                The restock order has been successfully completed and inventory has been updated.
                            </p>
                            <table style="width: 100%; background-color: #ECFDF5; border-radius: 8px; border: 1px solid #6EE7B7;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #065F46; font-size: 16px;">📦 Completed Order</h3>
                                        <table style="width: 100%;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px; width: 40%;">Product:</td>
                                                <td style="padding: 8px 0; color: #064E3B; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px;">Quantity:</td>
                                                <td style="padding: 8px 0; color: #064E3B; font-size: 14px; font-weight: 600;">$quantity units</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px;">Completed:</td>
                                                <td style="padding: 8px 0; color: #064E3B; font-size: 14px; font-weight: 600;">${_formatDate(completedDate)}</td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px;">Request ID:</td>
                                                <td style="padding: 8px 0; color: #064E3B; font-size: 14px; font-weight: 600;">#$requestId</td>
                                            </tr>
                                        </table>
                                    </td>
                                </tr>
                            </table>
                            <table style="width: 100%; margin-top: 25px;">
                                <tr>
                                    <td style="padding: 15px; background-color: #DBEAFE; border-left: 4px solid #3B82F6; border-radius: 4px;">
                                        <p style="margin: 0; color: #1E40AF; font-size: 14px; line-height: 1.6;">
                                            ✅ Inventory has been automatically updated with the received quantity.
                                        </p>
                                    </td>
                                </tr>
                            </table>
                            <p style="margin: 30px 0 0 0; color: #374151; font-size: 14px;">Best regards,<br><strong>$companyName</strong></p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">Automated email from MIA Tracker</p>
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
      return DateFormat('dd/MM/yyyy HH:mm').format(date);
    } catch (e) {
      return isoDate;
    }
  }
}