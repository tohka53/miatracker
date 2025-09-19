import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class InventoryService {
  static final SupabaseClient _supabase = AuthService.client;

  // CRUD para Ubicaciones (Locat)
  static Future<List<Map<String, dynamic>>> getLocations() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('locat')
          .select()
          .eq('user_id', userId)
          .eq('status', 1)
          .order('fecha_creacion', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Error al obtener ubicaciones: $e');
    }
  }

  static Future<Map<String, dynamic>> createLocation(Map<String, dynamic> locationData) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('locat')
          .insert({
        ...locationData,
        'user_id': userId,
        'fecha_creacion': DateTime.now().toIso8601String(),
        'status': 1,
      })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al crear ubicación: $e');
    }
  }

  // CRUD para Inventario
  static Future<List<Map<String, dynamic>>> getInventory() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      // Primero intentar con la vista completa
      try {
        final response = await _supabase
            .from('inventario_completo')
            .select()
            .eq('user_id', userId)
            .order('fecha_creacion', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        // Si falla la vista, usar consulta con JOIN manual
        final response = await _supabase
            .from('inventario')
            .select('''
              *,
              locat!inventario_id_location_fkey (
                id_locat,
                lugar_fisico,
                coordenadas
              )
            ''')
            .eq('user_id', userId)
            .eq('status', 1)
            .order('fecha_creacion', ascending: false);

        // Transformar datos para consistencia
        return response.map<Map<String, dynamic>>((item) {
          final location = item['locat'];
          return {
            ...item,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'coordenadas': location?['coordenadas'],
            'stock_status': _calculateStockStatus(item['cantidad'], item['alerta_cantidad']),
          };
        }).toList();
      }
    } catch (e) {
      throw Exception('Error al obtener inventario: $e');
    }
  }

  static String _calculateStockStatus(dynamic cantidad, dynamic alertaCantidad) {
    final stock = cantidad ?? 0;
    final alerta = alertaCantidad ?? 5;

    if (stock == 0) return 'out_of_stock';
    if (stock <= alerta) return 'low_stock';
    return 'normal';
  }

  static Future<Map<String, dynamic>> createInventoryItem(Map<String, dynamic> itemData) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      final response = await _supabase
          .from('inventario')
          .insert({
        ...itemData,
        'user_id': userId,
        'fecha_creacion': DateTime.now().toIso8601String(),
        'status': 1,
      })
          .select()
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al crear producto: $e');
    }
  }

  static Future<void> updateInventoryItem(int itemId, Map<String, dynamic> updates) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('inventario')
          .update({
        ...updates,
        'fecha_modificacion': DateTime.now().toIso8601String(),
      })
          .eq('id_inventario', itemId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al actualizar producto: $e');
    }
  }

  static Future<void> deleteInventoryItem(int itemId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Soft delete - cambiar status a 0
      await _supabase
          .from('inventario')
          .update({
        'status': 0,
        'fecha_modificacion': DateTime.now().toIso8601String(),
      })
          .eq('id_inventario', itemId)
          .eq('user_id', userId);
    } catch (e) {
      throw Exception('Error al eliminar producto: $e');
    }
  }

  // Funciones especiales usando las funciones de PostgreSQL
  static Future<List<Map<String, dynamic>>> getLowStockItems() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .rpc('get_low_stock_items', params: {'user_uuid': userId});

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo productos con stock bajo: $e');
      }
      return [];
    }
  }

  static Future<Map<String, dynamic>> getInventoryStats() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) {
        return {
          'total_productos': 0,
          'productos_activos': 0,
          'productos_sin_stock': 0,
          'productos_stock_bajo': 0,
          'total_ubicaciones': 0,
          'ubicaciones_activas': 0,
        };
      }

      try {
        final response = await _supabase
            .rpc('get_inventory_stats', params: {'user_uuid': userId});

        if (response.isNotEmpty) {
          return response.first;
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error con función RPC, calculando manualmente: $e');
        }
      }

      // Fallback: calcular estadísticas manualmente
      final inventory = await _supabase
          .from('inventario')
          .select('cantidad, alerta_cantidad, status')
          .eq('user_id', userId);

      final locations = await _supabase
          .from('locat')
          .select('status')
          .eq('user_id', userId);

      final activeProducts = inventory.where((item) => item['status'] == 1).length;
      final outOfStock = inventory.where((item) =>
      item['status'] == 1 && (item['cantidad'] ?? 0) == 0).length;
      final lowStock = inventory.where((item) =>
      item['status'] == 1 &&
          (item['cantidad'] ?? 0) > 0 &&
          (item['cantidad'] ?? 0) <= (item['alerta_cantidad'] ?? 5)).length;
      final activeLocations = locations.where((loc) => loc['status'] == 1).length;

      return {
        'total_productos': inventory.length,
        'productos_activos': activeProducts,
        'productos_sin_stock': outOfStock,
        'productos_stock_bajo': lowStock,
        'total_ubicaciones': locations.length,
        'ubicaciones_activas': activeLocations,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error obteniendo estadísticas del inventario: $e');
      }
      return {
        'total_productos': 0,
        'productos_activos': 0,
        'productos_sin_stock': 0,
        'productos_stock_bajo': 0,
        'total_ubicaciones': 0,
        'ubicaciones_activas': 0,
      };
    }
  }

  static Future<List<Map<String, dynamic>>> searchInventory(String searchText) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      try {
        final response = await _supabase
            .rpc('search_inventory', params: {
          'user_uuid': userId,
          'search_text': searchText,
        });

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        // Fallback: búsqueda manual
        final response = await _supabase
            .from('inventario')
            .select()
            .eq('user_id', userId)
            .eq('status', 1)
            .or('nombre_producto.ilike.%$searchText%,descripcion.ilike.%$searchText%')
            .order('fecha_creacion', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error buscando en inventario: $e');
      }
      return [];
    }
  }

  static Future<List<Map<String, dynamic>>> searchByBarcode(Map<String, dynamic> barcodeData) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .rpc('search_by_barcode', params: {
        'user_uuid': userId,
        'barcode_data': barcodeData,
      });

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      if (kDebugMode) {
        print('Error buscando por código de barras: $e');
      }
      return [];
    }
  }

  // Crear datos de ejemplo
  static Future<void> createSampleData() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase.rpc('create_inventory_sample_data', params: {
        'user_uuid': userId,
      });

      if (kDebugMode) {
        print('Datos de ejemplo del inventario creados exitosamente');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error creando datos de ejemplo del inventario: $e');
      }
      throw Exception('Error al crear datos de ejemplo: $e');
    }
  }

  // Stream para actualizaciones en tiempo real del inventario
  static Stream<List<Map<String, dynamic>>> getInventoryStream() {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('inventario')
        .stream(primaryKey: ['id_inventario']).map((List<Map<String, dynamic>> data) {
      return data.where((item) =>
      item['user_id'] == userId &&
          item['status'] == 1
      ).toList()
        ..sort((a, b) => DateTime.parse(b['fecha_creacion'] ?? DateTime.now().toIso8601String())
            .compareTo(DateTime.parse(a['fecha_creacion'] ?? DateTime.now().toIso8601String())));
    });
  }

  // Stream para ubicaciones
  static Stream<List<Map<String, dynamic>>> getLocationsStream() {
    final userId = AuthService.currentUser?.id;
    if (userId == null) {
      return Stream.value([]);
    }

    return _supabase
        .from('locat')
        .stream(primaryKey: ['id_locat']).map((List<Map<String, dynamic>> data) {
      return data.where((item) =>
      item['user_id'] == userId &&
          item['status'] == 1
      ).toList()
        ..sort((a, b) => DateTime.parse(b['fecha_creacion'] ?? DateTime.now().toIso8601String())
            .compareTo(DateTime.parse(a['fecha_creacion'] ?? DateTime.now().toIso8601String())));
    });
  }

  // Utilidades para códigos QR y códigos de barras
  static String generateQRData(Map<String, dynamic> item) {
    // Generar datos estructurados para el QR
    final qrData = {
      'type': 'mia_inventory',
      'id': item['id_inventario']?.toString(),
      'name': item['nombre_producto'],
      'code': item['codigo_barras']?['barcode_data'] ?? generateBarcodeData(item),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Convertir a String JSON
    return qrData.entries
        .map((e) => '${e.key}:${e.value}')
        .join('|');
  }

  static String generateProductCode(Map<String, dynamic> item) {
    // Generar código único basado en el producto
    final name = item['nombre_producto']?.toString() ?? 'UNKNOWN';
    final id = item['id_inventario']?.toString() ?? '0';
    final prefix = name.substring(0, name.length > 3 ? 3 : name.length).toUpperCase();
    return '$prefix-$id-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }

  // Nueva función para generar código de barras válido
  static String generateBarcodeData(Map<String, dynamic> item) {
    // Generar código de barras numérico válido para Code128
    final id = item['id_inventario']?.toString() ?? '0';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final productId = id.padLeft(4, '0'); // Rellenar con ceros
    final timeCode = timestamp.substring(timestamp.length - 6); // Últimos 6 dígitos

    return 'MIA$productId$timeCode'; // Ejemplo: MIA000112345678
  }

  // Generar código de barras numérico puro (para formatos que solo aceptan números)
  static String generateNumericBarcodeData(Map<String, dynamic> item) {
    final id = item['id_inventario']?.toString() ?? '0';
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final productId = id.padLeft(4, '0');
    final timeCode = timestamp.substring(timestamp.length - 6);

    return '999$productId$timeCode'; // Ejemplo: 999000112345678 (13 dígitos)
  }

  // Validar si un código es apropiado para código de barras
  static bool isValidBarcodeFormat(String code) {
    // Code128 puede manejar caracteres alfanuméricos
    // EAN13/UPC necesitan solo números
    return code.isNotEmpty && code.length >= 8;
  }

  static Map<String, dynamic>? parseQRData(String qrData) {
    try {
      final parts = qrData.split('|');
      final Map<String, dynamic> data = {};

      for (final part in parts) {
        final keyValue = part.split(':');
        if (keyValue.length == 2) {
          data[keyValue[0]] = keyValue[1];
        }
      }

      // Verificar que sea un QR válido de M.I.A Tracker
      if (data['type'] == 'mia_inventory') {
        return data;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> getItemByQRCode(String qrData) async {
    try {
      final parsedData = parseQRData(qrData);
      if (parsedData == null) return null;

      final itemId = int.tryParse(parsedData['id'] ?? '');
      if (itemId == null) return null;

      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      final response = await _supabase
          .from('inventario')
          .select('''
            *,
            locat!inventario_id_location_fkey (
              id_locat,
              lugar_fisico,
              coordenadas
            )
          ''')
          .eq('user_id', userId)
          .eq('id_inventario', itemId)
          .eq('status', 1)
          .maybeSingle();

      if (response != null) {
        final location = response['locat'];
        return {
          ...response,
          'id_locat': location?['id_locat'],
          'lugar_fisico': location?['lugar_fisico'],
          'coordenadas': location?['coordenadas'],
          'stock_status': _calculateStockStatus(response['cantidad'], response['alerta_cantidad']),
        };
      }

      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener producto por QR: $e');
      }
      return null;
    }
  }

  // Utilidades
  static String getStockStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'out_of_stock':
        return 'Sin Stock';
      case 'low_stock':
        return 'Stock Bajo';
      case 'normal':
        return 'Normal';
      default:
        return 'Desconocido';
    }
  }

  static String getStockStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'out_of_stock':
        return '#EF4444'; // Rojo
      case 'low_stock':
        return '#F59E0B'; // Amarillo
      case 'normal':
        return '#6B8E3D'; // Verde
      default:
        return '#6B7280'; // Gris
    }
  }

  static Map<String, dynamic> parseCoordinates(dynamic coordenadas) {
    if (coordenadas == null) return {'lat': null, 'lng': null};

    if (coordenadas is Map<String, dynamic>) {
      return {
        'lat': coordenadas['lat']?.toDouble(),
        'lng': coordenadas['lng']?.toDouble(),
      };
    }

    return {'lat': null, 'lng': null};
  }

  static String formatCoordinates(dynamic coordenadas) {
    final coords = parseCoordinates(coordenadas);
    if (coords['lat'] != null && coords['lng'] != null) {
      return '${coords['lat']?.toStringAsFixed(4)}, ${coords['lng']?.toStringAsFixed(4)}';
    }
    return 'Sin coordenadas';
  }
}