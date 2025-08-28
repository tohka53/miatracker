import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class DatabaseService {
  static final SupabaseClient _supabase = AuthService.client;

  // CRUD para Assets/Inventory
  static Future<List<Map<String, dynamic>>> getAssets() async {
    try {
      final response = await _supabase
          .from('assets')
          .select()
          .eq('user_id', AuthService.currentUser?.id ?? '')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener assets: $e');
    }
  }

  static Future<Map<String, dynamic>> createAsset(Map<String, dynamic> assetData) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('assets')
          .insert({
        ...assetData,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al crear asset: $e');
    }
  }

  static Future<void> updateAsset(String assetId, Map<String, dynamic> updates) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('assets')
          .update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', assetId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar asset: $e');
    }
  }

  static Future<void> deleteAsset(String assetId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('assets')
          .delete()
          .eq('id', assetId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al eliminar asset: $e');
    }
  }

  // CRUD para Maintenance Records
  static Future<List<Map<String, dynamic>>> getMaintenanceRecords() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('maintenance_records')
          .select('''
            *,
            assets (
              name,
              asset_tag
            )
          ''')
          .eq('user_id', userId)
          .order('scheduled_date', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener registros de mantenimiento: $e');
    }
  }

  static Future<Map<String, dynamic>> createMaintenanceRecord(Map<String, dynamic> recordData) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('maintenance_records')
          .insert({
        ...recordData,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al crear registro de mantenimiento: $e');
    }
  }

  static Future<void> updateMaintenanceRecord(String recordId, Map<String, dynamic> updates) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('maintenance_records')
          .update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', recordId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar registro de mantenimiento: $e');
    }
  }

  static Future<void> deleteMaintenanceRecord(String recordId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('maintenance_records')
          .delete()
          .eq('id', recordId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al eliminar registro de mantenimiento: $e');
    }
  }

  // Método simplificado para estadísticas del dashboard
  static Future<Map<String, dynamic>> getDashboardStats() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) {
        return {
          'total_assets': 0,
          'total_maintenance': 0,
          'pending_maintenance': 0,
          'completed_maintenance': 0,
        };
      }

      // Obtener todos los datos y contar en el cliente
      final assets = await _supabase
          .from('assets')
          .select('id, status')
          .eq('user_id', userId);

      final maintenance = await _supabase
          .from('maintenance_records')
          .select('id, status')
          .eq('user_id', userId);

      // Contar en el cliente para evitar problemas con CountOption
      final pendingCount = maintenance.where((record) =>
      record['status'] == 'pending').length;
      final completedCount = maintenance.where((record) =>
      record['status'] == 'completed').length;
      final activeAssets = assets.where((asset) =>
      asset['status'] == 'active').length;

      return {
        'total_assets': assets.length,
        'active_assets': activeAssets,
        'total_maintenance': maintenance.length,
        'pending_maintenance': pendingCount,
        'completed_maintenance': completedCount,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo estadísticas: $e');
      }
      // Retornar valores por defecto si hay error
      return {
        'total_assets': 0,
        'active_assets': 0,
        'total_maintenance': 0,
        'pending_maintenance': 0,
        'completed_maintenance': 0,
      };
    }
  }

  // Búsqueda de assets
  static Future<List<Map<String, dynamic>>> searchAssets(String query) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('assets')
          .select()
          .eq('user_id', userId)
          .or('name.ilike.%$query%,asset_tag.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al buscar assets: $e');
    }
  }

  // Suscripciones en tiempo real - versión simplificada
  static Stream<List<Map<String, dynamic>>> getAssetsStream() {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('assets')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  static Stream<List<Map<String, dynamic>>> getMaintenanceRecordsStream() {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('maintenance_records')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('scheduled_date', ascending: false);
  }

  // Verificar conexión con la base de datos
  static Future<bool> testConnection() async {
    try {
      await _supabase.from('assets').select('id').limit(1);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Error de conexión: $e');
      }
      return false;
    }
  }

  // Crear datos de ejemplo para pruebas
  static Future<void> createSampleData() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Crear un asset de ejemplo
      await _supabase.from('assets').insert({
        'user_id': userId,
        'name': 'Laptop Dell Inspiron',
        'asset_tag': 'LAPTOP-001',
        'description': 'Laptop para trabajo de oficina',
        'category': 'Electronics',
        'brand': 'Dell',
        'model': 'Inspiron 15 3000',
        'serial_number': 'DL123456789',
        'location': 'Oficina Principal',
        'status': 'active',
        'condition': 'good',
        'purchase_date': '2024-01-15',
        'purchase_price': 899.99,
        'current_value': 750.00,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('Datos de ejemplo creados exitosamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creando datos de ejemplo: $e');
      }
      throw Exception('Error al crear datos de ejemplo: $e');
    }
  }

  // Obtener assets por categoría
  static Future<Map<String, List<Map<String, dynamic>>>> getAssetsByCategory() async {
    try {
      final assets = await getAssets();
      final Map<String, List<Map<String, dynamic>>> grouped = {};

      for (var asset in assets) {
        final category = asset['category'] ?? 'Sin categoría';
        if (!grouped.containsKey(category)) {
          grouped[category] = [];
        }
        grouped[category]!.add(asset);
      }

      return grouped;
    } catch (e) {
      throw Exception('Error al agrupar assets por categoría: $e');
    }
  }

  // Obtener próximos mantenimientos
  static Future<List<Map<String, dynamic>>> getUpcomingMaintenance() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final now = DateTime.now().toIso8601String();
      final response = await _supabase
          .from('maintenance_records')
          .select('''
            *,
            assets (
              name,
              asset_tag
            )
          ''')
          .eq('user_id', userId)
          .eq('status', 'pending')
          .gte('scheduled_date', now)
          .order('scheduled_date', ascending: true)
          .limit(5);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener próximos mantenimientos: $e');
    }
  }
}