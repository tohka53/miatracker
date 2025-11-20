// lib/services/low_stock_alert_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'email_service.dart';
import 'in_app_notification_service.dart';

/// Servicio para manejar alertas de stock bajo
/// Envía emails y notificaciones push cuando un producto alcanza su nivel de alerta
class LowStockAlertService {
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // 🔥 VERIFICAR Y PROCESAR ALERTAS PENDIENTES
  // ========================================================================

  /// Verifica si hay alertas pendientes y las procesa
  /// Este método debe llamarse periódicamente o al iniciar la app
  static Future<void> processPendingAlerts() async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('🔍 Verificando alertas pendientes de stock bajo');
      }

      // Obtener company_id del usuario actual
      final userId = AuthService.currentUser?.id;
      if (userId == null) {
        if (kDebugMode) print('⚠️ Usuario no autenticado');
        return;
      }

      final profile = await _supabase
          .from('profiles')
          .select('id_company')
          .eq('id', userId)
          .maybeSingle();

      final companyId = profile?['id_company'];
      if (companyId == null) {
        if (kDebugMode) print('⚠️ Usuario sin compañía asignada');
        return;
      }

      // Obtener alertas pendientes
      final alerts = await _supabase.rpc(
        'get_pending_stock_alerts',
        params: {'p_company_id': companyId},
      ) as List<dynamic>;

      if (alerts.isEmpty) {
        if (kDebugMode) print('✅ No hay alertas pendientes');
        return;
      }

      if (kDebugMode) {
        print('📋 Alertas pendientes encontradas: ${alerts.length}');
      }

      // Procesar cada alerta
      for (var alert in alerts) {
        await _processSingleAlert(alert, companyId);
      }

      if (kDebugMode) {
        print('✅ Todas las alertas procesadas');
        print('═══════════════════════════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando alertas: $e');
        print('═══════════════════════════════════════════════');
      }
    }
  }

  // ========================================================================
  // 🔥 PROCESAR UNA ALERTA INDIVIDUAL
  // ========================================================================

  static Future<void> _processSingleAlert(
      Map<String, dynamic> alert,
      int companyId,
      ) async {
    try {
      final alertId = alert['id'];
      final productName = alert['producto_nombre'] ?? 'Producto';
      final currentStock = alert['cantidad_actual'] ?? 0;
      final alertThreshold = alert['alerta_cantidad'] ?? 0;

      if (kDebugMode) {
        print('───────────────────────────────────────────────');
        print('📦 Procesando alerta:');
        print('   ID: $alertId');
        print('   Producto: $productName');
        print('   Stock actual: $currentStock');
        print('   Umbral de alerta: $alertThreshold');
      }

      // Obtener admins y supervisores
      final admins = await _supabase.rpc(
        'get_company_admins_and_supervisors',
        params: {'p_company_id': companyId},
      ) as List<dynamic>;

      if (admins.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No se encontraron admins/supervisores para notificar');
        }
        return;
      }

      if (kDebugMode) {
        print('👥 Admins/Supervisores encontrados: ${admins.length}');
      }

      // Enviar emails
      await _sendLowStockEmails(
        admins: admins,
        productName: productName,
        currentStock: currentStock,
        alertThreshold: alertThreshold,
        companyId: companyId,
      );

      // Marcar alerta como notificada
      await _supabase.rpc(
        'mark_alert_email_sent',
        params: {'p_alert_id': alertId},
      );

      if (kDebugMode) {
        print('✅ Alerta procesada y marcada como enviada');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error procesando alerta individual: $e');
      }
    }
  }

  // ========================================================================
  // 🔥 ENVIAR EMAILS DE ALERTA DE STOCK BAJO
  // ========================================================================

  static Future<void> _sendLowStockEmails({
    required List<dynamic> admins,
    required String productName,
    required int currentStock,
    required int alertThreshold,
    required int companyId,
  }) async {
    try {
      // Obtener nombre de la compañía
      String companyName = 'MIA Tracker';
      try {
        final company = await _supabase
            .from('company')
            .select('company_name')
            .eq('id_company', companyId)
            .maybeSingle();
        companyName = company?['company_name'] ?? companyName;
      } catch (e) {
        if (kDebugMode) print('⚠️ No se pudo obtener nombre de compañía');
      }

      // Recopilar emails válidos
      final List<String> adminEmails = [];
      for (var admin in admins) {
        final email = admin['email'] as String?;
        if (email != null && email.isNotEmpty && email.contains('@')) {
          adminEmails.add(email);
        }
      }

      if (adminEmails.isEmpty) {
        if (kDebugMode) {
          print('⚠️ No hay emails válidos para enviar alertas');
        }
        return;
      }

      if (kDebugMode) {
        print('📧 Enviando email a: ${adminEmails.join(", ")}');
      }

      // Construir HTML del email
      final htmlBody = _buildLowStockEmailTemplate(
        productName: productName,
        currentStock: currentStock,
        alertThreshold: alertThreshold,
        companyName: companyName,
      );

      // Enviar email a todos los admins/supervisores
      await EmailService.sendViaEdgeFunction(
        toEmail: adminEmails.join(';'), // Múltiples destinatarios separados por ;
        subject: '⚠️ Low Stock Alert - $productName',
        html: htmlBody,
      );

      if (kDebugMode) {
        print('✅ Emails enviados exitosamente a ${adminEmails.length} destinatarios');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enviando emails: $e');
      }
      rethrow;
    }
  }

  // ========================================================================
  // 📧 TEMPLATE HTML PARA EMAIL DE STOCK BAJO
  // ========================================================================

  static String _buildLowStockEmailTemplate({
    required String productName,
    required int currentStock,
    required int alertThreshold,
    required String companyName,
  }) {
    final stockPercentage = ((currentStock / alertThreshold) * 100).round();
    final stockColor = currentStock == 0 ? '#EF4444' : '#F59E0B';
    final stockIcon = currentStock == 0 ? '🔴' : '⚠️';
    final stockStatus = currentStock == 0 ? 'OUT OF STOCK' : 'LOW STOCK';

    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Low Stock Alert</title>
</head>
<body style="margin: 0; padding: 0; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif; background-color: #f3f4f6;">
    <table role="presentation" style="width: 100%; border-collapse: collapse;">
        <tr>
            <td align="center" style="padding: 40px 0;">
                <table role="presentation" style="width: 600px; border-collapse: collapse; background-color: #ffffff; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                    <!-- Header -->
                    <tr>
                        <td style="padding: 40px 40px 30px 40px; background: linear-gradient(135deg, $stockColor 0%, ${stockColor}dd 100%); border-radius: 8px 8px 0 0;">
                            <table role="presentation" style="width: 100%;">
                                <tr>
                                    <td align="center">
                                        <div style="width: 80px; height: 80px; background-color: rgba(255,255,255,0.2); border-radius: 50%; display: inline-flex; align-items: center; justify-content: center; margin-bottom: 20px;">
                                            <span style="font-size: 48px;">$stockIcon</span>
                                        </div>
                                        <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700; text-align: center;">
                                            $stockStatus
                                        </h1>
                                        <p style="margin: 10px 0 0 0; color: rgba(255,255,255,0.9); font-size: 16px; text-align: center;">
                                            Review inventory immediately
                                        </p>
                                    </td>
                                </tr>
                            </table>
                        </td>
                    </tr>

                    <!-- Content -->
                    <tr>
                        <td style="padding: 40px;">
                            <p style="margin: 0 0 20px 0; color: #374151; font-size: 16px; line-height: 1.6;">
                                Hello,
                            </p>
                            <p style="margin: 0 0 30px 0; color: #374151; font-size: 16px; line-height: 1.6;">
                                The following product has reached its stock alert level:
                            </p>

                            <!-- Product Info Card -->
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #FEF3C7; border-left: 4px solid $stockColor; border-radius: 4px; margin-bottom: 30px;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h2 style="margin: 0 0 15px 0; color: #92400E; font-size: 20px; font-weight: 700;">
                                            📦 $productName
                                        </h2>
                                        <table role="presentation" style="width: 100%;">
                                            <tr>
                                                <td style="padding: 8px 0; color: #78350F; font-size: 14px; font-weight: 600;">
                                                    Current stock:
                                                </td>
                                                <td style="padding: 8px 0; color: $stockColor; font-size: 18px; font-weight: 700; text-align: right;">
                                                    $currentStock units
                                                </td>
                                            </tr>
                                            <tr>
                                                <td style="padding: 8px 0; color: #78350F; font-size: 14px; font-weight: 600;">
                                                    Alert threshold:
                                                </td>
                                                <td style="padding: 8px 0; color: #78350F; font-size: 16px; font-weight: 600; text-align: right;">
                                                    $alertThreshold units
                                                </td>
                                            </tr>
                                            ${currentStock > 0 ? '''
                                            <tr>
                                                <td style="padding: 8px 0; color: #78350F; font-size: 14px; font-weight: 600;">
                                                    Stock level:
                                                </td>
                                                <td style="padding: 8px 0; text-align: right;">
                                                    <div style="background-color: #FDE68A; border-radius: 4px; padding: 4px 8px; display: inline-block;">
                                                        <span style="color: #92400E; font-size: 14px; font-weight: 700;">
                                                            $stockPercentage%
                                                        </span>
                                                    </div>
                                                </td>
                                            </tr>
                                            ''' : ''}
                                        </table>
                                    </td>
                                </tr>
                            </table>

                            <!-- Action Required -->
                            <table role="presentation" style="width: 100%; border-collapse: collapse; background-color: #DBEAFE; border-radius: 4px; margin-bottom: 30px;">
                                <tr>
                                    <td style="padding: 20px;">
                                        <h3 style="margin: 0 0 10px 0; color: #1E40AF; font-size: 16px; font-weight: 700;">
                                            ✅ Recommended actions:
                                        </h3>
                                        <ul style="margin: 0; padding-left: 20px; color: #1E3A8A;">
                                            <li style="margin-bottom: 8px;">Review inventory in the system</li>
                                            <li style="margin-bottom: 8px;">Check for pending orders</li>
                                            <li style="margin-bottom: 8px;">Consider creating a restock request</li>
                                            <li>Contact the supplier if necessary</li>
                                        </ul>
                                    </td>
                                </tr>
                            </table>

                            <!-- CTA Button -->
                            <table role="presentation" style="width: 100%; margin-top: 30px;">
                                <tr>
                                    <td align="center">
                                        <a href="miatracker://inventory" style="display: inline-block; padding: 16px 32px; background-color: #2563EB; color: #ffffff; text-decoration: none; font-weight: 600; font-size: 16px; border-radius: 6px; box-shadow: 0 2px 4px rgba(0,0,0,0.1);">
                                            View Inventory
                                        </a>
                                    </td>
                                </tr>
                            </table>

                            <p style="margin: 30px 0 0 0; color: #374151; font-size: 14px;">
                                Best regards,<br>
                                <strong>$companyName</strong>
                            </p>
                        </td>
                    </tr>

                    <!-- Footer -->
                    <tr>
                        <td style="padding: 30px; background-color: #f9fafb; border-radius: 0 0 8px 8px; text-align: center;">
                            <p style="margin: 0; color: #9ca3af; font-size: 13px;">
                                Automatic alert from MIA Tracker Inventory System
                            </p>
                            <p style="margin: 10px 0 0 0; color: #9ca3af; font-size: 12px;">
                                © ${DateTime.now().year} MIA Tracker. All rights reserved.
                            </p>
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
  // 🔥 OBTENER ALERTAS ACTIVAS (PARA MOSTRAR EN UI)
  // ========================================================================

  static Future<List<Map<String, dynamic>>> getActiveAlerts() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final profile = await _supabase
          .from('profiles')
          .select('id_company')
          .eq('id', userId)
          .maybeSingle();

      final companyId = profile?['id_company'];
      if (companyId == null) return [];

      final alerts = await _supabase.rpc(
        'get_pending_stock_alerts',
        params: {'p_company_id': companyId},
      ) as List<dynamic>;

      return alerts.map((alert) => Map<String, dynamic>.from(alert)).toList();
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo alertas activas: $e');
      return [];
    }
  }

  // ========================================================================
  // 🔥 MARCAR ALERTA COMO RESUELTA
  // ========================================================================

  static Future<bool> resolveAlert(int alertId) async {
    try {
      final result = await _supabase.rpc(
        'resolve_stock_alert',
        params: {'p_alert_id': alertId},
      );

      if (kDebugMode) {
        print('✅ Alerta $alertId marcada como resuelta');
      }

      return result == true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error resolviendo alerta: $e');
      }
      return false;
    }
  }

  // ========================================================================
  // 🔥 VERIFICAR MANUALMENTE SI UN PRODUCTO TIENE STOCK BAJO
  // ========================================================================

  static Future<bool> checkProductStockLevel(int productId) async {
    try {
      final product = await _supabase
          .from('inventario')
          .select('cantidad, alerta_cantidad')
          .eq('id_inventario', productId)
          .maybeSingle();

      if (product == null) return false;

      final cantidad = product['cantidad'] as int;
      final alertaCantidad = product['alerta_cantidad'] as int;

      return cantidad <= alertaCantidad;
    } catch (e) {
      if (kDebugMode) print('❌ Error verificando nivel de stock: $e');
      return false;
    }
  }

  // ========================================================================
  // 🔥 STREAM DE ALERTAS EN TIEMPO REAL
  // ========================================================================

  static Stream<List<Map<String, dynamic>>> alertsStream() {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('stock_alerts')
        .stream(primaryKey: ['id'])
        .eq('status', 'pending')
        .order('fecha_alerta', ascending: false)
        .asyncMap((data) async {
      // Filtrar por compañía del usuario
      final profile = await _supabase
          .from('profiles')
          .select('id_company')
          .eq('id', userId)
          .maybeSingle();

      final companyId = profile?['id_company'];
      if (companyId == null) return [];

      return data
          .where((alert) => alert['id_company'] == companyId)
          .map((alert) => Map<String, dynamic>.from(alert))
          .toList();
    });
  }
}