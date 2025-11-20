// lib/services/in_app_notification_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class InAppNotificationService {
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // 🔥 CREAR NOTIFICACIÓN IN-APP EN LA BASE DE DATOS
  // ========================================================================

  static Future<void> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      if (kDebugMode) {
        print('═══════════════════════════════════════════════');
        print('🔔 CREANDO NOTIFICACIÓN IN-APP');
        print('   User ID: $userId');
        print('   Title: $title');
        print('   Type: $type');
      }

      await _supabase.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'message': message,
        'type': type,
        'data': data,
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('✅ Notificación in-app creada exitosamente');
        print('═══════════════════════════════════════════════');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error creando notificación in-app: $e');
        print('═══════════════════════════════════════════════');
      }
    }
  }

  // ========================================================================
  // 🔥 NOTIFICACIÓN DE APROBACIÓN DE RESTOCK
  // ========================================================================

  static Future<void> sendRestockApprovalNotification({
    required int requestId,
    required int supplierId,
    required String productName,
    required int quantity,
  }) async {
    try {
      // 1. Obtener user_id del proveedor
      final supplier = await _supabase
          .from('supply_company')
          .select('user_id, name')
          .eq('id', supplierId)
          .single();

      final supplierUserId = supplier['user_id'] as String?;

      if (supplierUserId == null) {
        if (kDebugMode) {
          print('⚠️ Proveedor sin user_id asociado');
        }
        return;
      }

      // 2. Crear notificación in-app
      await createNotification(
        userId: supplierUserId,
        title: '✅ Request Approved',
        message: 'Your restock request for $productName ($quantity units) has been approved',
        type: 'restock_approved',
        data: {
          'request_id': requestId,
          'supplier_id': supplierId,
          'product_name': productName,
          'quantity': quantity,
          'deep_link': 'miatracker://restock/approved/$requestId',
        },
      );

      if (kDebugMode) {
        print('✅ Notificación de aprobación enviada a usuario: $supplierUserId');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error enviando notificación de aprobación: $e');
      }
    }
  }

  // ========================================================================
  // 🔥 OBTENER NOTIFICACIONES NO LEÍDAS
  // ========================================================================

  static Future<List<Map<String, dynamic>>> getUnreadNotifications() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('notifications')
          .select('*')
          .eq('user_id', userId)
          .eq('is_read', false)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('❌ Error obteniendo notificaciones: $e');
      return [];
    }
  }

  // ========================================================================
  // 🔥 MARCAR NOTIFICACIÓN COMO LEÍDA
  // ========================================================================

  static Future<void> markAsRead(int notificationId) async {
    try {
      await _supabase
          .from('notifications')
          .update({'is_read': true, 'read_at': DateTime.now().toIso8601String()})
          .eq('id', notificationId);
    } catch (e) {
      if (kDebugMode) print('❌ Error marcando como leída: $e');
    }
  }

  // ========================================================================
  // 🔥 STREAM DE NOTIFICACIONES EN TIEMPO REAL
  // ========================================================================

  static Stream<List<Map<String, dynamic>>> notificationsStream() {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((data) => List<Map<String, dynamic>>.from(data));
  }
}