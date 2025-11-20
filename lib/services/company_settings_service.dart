import 'dart:typed_data'; // ← Agregar esta línea al inicio
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

/// Servicio para gestionar la configuración de la compañía
/// Incluye información básica y modo proveedor
class CompanySettingsService {
  static final _supabase = Supabase.instance.client;

  // ==================== CONFIGURACIÓN ====================

  /// Obtener configuración de la compañía del usuario actual
  static Future<Map<String, dynamic>?> getSettings() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('company_settings')
          .select('*')
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('Error al obtener configuración: $e');
      return null;
    }
  }

  /// Crear o actualizar configuración de la compañía
  static Future<void> upsertSettings({
    required String companyName,
    String? taxId,
    String? description,
    required String phone,
    required String email,
    String? address,
    String? website,
    bool? isSupplier,
    String? logoUrl,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final data = {
        'user_id': userId,
        'company_name': companyName,
        'tax_id': taxId,
        'description': description,
        'phone': phone,
        'email': email,
        'address': address,
        'website': website,
        'logo_url': logoUrl,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (isSupplier != null) {
        data['is_supplier'] = isSupplier as String?;
      }

      await _supabase.from('company_settings').upsert(data);
    } catch (e) {
      throw Exception('Error al guardar configuración: $e');
    }
  }

  /// Verificar si el usuario actual es proveedor
  static Future<bool> isSupplier() async {
    try {
      final settings = await getSettings();
      return settings?['is_supplier'] ?? false;
    } catch (e) {
      if (kDebugMode) print('Error al verificar modo proveedor: $e');
      return false;
    }
  }

  /// Activar modo proveedor
  static Future<void> enableSupplierMode() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('company_settings')
          .update({
        'is_supplier': true,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al activar modo proveedor: $e');
    }
  }

  /// Desactivar modo proveedor
  static Future<void> disableSupplierMode() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('company_settings')
          .update({
        'is_supplier': false,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al desactivar modo proveedor: $e');
    }
  }

  // ==================== INFORMACIÓN DEL PROVEEDOR ====================

  /// Obtener información pública de un proveedor
  static Future<Map<String, dynamic>?> getSupplierInfo(String userId) async {
    try {
      final response = await _supabase
          .from('company_settings')
          .select('''
            company_name,
            description,
            phone,
            email,
            address,
            website,
            logo_url,
            supplier_rating,
            is_supplier
          ''')
          .eq('user_id', userId)
          .eq('is_supplier', true)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('Error al obtener info del proveedor: $e');
      return null;
    }
  }

  /// Obtener lista de todos los proveedores activos
  static Future<List<Map<String, dynamic>>> getAllSuppliers() async {
    try {
      final response = await _supabase
          .from('company_settings')
          .select('''
            user_id,
            company_name,
            description,
            supplier_rating,
            logo_url
          ''')
          .eq('is_supplier', true)
          .eq('supplier_approved', true)
          .order('supplier_rating', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener proveedores: $e');
      return [];
    }
  }

  /// Obtener proveedores destacados (mejor rating)
  static Future<List<Map<String, dynamic>>> getTopSuppliers({int limit = 5}) async {
    try {
      final response = await _supabase
          .from('company_settings')
          .select('''
            user_id,
            company_name,
            description,
            supplier_rating,
            logo_url
          ''')
          .eq('is_supplier', true)
          .eq('supplier_approved', true)
          .gte('supplier_rating', 4.0)
          .order('supplier_rating', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error al obtener proveedores destacados: $e');
      return [];
    }
  }

  // ==================== VALIDACIÓN ====================

  /// Validar que la configuración está completa para activar modo proveedor
  static Future<Map<String, dynamic>> validateSupplierRequirements() async {
    try {
      final settings = await getSettings();

      if (settings == null) {
        return {
          'valid': false,
          'errors': ['Debes completar la configuración de tu empresa primero'],
        };
      }

      final errors = <String>[];

      // Campos requeridos
      if (settings['company_name'] == null ||
          (settings['company_name'] as String).isEmpty) {
        errors.add('Nombre de empresa es requerido');
      }

      if (settings['phone'] == null || (settings['phone'] as String).isEmpty) {
        errors.add('Teléfono es requerido');
      }

      if (settings['email'] == null || (settings['email'] as String).isEmpty) {
        errors.add('Email es requerido');
      }

      if (settings['address'] == null || (settings['address'] as String).isEmpty) {
        errors.add('Dirección es requerida para proveedores');
      }

      if (settings['tax_id'] == null || (settings['tax_id'] as String).isEmpty) {
        errors.add('NIT/Identificación fiscal es requerida para proveedores');
      }

      return {
        'valid': errors.isEmpty,
        'errors': errors,
      };
    } catch (e) {
      return {
        'valid': false,
        'errors': ['Error al validar requisitos: $e'],
      };
    }
  }

  // ==================== LOGO ====================

  /// Subir logo de la empresa
  static Future<String?> uploadLogo(String filePath, Uint8List fileBytes) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final fileName = 'company-logo-$userId-${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '$userId/$fileName';

      // Subir imagen a storage
      await _supabase.storage
          .from('company-logos')
          .uploadBinary(path, fileBytes);

      // Obtener URL pública
      final publicUrl = _supabase.storage
          .from('company-logos')
          .getPublicUrl(path);

      // Actualizar configuración con la URL del logo
      await _supabase
          .from('company_settings')
          .update({'logo_url': publicUrl})
          .eq('user_id', userId);

      return publicUrl;
    } catch (e) {
      throw Exception('Error al subir logo: $e');
    }
  }

  /// Eliminar logo de la empresa
  static Future<void> deleteLogo() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final settings = await getSettings();
      final logoUrl = settings?['logo_url'];

      if (logoUrl != null && (logoUrl as String).isNotEmpty) {
        // Extraer path del URL
        final uri = Uri.parse(logoUrl);
        final path = uri.pathSegments.last;

        // Eliminar del storage
        await _supabase.storage
            .from('company-logos')
            .remove(['$userId/$path']);

        // Actualizar configuración
        await _supabase
            .from('company_settings')
            .update({'logo_url': null})
            .eq('user_id', userId);
      }
    } catch (e) {
      throw Exception('Error al eliminar logo: $e');
    }
  }

  // ==================== INICIALIZACIÓN ====================

  /// Crear configuración inicial cuando el usuario se registra
  static Future<void> createInitialSettings({
    required String companyName,
    required String email,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase.from('company_settings').insert({
        'user_id': userId,
        'company_name': companyName,
        'email': email,
        'phone': '',
        'is_supplier': false,
      });
    } catch (e) {
      // Si ya existe, no hacer nada
      if (kDebugMode) print('Error al crear configuración inicial: $e');
    }
  }

  // ==================== ESTADÍSTICAS ====================

  /// Obtener estadísticas básicas de la compañía
  static Future<Map<String, dynamic>> getCompanyStats() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return {};

      final settings = await getSettings();
      if (settings == null) return {};

      final stats = <String, dynamic>{
        'company_name': settings['company_name'],
        'is_supplier': settings['is_supplier'] ?? false,
        'supplier_rating': settings['supplier_rating'] ?? 0.0,
      };

      if (settings['is_supplier'] == true) {
        // Obtener estadísticas adicionales si es proveedor
        try {
          final productsResponse = await _supabase
              .from('marketplace_products')
              .select('id')
              .eq('supplier_user_id', userId)
              .eq('status', 'active');

          final ordersResponse = await _supabase
              .from('marketplace_orders')
              .select('id')
              .eq('supplier_user_id', userId);

          stats['active_products'] = (productsResponse as List).length;
          stats['total_orders'] = (ordersResponse as List).length;
        } catch (e) {
          if (kDebugMode) print('Error al obtener estadísticas de proveedor: $e');
          stats['active_products'] = 0;
          stats['total_orders'] = 0;
        }
      }

      return stats;
    } catch (e) {
      if (kDebugMode) print('Error al obtener estadísticas: $e');
      return {};
    }
  }
}