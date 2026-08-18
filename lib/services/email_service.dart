// lib/services/email_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../utils/mia_links.dart';

class EmailService {
  static const String _fromEmail = 'mark@miatracker.com';
  static const String _fromName = 'MIA Tracker System';
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // VERIFICAR CONFIGURACIÓN
  // ========================================================================

  static bool isConfigured() => true;

  /// Último error de envío (visible también en release, para diagnóstico en UI).
  static String? lastError;

  /// Última operación de envío realizada (para diagnóstico en UI).
  static Map<String, dynamic>? lastResult;

  static Map<String, dynamic> getConfigInfo() {
    return {
      'configured': true,
      'from_email': _fromEmail,
      'from_name': _fromName,
      'method': 'Supabase Edge Function',
      'last_error': lastError,
      'last_result': lastResult,
    };
  }

  /// Log que SÍ aparece en release builds (no solo en debug).
  static void _log(String msg) => debugPrint('[EmailService] $msg');

  // ========================================================================
  // 🏷️ ITEM NUMBER (CÓDIGO DE BARRAS) Y BOTÓN A LA APP
  // ========================================================================

  /// Item Number = el código de barras del producto (`inventario.codigo_barras`).
  ///
  /// Es la referencia que permite saber de QUÉ producto se habla sin depender
  /// del nombre. Se lee del inventario para que el correo lleve el código
  /// vigente aunque la solicitud sea vieja. Nunca lanza: si no se puede
  /// resolver devuelve `null` y el correo omite la fila.
  static Future<String?> resolveItemNumber(int? productId) async {
    if (productId == null || productId == 0) return null;
    try {
      final row = await _supabase
          .from('inventario')
          .select('codigo_barras')
          .eq('id_inventario', productId)
          .maybeSingle();

      return extractItemNumber(row?['codigo_barras']);
    } catch (e) {
      _log('⚠️ No se pudo resolver el item number de $productId: $e');
      return null;
    }
  }

  /// Item Number a partir del id de la SOLICITUD (cuando no se tiene el
  /// producto a mano). Nunca lanza.
  static Future<String?> resolveItemNumberByRequest(int requestId) async {
    try {
      final row = await _supabase
          .from('restock_requests')
          .select('id_inventario')
          .eq('id', requestId)
          .maybeSingle();

      return resolveItemNumber(row?['id_inventario'] as int?);
    } catch (e) {
      _log('⚠️ No se pudo resolver el item number de la solicitud $requestId: $e');
      return null;
    }
  }

  /// Saca el código legible de un `codigo_barras` JSONB.
  /// Formato real en la base: {"barcode_data": "650454"} (a veces con qr_data).
  static String? extractItemNumber(dynamic codigoBarras) {
    try {
      if (codigoBarras == null) return null;

      if (codigoBarras is String) {
        final trimmed = codigoBarras.trim();
        if (trimmed.isEmpty) return null;

        // La columna es JSONB, pero si alguna fila quedó guardada como TEXTO
        // JSON ('{"barcode_data":"650454"}') hay que decodificarla: si no, el
        // correo mostraría el blob entero como Item Number.
        if (trimmed.startsWith('{')) {
          try {
            return extractItemNumber(jsonDecode(trimmed));
          } catch (_) {
            return trimmed;
          }
        }

        return trimmed;
      }

      if (codigoBarras is Map) {
        for (final key in const ['barcode_data', 'upc', 'ean', 'qr_data']) {
          final value = codigoBarras[key];
          if (value != null && value.toString().trim().isNotEmpty) {
            return value.toString().trim();
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sufijo ` (Item #650454)` para los asuntos. Vacío si no hay código.
  static String _itemSuffix(String? itemNumber) =>
      (itemNumber == null || itemNumber.isEmpty) ? '' : ' (Item #$itemNumber)';

  /// Asunto del correo que recibe el proveedor.
  /// Antes decía "Restock Request Approved": para el proveedor no es una
  /// aprobación, es una ORDEN que se le está pidiendo.
  static String _orderRequestSubject(String? productName, String? itemNumber) {
    final product =
        (productName == null || productName.isEmpty) ? 'Product' : productName;
    return '📦 Order Request - $product${_itemSuffix(itemNumber)}';
  }

  /// Fila "Item Number" para las tablas de detalle de los correos.
  /// Devuelve '' cuando no hay código, para no dejar filas vacías.
  static String _itemNumberRow(
    String? itemNumber, {
    required String labelColor,
    required String valueColor,
  }) {
    if (itemNumber == null || itemNumber.isEmpty) return '';
    return '''
                                            <tr>
                                                <td style="padding: 8px 0; color: $labelColor; font-size: 14px;">Item Number:</td>
                                                <td style="padding: 8px 0; color: $valueColor; font-size: 14px; font-weight: 700; font-family: 'SF Mono', Menlo, Consolas, monospace; letter-spacing: 0.5px;">$itemNumber</td>
                                            </tr>
''';
  }

  /// Botón que abre la orden en MIA Tracker.
  ///
  /// Enlace https normal: en el navegador abre el Flutter web y, cuando el
  /// dominio quede verificado como App Link / Universal Link, abre la app
  /// instalada en Android o iOS con esa misma URL.
  static String _openInAppButton(
    String url, {
    String label = 'View Order in MIA Tracker',
    String color = '#2B5F8C',
  }) {
    return '''
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center">
                                        <a href="$url" target="_blank" style="display: inline-block; padding: 14px 32px; background-color: $color; color: #ffffff; text-decoration: none; border-radius: 6px; font-weight: 600; font-size: 15px;">
                                            $label
                                        </a>
                                        <p style="margin: 12px 0 0 0; color: #9ca3af; font-size: 12px;">
                                            Opens the MIA Tracker app if installed, otherwise your browser.
                                        </p>
                                    </td>
                                </tr>
                            </table>
''';
  }

  // ========================================================================
  // 🔑 RESOLVER EMAILS DE ADMINS  (con cascada de fallbacks)
  //
  // Motivo: `get_company_admins_and_supervisors` es el RPC que SÍ funciona en
  // producción (lo usa LowStockAlertService y sus correos llegan). Devuelve el
  // `email` directamente en la fila. `get_company_admins` puede no existir en
  // la base, y además obliga a un RPC extra `get_user_email` por cada admin.
  // Antes, si cualquiera de esos dos RPC fallaba, el envío moría en silencio.
  // ========================================================================

  static Future<List<String>> resolveCompanyAdminEmails(int companyId) async {
    final Set<String> emails = <String>{};

    bool isValid(dynamic v) =>
        v is String && v.trim().isNotEmpty && v.contains('@');

    void addAll(Iterable<dynamic> rows) {
      for (final row in rows) {
        if (row is Map && isValid(row['email'])) {
          emails.add((row['email'] as String).trim());
        }
      }
    }

    // --- Intento 1: RPC probado en producción (trae email en la fila) -------
    try {
      final rows = await _supabase.rpc(
        'get_company_admins_and_supervisors',
        params: {'p_company_id': companyId},
      );
      if (rows is List) {
        addAll(rows);
        _log('get_company_admins_and_supervisors -> ${rows.length} filas, '
            '${emails.length} emails válidos');
      }
    } catch (e) {
      _log('⚠️ get_company_admins_and_supervisors falló: $e');
    }

    if (emails.isNotEmpty) return emails.toList();

    // --- Intento 2: get_company_admins (+ get_user_email por admin) ---------
    try {
      final rows = await _supabase.rpc(
        'get_company_admins',
        params: {'p_company_id': companyId},
      );

      if (rows is List) {
        _log('get_company_admins -> ${rows.length} filas');
        addAll(rows); // por si esta versión ya trae email

        if (emails.isEmpty) {
          for (final admin in rows) {
            if (admin is! Map || admin['id'] == null) continue;
            try {
              final res = await _supabase.rpc(
                'get_user_email',
                params: {'user_uuid': admin['id']},
              );
              if (isValid(res)) emails.add((res as String).trim());
            } catch (e) {
              _log('⚠️ get_user_email(${admin['id']}) falló: $e');
            }
          }
        }
      }
    } catch (e) {
      _log('⚠️ get_company_admins falló: $e');
    }

    if (emails.isNotEmpty) return emails.toList();

    // --- Intento 3: leer profiles directo y pedir email uno por uno ---------
    try {
      final profiles = await _supabase
          .from('profiles')
          .select('id, full_name, role')
          .eq('id_company', companyId)
          .inFilter('role', ['admin', 'supervisor', 'owner']);

      _log('fallback profiles -> ${profiles.length} filas');

      for (final p in profiles) {
        try {
          final res = await _supabase.rpc(
            'get_user_email',
            params: {'user_uuid': p['id']},
          );
          if (isValid(res)) emails.add((res as String).trim());
        } catch (_) {/* ignorado: ya estamos en el último fallback */}
      }
    } catch (e) {
      _log('⚠️ fallback profiles falló: $e');
    }

    if (emails.isEmpty) {
      _log('❌ No se resolvió NINGÚN email de admin para company $companyId');
    }
    return emails.toList();
  }

  // ========================================================================
  // 🧪 DIAGNÓSTICO: probar la cadena completa sin adivinar
  // ========================================================================

  /// Envía un correo de prueba y devuelve el error EXACTO si falla.
  static Future<Map<String, dynamic>> sendTestEmail(String toEmail) async {
    _log('🧪 Enviando correo de prueba a $toEmail');
    return sendViaEdgeFunction(
      toEmail: toEmail,
      subject: '🧪 MIA Tracker - Test Email',
      html: '<h2>MIA Tracker</h2>'
          '<p>Si estás leyendo esto, la Edge Function y Resend funcionan.</p>'
          '<p>Enviado: ${DateTime.now().toIso8601String()}</p>',
    );
  }

  /// Revisa cada eslabón de la cadena de envío y reporta dónde se rompe.
  static Future<Map<String, dynamic>> diagnose({int? companyId}) async {
    final report = <String, dynamic>{};

    final session = _supabase.auth.currentSession;
    report['autenticado'] = session != null;
    report['user_id'] = _supabase.auth.currentUser?.id;

    if (companyId != null) {
      final emails = await resolveCompanyAdminEmails(companyId);
      report['admin_emails_encontrados'] = emails.length;
      report['admin_emails'] = emails;
    }

    final ping = await sendViaEdgeFunction(
      toEmail: 'delivered@resend.dev', // buzón de prueba oficial de Resend
      subject: '🧪 MIA Tracker - Diagnóstico',
      html: '<p>Ping de diagnóstico.</p>',
    );
    report['edge_function_ok'] = ping['success'] == true;
    report['edge_function_respuesta'] = ping;

    _log('🧪 Diagnóstico: $report');
    return report;
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
        lastError = null;
        lastResult = {'to': toEmail, 'subject': subject, 'ok': true};
        _log('✅ Enviado a $toEmail');
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
        lastError = errText;
        lastResult = {'to': toEmail, 'subject': subject, 'ok': false};
        _log('❌ Edge Function status ${res.status}: $errText');
        return {'success': false, 'error': errText};
      }
    } on FunctionException catch (e) {
      // supabase_flutter v2 LANZA esta excepción en respuestas >= 400.
      // `details` trae el cuerpo real de la Edge Function (el error de Resend),
      // que es justo lo que antes se perdía.
      final detail = e.details ?? e.reasonPhrase ?? 'sin detalle';
      final msg = 'Edge Function ${e.status}: $detail';
      lastError = msg;
      lastResult = {'to': toEmail, 'subject': subject, 'ok': false};
      _log('❌ $msg');
      return {'success': false, 'error': msg, 'status': e.status};
    } catch (e) {
      lastError = e.toString();
      lastResult = {'to': toEmail, 'subject': subject, 'ok': false};
      _log('❌ Error llamando Edge Function: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ========================================================================
  // 🔑 RESOLVER EL EMAIL DEL SOLICITANTE (quien manda la orden)
  //
  // `profiles` no guarda el correo y `auth.users` no es accesible desde el
  // cliente, así que hace falta el RPC `get_user_email`. Si el solicitante es
  // el usuario logueado nos ahorramos la llamada.
  // ========================================================================

  static Future<String?> resolveUserEmail(String? userId) async {
    if (userId == null || userId.isEmpty) return null;

    bool isValid(dynamic v) =>
        v is String && v.trim().isNotEmpty && v.contains('@');

    // --- Intento 1: es el usuario logueado (sin tocar la red) --------------
    final current = _supabase.auth.currentUser;
    if (current != null && current.id == userId && isValid(current.email)) {
      return current.email!.trim();
    }

    // --- Intento 2: RPC get_user_email -------------------------------------
    try {
      final res = await _supabase.rpc(
        'get_user_email',
        params: {'user_uuid': userId},
      );
      if (isValid(res)) return (res as String).trim();
    } catch (e) {
      _log('⚠️ get_user_email($userId) falló: $e');
    }

    // --- Intento 3: columna email en profiles (si existe en el esquema) -----
    try {
      final row = await _supabase
          .from('profiles')
          .select('email')
          .eq('id', userId)
          .maybeSingle();
      if (row != null && isValid(row['email'])) {
        return (row['email'] as String).trim();
      }
    } catch (_) {/* la columna puede no existir: es el último recurso */}

    _log('❌ No se pudo resolver el email del solicitante $userId');
    return null;
  }

  /// Nombre de la compañía. Centralizado para no repetir el bug de leer
  /// `['name']` cuando la columna real es `company_name`.
  static Future<String> resolveCompanyName(int companyId) async {
    try {
      final row = await _supabase
          .from('company')
          .select('company_name')
          .eq('id_company', companyId)
          .maybeSingle();
      final name = row?['company_name'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
    } catch (e) {
      _log('⚠️ No se pudo resolver el nombre de la compañía $companyId: $e');
    }
    return 'MIA Tracker';
  }

  /// Nombre visible del solicitante (para los correos).
  static Future<String> resolveUserName(String? userId) async {
    if (userId == null || userId.isEmpty) return 'Usuario';
    try {
      final row = await _supabase
          .from('profiles')
          .select('full_name, username')
          .eq('id', userId)
          .maybeSingle();
      final name = row?['full_name'] ?? row?['username'];
      if (name is String && name.trim().isNotEmpty) return name.trim();
    } catch (e) {
      _log('⚠️ No se pudo resolver el nombre del usuario $userId: $e');
    }
    return 'Usuario';
  }

  // ========================================================================
  // 📢 NOTIFICACIONES COMPLETAS (SOLICITANTE + JEFE/ADMINS + PROVEEDOR)
  //
  // Estos tres métodos son los ÚNICOS que deben llamarse desde los servicios
  // de restock. Cada uno cubre a los tres destinatarios de una etapa y nunca
  // lanza excepción: si un destinatario falla, los otros dos igual reciben.
  // ========================================================================

  /// Etapa 1 — La orden se acaba de crear.
  /// Solicitante: confirmación · Jefe/admins: solicitud a aprobar · Proveedor: aviso.
  static Future<Map<String, dynamic>> notifyRestockCreated({
    required int requestId,
    required int companyId,
    required String requesterUserId,
    required String productName,
    required int requestedQuantity,
    required int currentStock,
    required String priority,
    int? supplierId,
    String? notes,
    int? productId,
  }) async {
    final sent = <String, bool>{
      'requester': false,
      'admins': false,
      'supplier': false,
    };

    _log('📢 notifyRestockCreated #$requestId (producto: $productName)');

    final companyName = await resolveCompanyName(companyId);
    final requesterName = await resolveUserName(requesterUserId);

    // Item Number = código de barras del producto. Va en los tres correos.
    final itemNumber = productId != null
        ? await resolveItemNumber(productId)
        : await resolveItemNumberByRequest(requestId);

    // ---------- 1) JEFE / ADMINS -------------------------------------------
    try {
      // sendRestockRequestToAdmins no devuelve resultado: reporta por lastError.
      // Lo limpiamos antes para no leer el error de un envío anterior.
      lastError = null;
      await sendRestockRequestToAdmins(
        requestId: requestId,
        productId: productId ?? 0,
        productName: productName,
        requestedQuantity: requestedQuantity,
        currentStock: currentStock,
        priority: priority,
        companyId: companyId,
        notes: notes,
        itemNumber: itemNumber,
      );
      sent['admins'] = lastError == null;
    } catch (e) {
      _log('⚠️ Falló el correo a admins: $e');
    }

    // ---------- 2) SOLICITANTE ---------------------------------------------
    try {
      final requesterEmail = await resolveUserEmail(requesterUserId);
      if (requesterEmail != null) {
        final res = await sendViaEdgeFunction(
          toEmail: requesterEmail,
          subject: '📤 Restock Request Sent - $productName${_itemSuffix(itemNumber)}',
          html: _buildStatusUpdateTemplate(
            title: '📤 Restock Request Sent',
            headerFrom: '#3B82F6',
            headerTo: '#1E40AF',
            greeting: 'Hello $requesterName,',
            intro:
            'Your restock request has been submitted and is now waiting for approval.',
            ctaUrl: MiaLinks.restockRequest(requestId),
            rows: {
              'Product': productName,
              if (itemNumber != null) 'Item Number': itemNumber,
              'Requested Quantity': '$requestedQuantity units',
              'Current Stock': '$currentStock units',
              'Priority': priority.toUpperCase(),
              'Status': 'Pending approval',
              'Request ID': '#$requestId',
              if (notes != null && notes.trim().isNotEmpty) 'Notes': notes,
            },
            noteTitle: 'ℹ️ What happens next',
            noteBody:
            'An administrator will review your request. You will receive another '
                'email as soon as it is approved or declined.',
            noteColor: '#3B82F6',
            companyName: companyName,
          ),
        );
        sent['requester'] = res['success'] == true;
      }
    } catch (e) {
      _log('⚠️ Falló el correo al solicitante: $e');
    }

    // ---------- 3) PROVEEDOR ------------------------------------------------
    if (supplierId != null) {
      try {
        await sendNewRestockRequestToSupplier(
          requestId: requestId,
          supplierId: supplierId,
          productName: productName,
          quantity: requestedQuantity,
          companyId: companyId,
          notes: notes,
          itemNumber: itemNumber,
        );
        sent['supplier'] = true;
      } catch (e) {
        _log('⚠️ Falló el correo al proveedor: $e');
      }
    } else {
      _log('ℹ️ La solicitud #$requestId no tiene proveedor asignado');
    }

    _log('📢 notifyRestockCreated #$requestId -> $sent');
    lastResult = {'stage': 'created', 'request_id': requestId, ...sent};
    return {'success': sent.values.any((v) => v), ...sent};
  }

  /// Etapa 2 — La orden fue aprobada.
  /// Proveedor: orden con QR · Solicitante y jefe/admins: aviso de aprobación.
  static Future<Map<String, dynamic>> notifyRestockApproved({
    required int requestId,
    required int supplierId,
    required int companyId,
    DateTime? deliveryDate,
    String? internalNotes,
  }) async {
    final sent = <String, bool>{
      'requester': false,
      'admins': false,
      'supplier': false,
    };

    _log('📢 notifyRestockApproved #$requestId');

    final request = await _supabase
        .from('restock_requests')
        .select('*')
        .eq('id', requestId)
        .maybeSingle();

    if (request == null) {
      _log('❌ Solicitud #$requestId no encontrada');
      return {'success': false, ...sent};
    }

    final productName = (request['nombre_producto'] ?? 'Product').toString();
    final quantity = (request['cantidad_solicitada'] as int?) ?? 0;
    final currentStock = (request['stock_actual'] as int?) ?? 0;
    final companyName = await resolveCompanyName(companyId);
    final requesterName = await resolveUserName(request['user_id']?.toString());
    final itemNumber = await resolveItemNumber(request['id_inventario'] as int?);

    // ---------- 1) PROVEEDOR (con QR) --------------------------------------
    try {
      await sendApprovalEmailWithQR(
        requestId: requestId,
        supplierId: supplierId,
        deliveryDate: deliveryDate,
        internalNotes: internalNotes,
        // ⚠️ Formato fijo: qr_complete_order_screen.dart valida este prefijo.
        qrData: MiaLinks.orderQrData(requestId),
        itemNumber: itemNumber,
      );
      sent['supplier'] = true;
    } catch (e) {
      _log('⚠️ Falló el correo al proveedor: $e');
    }

    // Datos del proveedor para mostrarlos en los otros dos correos.
    String supplierName = 'Supplier';
    try {
      final sup = await _supabase
          .from('supply_company')
          .select('name')
          .eq('id', supplierId)
          .maybeSingle();
      if (sup?['name'] is String) supplierName = sup!['name'];
    } catch (_) {}

    final rows = <String, String>{
      'Product': productName,
      if (itemNumber != null) 'Item Number': itemNumber,
      'Approved Quantity': '$quantity units',
      'Current Stock': '$currentStock units',
      'Stock After Delivery': '${currentStock + quantity} units',
      'Supplier': supplierName,
      if (deliveryDate != null)
        'Estimated Delivery': DateFormat('dd/MM/yyyy').format(deliveryDate),
      'Request ID': '#$requestId',
      if (internalNotes != null && internalNotes.trim().isNotEmpty)
        'Notes': internalNotes,
    };

    final html = _buildStatusUpdateTemplate(
      title: '✅ Restock Request Approved',
      headerFrom: '#10B981',
      headerTo: '#059669',
      greeting: 'Hello,',
      intro:
      'The restock request created by $requesterName has been approved and the '
          'supplier has been notified.',
      rows: rows,
      noteTitle: '📦 Next step',
      noteBody:
      'The supplier received the order together with a QR code. Scanning that QR '
          'on delivery will complete the order and update the inventory automatically.',
      noteColor: '#10B981',
      companyName: companyName,
      ctaUrl: MiaLinks.restockRequest(requestId),
    );

    // ---------- 2) SOLICITANTE ---------------------------------------------
    try {
      final requesterEmail = await resolveUserEmail(request['user_id']?.toString());
      if (requesterEmail != null) {
        final res = await sendViaEdgeFunction(
          toEmail: requesterEmail,
          subject:
              '✅ Your Restock Request Was Approved - $productName${_itemSuffix(itemNumber)}',
          html: html,
        );
        sent['requester'] = res['success'] == true;
      }
    } catch (e) {
      _log('⚠️ Falló el correo al solicitante: $e');
    }

    // ---------- 3) JEFE / ADMINS -------------------------------------------
    try {
      final adminEmails = await resolveCompanyAdminEmails(companyId);
      if (adminEmails.isNotEmpty) {
        final res = await sendViaEdgeFunction(
          toEmail: adminEmails.join(';'),
          subject:
              '✅ Restock Request Approved - $productName${_itemSuffix(itemNumber)}',
          html: html,
        );
        sent['admins'] = res['success'] == true;
      }
    } catch (e) {
      _log('⚠️ Falló el correo a admins: $e');
    }

    _log('📢 notifyRestockApproved #$requestId -> $sent');
    lastResult = {'stage': 'approved', 'request_id': requestId, ...sent};
    return {'success': sent.values.any((v) => v), ...sent};
  }

  /// Etapa 3 — La orden fue rechazada.
  /// Solicitante: el motivo · Jefe/admins: registro · Proveedor: cancelación.
  static Future<Map<String, dynamic>> notifyRestockRejected({
    required int requestId,
    required int companyId,
    required String reason,
    int? supplierId,
  }) async {
    final sent = <String, bool>{
      'requester': false,
      'admins': false,
      'supplier': false,
    };

    _log('📢 notifyRestockRejected #$requestId');

    final request = await _supabase
        .from('restock_requests')
        .select('*')
        .eq('id', requestId)
        .maybeSingle();

    if (request == null) {
      _log('❌ Solicitud #$requestId no encontrada');
      return {'success': false, ...sent};
    }

    final productName = (request['nombre_producto'] ?? 'Product').toString();
    final quantity = (request['cantidad_solicitada'] as int?) ?? 0;
    final companyName = await resolveCompanyName(companyId);
    final requesterName = await resolveUserName(request['user_id']?.toString());
    final itemNumber = await resolveItemNumber(request['id_inventario'] as int?);

    final html = _buildStatusUpdateTemplate(
      title: '❌ Restock Request Declined',
      headerFrom: '#EF4444',
      headerTo: '#B91C1C',
      greeting: 'Hello,',
      intro:
      'The restock request created by $requesterName has been declined.',
      rows: {
        'Product': productName,
        if (itemNumber != null) 'Item Number': itemNumber,
        'Requested Quantity': '$quantity units',
        'Status': 'Declined',
        'Request ID': '#$requestId',
      },
      noteTitle: '📝 Reason',
      noteBody: reason,
      noteColor: '#EF4444',
      companyName: companyName,
      ctaUrl: MiaLinks.restockRequest(requestId),
    );

    // ---------- 1) SOLICITANTE ---------------------------------------------
    try {
      final requesterEmail = await resolveUserEmail(request['user_id']?.toString());
      if (requesterEmail != null) {
        final res = await sendViaEdgeFunction(
          toEmail: requesterEmail,
          subject:
              '❌ Your Restock Request Was Declined - $productName${_itemSuffix(itemNumber)}',
          html: html,
        );
        sent['requester'] = res['success'] == true;
      }
    } catch (e) {
      _log('⚠️ Falló el correo al solicitante: $e');
    }

    // ---------- 2) JEFE / ADMINS -------------------------------------------
    try {
      final adminEmails = await resolveCompanyAdminEmails(companyId);
      if (adminEmails.isNotEmpty) {
        final res = await sendViaEdgeFunction(
          toEmail: adminEmails.join(';'),
          subject:
              '❌ Restock Request Declined - $productName${_itemSuffix(itemNumber)}',
          html: html,
        );
        sent['admins'] = res['success'] == true;
      }
    } catch (e) {
      _log('⚠️ Falló el correo a admins: $e');
    }

    // ---------- 3) PROVEEDOR ------------------------------------------------
    final finalSupplierId = supplierId ?? request['id_supply_company'];
    if (finalSupplierId != null) {
      try {
        final supplier = await _supabase
            .from('supply_company')
            .select('name, email')
            .eq('id', finalSupplierId)
            .maybeSingle();

        final email = supplier?['email'];
        if (email is String && email.trim().isNotEmpty) {
          final res = await sendRejectionEmail(
            toEmail: email.trim(),
            supplierName: (supplier?['name'] ?? 'Supplier').toString(),
            productName: productName,
            quantity: quantity,
            companyName: companyName,
            rejectionReason: reason,
            itemNumber: itemNumber,
          );
          sent['supplier'] = res['success'] == true;
        } else {
          _log('ℹ️ El proveedor $finalSupplierId no tiene email configurado');
        }
      } catch (e) {
        _log('⚠️ Falló el correo al proveedor: $e');
      }
    }

    _log('📢 notifyRestockRejected #$requestId -> $sent');
    lastResult = {'stage': 'rejected', 'request_id': requestId, ...sent};
    return {'success': sent.values.any((v) => v), ...sent};
  }

  // ========================================================================
  // TEMPLATE GENÉRICO DE CAMBIO DE ESTADO (solicitante / jefe)
  // Cualquier valor que se le pase se renderiza: no hay campos silenciosos.
  // ========================================================================

  static String _buildStatusUpdateTemplate({
    required String title,
    required String headerFrom,
    required String headerTo,
    required String greeting,
    required String intro,
    required Map<String, String> rows,
    required String companyName,
    String? noteTitle,
    String? noteBody,
    String? noteColor,
    String? ctaUrl,
  }) {
    final rowsHtml = rows.entries.map((e) => '''
      <tr>
        <td style="padding: 8px 0; color: #6b7280; font-size: 14px; width: 45%;">${e.key}:</td>
        <td style="padding: 8px 0; color: #111827; font-size: 14px; font-weight: 600;">${e.value}</td>
      </tr>''').join();

    final noteHtml = (noteTitle != null && noteBody != null)
        ? '''
      <table role="presentation" style="width: 100%; margin-top: 25px;">
        <tr>
          <td style="padding: 18px; background-color: #f9fafb; border-left: 4px solid ${noteColor ?? '#6b7280'}; border-radius: 4px;">
            <h3 style="margin: 0 0 8px 0; color: #374151; font-size: 15px;">$noteTitle</h3>
            <p style="margin: 0; color: #6b7280; font-size: 14px; line-height: 1.6;">$noteBody</p>
          </td>
        </tr>
      </table>'''
        : '';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$title</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0,0,0,0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, $headerFrom 0%, $headerTo 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 26px; font-weight: 700;">$title</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255,255,255,0.9); font-size: 15px;">MIA Tracker - $companyName</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 16px 0; color: #374151; font-size: 16px;">$greeting</p>
                            <p style="margin: 0 0 28px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">$intro</p>

                            <table role="presentation" style="width: 100%; background-color: #f9fafb; border-radius: 8px; border: 1px solid #e5e7eb;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 12px 0; color: #111827; font-size: 16px;">📦 Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            $rowsHtml
                                        </table>
                                    </td>
                                </tr>
                            </table>

                            $noteHtml

${_openInAppButton(ctaUrl ?? MiaLinks.appHome, label: 'Open in MIA Tracker', color: headerFrom)}

                            <p style="margin: 30px 0 0 0; color: #374151; font-size: 14px;">
                                Best regards,<br><strong>$companyName</strong>
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

      final itemNumber = await resolveItemNumber(request['id_inventario'] as int?);

      final htmlBody = _buildApprovalEmailTemplate(
        supplierName: supplier['name'],
        productName: request['nombre_producto'] ?? 'Producto',
        quantity: request['cantidad_solicitada'] ?? 0,
        companyName: companyName,
        internalNotes: request['internal_notes'],
        estimatedDeliveryDate: request['estimated_delivery_date'],
        itemNumber: itemNumber,
        requestId: requestId,
      );

      final result = await sendViaEdgeFunction(
        toEmail: supplier['email'],
        subject: _orderRequestSubject(
          request['nombre_producto']?.toString(),
          itemNumber,
        ),
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
    String? itemNumber,
    int? productId,
    int? requestId,
  }) async {
    try {
      final resolvedItemNumber = itemNumber ?? await resolveItemNumber(productId);

      final htmlBody = _buildApprovalEmailTemplate(
        supplierName: supplierName,
        productName: productName,
        quantity: quantity,
        companyName: companyName,
        internalNotes: internalNotes,
        estimatedDeliveryDate: estimatedDeliveryDate,
        itemNumber: resolvedItemNumber,
        requestId: requestId,
      );

      return await sendViaEdgeFunction(
        toEmail: toEmail,
        subject: _orderRequestSubject(productName, resolvedItemNumber),
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
    String? itemNumber,
    int? productId,
  }) async {
    try {
      final resolvedItemNumber = itemNumber ?? await resolveItemNumber(productId);

      final htmlBody = _buildRejectionEmailTemplate(
        supplierName: supplierName,
        productName: productName,
        quantity: quantity,
        companyName: companyName,
        rejectionReason: rejectionReason,
        itemNumber: resolvedItemNumber,
      );

      return await sendViaEdgeFunction(
        toEmail: toEmail,
        subject:
            '❌ Restock Request Rejected - $productName${_itemSuffix(resolvedItemNumber)}',
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
    String? itemNumber,
    int? productId,
  }) async {
    return await sendRejectionEmail(
      toEmail: toEmail,
      supplierName: supplierName,
      productName: productName,
      quantity: quantity,
      companyName: companyName,
      rejectionReason: rejectionReason,
      itemNumber: itemNumber,
      productId: productId,
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
    int? productId,
    String? itemNumber,
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

      final resolvedItemNumber = itemNumber ??
          await resolveItemNumber(productId) ??
          await resolveItemNumberByRequest(requestId);

      final htmlBody = _buildNewRestockRequestTemplate(
        supplierName: supplier['name'],
        productName: productName,
        quantity: quantity,
        companyName: companyName,
        notes: notes,
        requestId: requestId,
        itemNumber: resolvedItemNumber,
      );

      final result = await sendViaEdgeFunction(
        toEmail: supplier['email'],
        subject: _orderRequestSubject(productName, resolvedItemNumber),
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
    String? itemNumber,
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
      final qrImageUrl = MiaLinks.qrImageUrl(qrData);

      if (kDebugMode) print('✅ QR Image URL: $qrImageUrl');

      // 4b. Item Number (código de barras del producto)
      final resolvedItemNumber =
          itemNumber ?? await resolveItemNumber(request['id_inventario'] as int?);

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
        itemNumber: resolvedItemNumber,
      );

      // 6. Enviar email
      final result = await sendViaEdgeFunction(
        toEmail: supplier['email'],
        subject: _orderRequestSubject(
          request['nombre_producto']?.toString(),
          resolvedItemNumber,
        ),
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
    String? itemNumber,
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

      // ✅ Resolución robusta con cascada de fallbacks (ver
      // resolveCompanyAdminEmails). Antes esto dependía únicamente de
      // get_company_admins + get_user_email y moría en silencio si fallaban.
      final List<String> failedAdmins = [];
      final adminEmails = await resolveCompanyAdminEmails(companyId);

      if (adminEmails.isEmpty) {
        lastError =
            'No se encontró ningún email de admin para la compañía $companyId';
        _log('❌ $lastError');
        return;
      }

      _log('✅ Admins resueltos: ${adminEmails.length} -> ${adminEmails.join(", ")}');

      final String recipientsString = adminEmails.join(';');

      // 🔥 GENERAR QR DATA
      // ⚠️ Formato fijo: qr_complete_order_screen.dart valida este prefijo.
      final qrData = MiaLinks.orderQrData(requestId);
      final qrImageUrl = MiaLinks.qrImageUrl(qrData);

      // Item Number = código de barras del producto.
      final resolvedItemNumber = itemNumber ??
          await resolveItemNumber(productId) ??
          await resolveItemNumberByRequest(requestId);

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
        itemNumber: resolvedItemNumber,
      );

      if (kDebugMode) {
        print('✅ Template HTML con QR generado');
        print('📧 Llamando Edge Function...');
      }

      final result = await sendViaEdgeFunction(
        toEmail: recipientsString,
        subject:
            '🔔 New Restock Request - $productName${_itemSuffix(resolvedItemNumber)}',
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
        _log('❌ Error enviando email a admins: ${result['error']}');
      }
    } catch (e, stackTrace) {
      lastError = 'sendRestockRequestToAdmins: $e';
      _log('❌ ERROR CRÍTICO en sendRestockRequestToAdmins: $e');
      if (kDebugMode) print('   Stack: $stackTrace');
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
    String? itemNumber,
  }) {
    final itemNumberRow = _itemNumberRow(
      itemNumber,
      labelColor: '#6b7280',
      valueColor: '#111827',
    );

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
$itemNumberRow
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
${_openInAppButton(MiaLinks.restockRequest(requestId), label: 'Review Request in MIA Tracker', color: '#2563eb')}

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

      // 2. Obtener proveedor (puede no existir: no debe tumbar el resto de envíos)
      Map<String, dynamic>? supplier;
      if (request['id_supply_company'] != null) {
        supplier = await _supabase
            .from('supply_company')
            .select('*')
            .eq('id', request['id_supply_company'])
            .maybeSingle();
      }
      if (supplier == null) {
        _log('ℹ️ La solicitud #$requestId no tiene proveedor: se notifica solo '
            'a admins y solicitante');
      }

      // 3. Obtener admins (resolución robusta con fallbacks)
      final adminEmails = await resolveCompanyAdminEmails(companyId);

      // 4. Obtener compañía
      final companyName = await resolveCompanyName(companyId);

      // 4b. Item Number (código de barras del producto)
      final itemNumber = await resolveItemNumber(request['id_inventario'] as int?);

      // 5. Construir HTML
      final htmlBody = _buildOrderCompletedTemplate(
        productName: request['nombre_producto'],
        quantity: request['cantidad_solicitada'],
        companyName: companyName,
        completedDate: request['fecha_completado'] ?? DateTime.now().toIso8601String(),
        requestId: requestId,
        itemNumber: itemNumber,
      );

      // 6. 🔥 ENVIAR A PROVEEDOR
      if (supplier != null &&
          supplier['email'] != null &&
          supplier['email'].toString().isNotEmpty) {
        if (kDebugMode) print('📧 Enviando email a proveedor: ${supplier['email']}');

        await sendViaEdgeFunction(
          toEmail: supplier['email'],
          subject:
              '✅ Order Completed - ${request['nombre_producto']}${_itemSuffix(itemNumber)}',
          html: htmlBody,
        );

        if (kDebugMode) print('✅ Email enviado al proveedor');
      }

      // 7. 🔥 ENVIAR A ADMINS (ya resueltos en el paso 3)
      if (adminEmails.isNotEmpty) {
        if (kDebugMode) {
          print('📧 Enviando email a ${adminEmails.length} admins');
          print('   Destinatarios: ${adminEmails.join(", ")}');
        }

        await sendViaEdgeFunction(
          toEmail: adminEmails.join(';'),
          subject:
              '✅ Restock Completed - ${request['nombre_producto']}${_itemSuffix(itemNumber)}',
          html: htmlBody,
        );

        if (kDebugMode) print('✅ Email enviado a admins');
      }

      // 8. 🔥 ENVIAR AL SOLICITANTE (quien creó la orden)
      final requesterEmail = await resolveUserEmail(request['user_id']?.toString());
      if (requesterEmail != null) {
        await sendViaEdgeFunction(
          toEmail: requesterEmail,
          subject:
              '✅ Your Restock Order Was Completed - ${request['nombre_producto']}${_itemSuffix(itemNumber)}',
          html: htmlBody,
        );
        _log('✅ Email de completado enviado al solicitante');
      } else {
        _log('⚠️ No se pudo notificar al solicitante de #$requestId');
      }

      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('✅ Emails de completado enviados exitosamente');
        print('   - Proveedor: ${supplier?['email'] ?? "sin proveedor"}');
        print('   - Admins: ${adminEmails.length}');
        print('   - Solicitante: ${requesterEmail ?? "no resuelto"}');
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
    String? itemNumber,
    int? requestId,
  }) {
    final itemNumberRow = _itemNumberRow(
      itemNumber,
      labelColor: '#047857',
      valueColor: '#064e3b',
    );

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
    <title>Order Request</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #6B8E3D 0%, #5a7632 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">📦 Order Request</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - Maintenance Inventory Asset Tracker</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Dear <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                <strong>$companyName</strong> is placing the following <strong style="color: #6B8E3D;">order request</strong> with you. Please confirm availability and delivery.
                            </p>
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #f0fdf4; border-radius: 8px; overflow: hidden; border: 1px solid #86efac;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #065f46; font-size: 16px;">📦 Order Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #047857; font-size: 14px; width: 40%;">Product:</td>
                                                <td style="padding: 8px 0; color: #064e3b; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
$itemNumberRow
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
${_openInAppButton(requestId != null ? MiaLinks.restockRequest(requestId) : MiaLinks.appHome, color: '#6B8E3D')}
                            <p style="margin: 30px 0 0 0; color: #6b7280; font-size: 14px; line-height: 1.6;">
                                If you have any questions, please contact us at <a href="mailto:$_fromEmail" style="color: #6B8E3D;">$_fromEmail</a>.
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
    String? itemNumber,
  }) {
    final itemNumberRow = _itemNumberRow(
      itemNumber,
      labelColor: '#7f1d1d',
      valueColor: '#450a0a',
    );

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
$itemNumberRow
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
    String? itemNumber,
  }) {
    final itemNumberRow = _itemNumberRow(
      itemNumber,
      labelColor: '#6b7280',
      valueColor: '#111827',
    );

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
$itemNumberRow
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
${_openInAppButton(MiaLinks.restockRequest(requestId), label: 'Review Request in MIA Tracker', color: '#2563eb')}
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
    String? itemNumber,
  }) {
    final itemNumberRow = _itemNumberRow(
      itemNumber,
      labelColor: '#1E40AF',
      valueColor: '#1E3A8A',
    );

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
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">📦 Order Request</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker - $companyName</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">Dear <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px; line-height: 1.6;">
                                <strong>$companyName</strong> is placing the following order request for your products.
                            </p>
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #EFF6FF; border-radius: 8px; overflow: hidden; border: 1px solid #93C5FD;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 15px 0; color: #1E40AF; font-size: 16px;">📦 Order Details</h3>
                                        <table role="presentation" style="width: 100%; border-collapse: collapse;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #1E40AF; font-size: 14px; width: 40%;">Product:</td>
                                                <td style="padding: 8px 0; color: #1E3A8A; font-size: 14px; font-weight: 600;">$productName</td>
                                            </tr>
$itemNumberRow
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
                                            Please review this order request and confirm availability. We will notify you when approved.
                                        </p>
                                    </td>
                                </tr>
                            </table>
${_openInAppButton(MiaLinks.restockRequest(requestId))}
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
    String? itemNumber,
  }) {
    final itemNumberRow = _itemNumberRow(
      itemNumber,
      labelColor: '#047857',
      valueColor: '#064e3b',
    );

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
    <title>Order Request</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; max-width: 100%; background-color: #ffffff; border-radius: 8px; box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);">
                    <tr>
                        <td style="background: linear-gradient(135deg, #6B8E3D 0%, #5a7632 100%); padding: 40px; border-radius: 8px 8px 0 0; text-align: center;">
                            <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700;">📦 Order Request</h1>
                            <p style="margin: 10px 0 0 0; color: rgba(255, 255, 255, 0.9); font-size: 16px;">MIA Tracker</p>
                        </td>
                    </tr>
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px;">Dear <strong>$supplierName</strong>,</p>
                            <p style="margin: 0 0 30px 0; color: #6b7280; font-size: 15px;">
                                <strong>$companyName</strong> is placing the following <strong style="color: #6B8E3D;">order request</strong> with you.
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
$itemNumberRow
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
${_openInAppButton(MiaLinks.restockRequest(requestId), color: '#6B8E3D')}
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
    String? itemNumber,
  }) {
    final itemNumberRow = _itemNumberRow(
      itemNumber,
      labelColor: '#047857',
      valueColor: '#064E3B',
    );

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
$itemNumberRow
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
${_openInAppButton(MiaLinks.restockRequest(requestId), color: '#10B981')}
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