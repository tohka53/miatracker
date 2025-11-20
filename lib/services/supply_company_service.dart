import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class SupplyCompanyService {
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // CRUD SUPPLY COMPANY
  // ========================================================================

  /// Obtener todos los proveedores del usuario
  static Future<List<Map<String, dynamic>>> getSuppliers() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('supply_company')
          .select()
          .eq('user_id', userId)
          .eq('status', 1)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener proveedores: $e');
    }
  }

  /// Obtener un proveedor específico por ID
  static Future<Map<String, dynamic>?> getSupplierById(int supplierId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('supply_company')
          .select()
          .eq('id', supplierId)
          .eq('user_id', userId)
          .eq('status', 1)
          .maybeSingle();

      return response;
    } catch (e) {
      if (kDebugMode) print('Error al obtener proveedor: $e');
      return null;
    }
  }

  /// Crear un nuevo proveedor
  static Future<Map<String, dynamic>> createSupplier(
      Map<String, dynamic> supplierData) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('supply_company')
          .insert({
        ...supplierData,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'status': 1,
      })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al crear proveedor: $e');
    }
  }

  /// Actualizar un proveedor existente
  static Future<void> updateSupplier(
      int supplierId, Map<String, dynamic> updates) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('supply_company')
          .update({
        ...updates,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', supplierId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar proveedor: $e');
    }
  }

  /// Eliminar (soft delete) un proveedor
  static Future<void> deleteSupplier(int supplierId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('supply_company')
          .update({
        'status': 0,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', supplierId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al eliminar proveedor: $e');
    }
  }

  // ========================================================================
  // FUNCIONES DE BÚSQUEDA Y ESTADÍSTICAS
  // ========================================================================

  /// Buscar proveedores por texto
  static Future<List<Map<String, dynamic>>> searchSuppliers(
      String searchText) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      try {
        final response = await _supabase.rpc(
          'search_suppliers',
          params: {
            'user_uuid': userId,
            'search_text': searchText,
          },
        );
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        // Fallback a búsqueda manual si la función RPC falla
        if (kDebugMode) print('RPC search_suppliers falló, usando fallback: $e');
        return _searchSuppliersFallback(searchText);
      }
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _searchSuppliersFallback(
      String searchText) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('supply_company')
          .select()
          .eq('user_id', userId)
          .eq('status', 1)
          .or(
          'name.ilike.%$searchText%,email.ilike.%$searchText%,phone.ilike.%$searchText%,description.ilike.%$searchText%')
          .order('name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error en búsqueda fallback: $e');
      return [];
    }
  }

  /// Obtener productos de un proveedor específico
  static Future<List<Map<String, dynamic>>> getProductsBySupplier(
      int supplierId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      try {
        final response = await _supabase.rpc(
          'get_products_by_supplier',
          params: {
            'user_uuid': userId,
            'supplier_id': supplierId,
          },
        );
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        // Fallback si la función RPC no existe
        if (kDebugMode) print('RPC get_products_by_supplier falló, usando fallback: $e');
        return _getProductsBySupplierFallback(supplierId);
      }
    } catch (e) {
      if (kDebugMode) print('Error obteniendo productos: $e');
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> _getProductsBySupplierFallback(
      int supplierId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('inventario')
          .select('''
          *,
          locat!inventario_id_location_fkey (
            id_locat,
            lugar_fisico
          )
        ''')
          .eq('user_id', userId)
          .eq('id_supply_company', supplierId)
          .eq('status', 1)
          .order('nombre_producto', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) print('Error obteniendo productos del proveedor: $e');
      return [];
    }
  }

  /// Obtener estadísticas de proveedores
  static Future<Map<String, dynamic>> getSupplierStats() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return _emptyStats();

      try {
        final response = await _supabase.rpc(
          'get_supplier_stats',
          params: {'user_uuid': userId},
        );

        if (response != null && response is List && response.isNotEmpty) {
          return response.first;
        }
      } catch (e) {
        if (kDebugMode) print('RPC get_supplier_stats falló: $e');
      }

      return _emptyStats();
    } catch (e) {
      if (kDebugMode) print('Error obteniendo estadísticas: $e');
      return _emptyStats();
    }
  }

  static Map<String, dynamic> _emptyStats() {
    return {
      'total_proveedores': 0,
      'proveedores_activos': 0,
      'total_productos_con_proveedor': 0,
      'valor_total_inventario_por_proveedor': 0.0,
    };
  }

  // ========================================================================
  // UTILIDADES PARA DIRECCIONES
  // ========================================================================

  /// Parsear dirección JSONB a Map
  static Map<String, dynamic> parseDireccion(dynamic direccion) {
    if (direccion == null) return {};
    if (direccion is Map<String, dynamic>) return direccion;
    return {};
  }

  /// Formatear dirección para mostrar
  static String formatDireccion(dynamic direccion) {
    final dir = parseDireccion(direccion);
    if (dir.isEmpty) return 'Sin dirección';

    final parts = <String>[];
    if (dir['calle'] != null) parts.add(dir['calle']);
    if (dir['zona'] != null) parts.add('Zona ${dir['zona']}');
    if (dir['ciudad'] != null) parts.add(dir['ciudad']);
    if (dir['pais'] != null) parts.add(dir['pais']);

    return parts.isNotEmpty ? parts.join(', ') : 'Sin dirección';
  }

  /// Crear objeto de dirección JSONB
  static Map<String, dynamic> createDireccionJsonb({
    String? calle,
    String? zona,
    String? ciudad,
    String? pais,
    String? codigoPostal,
  }) {
    final Map<String, dynamic> direccion = {};

    if (calle != null && calle.isNotEmpty) direccion['calle'] = calle;
    if (zona != null && zona.isNotEmpty) direccion['zona'] = zona;
    if (ciudad != null && ciudad.isNotEmpty) direccion['ciudad'] = ciudad;
    if (pais != null && pais.isNotEmpty) direccion['pais'] = pais;
    if (codigoPostal != null && codigoPostal.isNotEmpty) {
      direccion['codigo_postal'] = codigoPostal;
    }

    return direccion;
  }

  // ========================================================================
  // VALIDACIONES
  // ========================================================================

  static bool isValidEmail(String email) {
    final emailRegex = RegExp(r'^[\w-]+(\.[\w-]+)*@([\w-]+\.)+[a-zA-Z]{2,7}$');
    return emailRegex.hasMatch(email);
  }

  static bool isValidPhone(String phone) {
    // Acepta cualquier texto que no esté vacío
    return phone.trim().isNotEmpty;
  }


  static String? validateSupplierName(String? name) {
    if (name == null || name.trim().isEmpty) {
      return 'El nombre es requerido';
    }
    if (name.trim().length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }
    return null;
  }

  static String? validateEmail(String? email) {
    if (email == null || email.trim().isEmpty) return null;
    if (!isValidEmail(email)) return 'Email inválido';
    return null;
  }

  static String? validatePhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return null;
    if (!isValidPhone(phone)) {
      return 'Teléfono inválido (formato: 1234-5678)';
    }
    return null;
  }

  // ========================================================================
  // STREAMS PARA TIEMPO REAL - CORREGIDO
  // ========================================================================

  /// Stream de proveedores en tiempo real
  static Stream<List<Map<String, dynamic>>> getSuppliersStream() {
    final userId = AuthService.currentUser?.id;
    if (userId == null) return Stream.value([]);

    return _supabase
        .from('supply_company')
        .stream(primaryKey: ['id'])
        .map((List<Map<String, dynamic>> data) {
      // Filtrar en la aplicación ya que stream no permite .eq()
      return data
          .where((item) =>
      item['user_id'] == userId &&
          item['status'] == 1)
          .toList()
        ..sort((a, b) => DateTime.parse(
            b['created_at'] ?? DateTime.now().toIso8601String())
            .compareTo(DateTime.parse(
            a['created_at'] ?? DateTime.now().toIso8601String())));
    });
  }

  // ========================================================================
  // EXPORTAR/IMPORTAR
  // ========================================================================

  static String exportSuppliersToText(List<Map<String, dynamic>> suppliers) {
    final buffer = StringBuffer();
    buffer.writeln('PROVEEDORES - M.I.A TRACKER');
    buffer.writeln('Generado: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('${'=' * 50}\n');

    for (final supplier in suppliers) {
      buffer.writeln('Nombre: ${supplier['name']}');
      if (supplier['email'] != null) {
        buffer.writeln('Email: ${supplier['email']}');
      }
      if (supplier['phone'] != null) {
        buffer.writeln('Teléfono: ${supplier['phone']}');
      }
      if (supplier['direccion'] != null) {
        buffer.writeln('Dirección: ${formatDireccion(supplier['direccion'])}');
      }
      if (supplier['description'] != null) {
        buffer.writeln('Descripción: ${supplier['description']}');
      }
      buffer.writeln('-' * 50);
    }

    return buffer.toString();
  }

}