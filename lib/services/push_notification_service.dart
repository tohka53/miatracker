// lib/services/push_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class PushNotificationService {
  static final SupabaseClient _supabase = AuthService.client;

  // 🔥 ENVIAR NOTIFICACIÓN PUSH AL PROVEEDOR
  static Future<void> sendApprovalNotification({
    required int requestId,
    required int supplierId,
    required String productName,
    required int quantity,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('📲 ENVIANDO PUSH NOTIFICATION');
        print('   Request ID: $requestId');
        print('   Supplier ID: $supplierId');
      }

      // 1. Obtener FCM token del proveedor
      final supplier = await _supabase
          .from('supply_company')
          .select('fcm_token, user_id')
          .eq('id', supplierId)
          .single();

      final fcmToken = supplier['fcm_token'] as String?;

      if (fcmToken == null || fcmToken.isEmpty) {
        if (kDebugMode) print('⚠️ Proveedor sin FCM token registrado');
        return;
      }

      // 2. Enviar notificación vía Edge Function
      await _supabase.functions.invoke(
        'send-push-notification',
        body: {
          'token': fcmToken,
          'title': '✅ Request Approved',
          'body': 'Your restock request for $productName ($quantity units) has been approved',
          'data': {
            'type': 'restock_approved',
            'request_id': requestId,
            'deep_link': 'miatracker://restock/approved/$requestId',
          },
        },
      );

      if (kDebugMode) {
        print('✅ Push notification enviada exitosamente');
        print('═══════════════════════════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enviando push: $e');
        print('═══════════════════════════════════════════════');
      }
    }
  }
}