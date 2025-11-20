  import 'package:flutter/foundation.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../services/auth_service.dart';
  import 'inventory_service_optimized.dart';

  class InventoryService {
    static final SupabaseClient _supabase = AuthService.client;


    static final Map<String, dynamic> _cache = {};
    static DateTime? _cacheTimestamp;
    static const Duration _cacheDuration = Duration(minutes: 5);

    static const int _pageSize = 20;
    // ========================================================================
    // CRUD UBICACIONES (LOCAT)
    // ========================================================================

    static Future<List<Map<String, dynamic>>> getLocations() async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        final response = await _supabase
            .from('locat')
            .select()
            .eq('id_company', companyId)
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
        final companyId = await getCurrentCompanyId();

        if (userId == null) throw Exception('Usuario no autenticado');
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compaÃ±Ã­a');

        final response = await _supabase
            .from('locat')
            .insert({
          ...locationData,
          'user_id': userId,
          'id_company': companyId,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'status': 1,
        })
            .select()
            .single();

        return response;
      } catch (e) {
        throw Exception('Error al crear ubicacion: $e');
      }
    }

    // ========================================================================
    // CRUD INVENTARIO - MEJORADO CON PRECIO Y DISTRIBUCIÃ“N
    // ========================================================================

    static Future<List<Map<String, dynamic>>> getInventory() async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

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
            .eq('id_company', companyId)
            .eq('status', 1)
            .order('fecha_creacion', ascending: false);

        final List<Map<String, dynamic>> inventory = [];

        for (var item in response) {
          final location = item['locat'];
          final distribution = await getProductLocationDistribution(item['id_inventario']);

          inventory.add({
            ...item,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'coordenadas': location?['coordenadas'],
            'stock_status': _calculateStockStatus(item['cantidad'], item['alerta_cantidad']),
            'precio': item['precio'] ?? 0.0,
            'image_url': item['imagen'],
            'ubicaciones': distribution,
          });
        }

        return inventory;
      } catch (e) {
        throw Exception('Error al obtener inventario: $e');
      }
    }

    static Future<List<Map<String, dynamic>>> getInventoryWithDistribution() async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        final inventory = await getInventory();

        for (var product in inventory) {
          final distribution = await getProductLocationDistribution(product['id_inventario']);
          product['stock_locations'] = distribution;
          product['total_distributed'] = distribution.fold<int>(
              0, (sum, loc) => sum + (loc['cantidad'] as int? ?? 0));
        }

        return inventory;
      } catch (e) {
        throw Exception('Error al obtener inventario con distribucion: $e');
      }
    }

    // Agregar este método que falta para obtener distribución de ubicaciones
    static Future<List<Map<String, dynamic>>> getProductLocationDistribution(int productId) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        final response = await _supabase
            .from('inventory_location_stock')
            .select('''
          cantidad,
          id_location,
          locat!inner(
            id_locat,
            lugar_fisico,
            coordenadas
          )
        ''')
            .eq('id_inventario', productId)
            .eq('id_company', companyId)
            .eq('status', 1)
            .gt('cantidad', 0);

        return response.map<Map<String, dynamic>>((item) {
          final location = item['locat'];
          return {
            'id_locat': location['id_locat'],
            'lugar_fisico': location['lugar_fisico'],
            'coordenadas': location['coordenadas'],
            'cantidad': item['cantidad'],
          };
        }).toList();
      } catch (e) {
        return [];
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
        final companyId = await getCurrentCompanyId();

        if (userId == null) throw Exception('Usuario no autenticado');
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compaÃ±Ã­a');

        final dataWithCompany = {
          ...itemData,
          'user_id': userId,
          'id_company': companyId,
          'fecha_creacion': DateTime.now().toIso8601String(),
          'status': 1,
          'precio': itemData['precio'] ?? 0.0,
        };

        final response = await _supabase
            .from('inventario')
            .insert(dataWithCompany)
            .select()
            .single();

        if (itemData['id_location'] != null && (itemData['cantidad'] ?? 0) > 0) {
          try {
            await _supabase.from('inventory_location_stock').insert({
              'id_inventario': response['id_inventario'],
              'id_location': itemData['id_location'],
              'id_company': companyId,
              'user_id': userId,
              'cantidad': itemData['cantidad'],
              'status': 1,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

            if (kDebugMode) {
            }
          } catch (e) {
            if (kDebugMode) {
            }
          }
        }

        return response;
      } catch (e) {
        throw Exception('Error al crear producto: $e');
      }
    }

    static Future<void> updateInventoryItem(int itemId, Map<String, dynamic> updates) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compaÃ±Ã­a');

        final cleanUpdates = Map<String, dynamic>.from(updates);
        cleanUpdates.remove('id_location');

        await _supabase
            .from('inventario')
            .update({
          ...cleanUpdates,
          'fecha_modificacion': DateTime.now().toIso8601String(),
        })
            .eq('id_inventario', itemId)
            .eq('id_company', companyId);

        if (kDebugMode) {
        }
      } catch (e) {
        throw Exception('Error al actualizar producto: $e');
      }
    }

    static Future<void> deleteInventoryItem(int itemId) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compania');

        await _supabase
            .from('inventario')
            .update({
          'status': 0,
          'fecha_modificacion': DateTime.now().toIso8601String(),
        })
            .eq('id_inventario', itemId)
            .eq('id_company', companyId);
      } catch (e) {
        throw Exception('Error al eliminar producto: $e');
      }
    }

    // ========================================================================
    // FUNCIONES ESPECIALES Y ESTADÃSTICAS
    // ========================================================================

    static Future<List<Map<String, dynamic>>> getLowStockItems() async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        final response = await _supabase
            .from('inventario')
            .select()
            .eq('id_company', companyId)
            .eq('status', 1)
            .order('fecha_creacion', ascending: false);

        return response.where((item) {
          final stock = item['cantidad'] ?? 0;
          final alerta = item['alerta_cantidad'] ?? 5;
          return stock > 0 && stock <= alerta;
        }).toList();
      } catch (e) {
        if (kDebugMode) print('Error obteniendo productos con stock bajo: $e');
        return [];
      }
    }

    static Future<Map<String, dynamic>> getInventoryStats() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return _emptyStats();

        try {
          final response = await _supabase
              .rpc('get_inventory_stats_by_company', params: {'user_uuid': userId});

          if (response != null && response is List && response.isNotEmpty) {
            return response.first as Map<String, dynamic>;
          }
        } catch (e) {
          if (kDebugMode) print('RPC no disponible, calculando manualmente: $e');
        }

        final companyId = await getCurrentCompanyId();
        if (companyId == null) return _emptyStats();

        final inventory = await _supabase
            .from('inventario')
            .select('cantidad, alerta_cantidad, status, precio')
            .eq('id_company', companyId);

        final locations = await _supabase
            .from('locat')
            .select('status')
            .eq('id_company', companyId);

        final activeProducts = inventory.where((item) => item['status'] == 1).length;
        final outOfStock = inventory.where((item) =>
        item['status'] == 1 && (item['cantidad'] ?? 0) == 0).length;
        final lowStock = inventory.where((item) =>
        item['status'] == 1 &&
            (item['cantidad'] ?? 0) > 0 &&
            (item['cantidad'] ?? 0) <= (item['alerta_cantidad'] ?? 5)).length;
        final activeLocations = locations.where((loc) => loc['status'] == 1).length;

        final totalValue = inventory.where((item) => item['status'] == 1).fold<double>(
            0.0, (sum, item) => sum + ((item['cantidad'] ?? 0) * (item['precio'] ?? 0.0)));

        return {
          'total_productos': inventory.length,
          'productos_activos': activeProducts,
          'productos_sin_stock': outOfStock,
          'productos_stock_bajo': lowStock,
          'total_ubicaciones': locations.length,
          'ubicaciones_activas': activeLocations,
          'valor_total_inventario': totalValue,
        };
      } catch (e) {
        if (kDebugMode) print('Error obteniendo estadisticas: $e');
        return _emptyStats();
      }
    }

    static Map<String, dynamic> _emptyStats() {
      return {
        'total_productos': 0,
        'productos_activos': 0,
        'productos_sin_stock': 0,
        'productos_stock_bajo': 0,
        'total_ubicaciones': 0,
        'ubicaciones_activas': 0,
        'valor_total_inventario': 0.0,
      };
    }

    static Future<List<Map<String, dynamic>>> searchInventory(String searchText) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        final response = await _supabase
            .from('inventario')
            .select()
            .eq('id_company', companyId)
            .eq('status', 1)
            .or('nombre_producto.ilike.%$searchText%,descripcion.ilike.%$searchText%')
            .order('fecha_creacion', ascending: false);

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        if (kDebugMode) print('Error buscando en inventario: $e');
        return [];
      }
    }

    static Future<List<Map<String, dynamic>>> searchByBarcode(Map<String, dynamic> barcodeData) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        final codeToSearch = barcodeData['barcode_data'] ?? barcodeData['qr_data'] ?? '';

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
            .eq('id_company', companyId)
            .eq('status', 1);

        final filtered = response.where((item) {
          final codigoBarras = item['codigo_barras'];
          if (codigoBarras == null) return false;

          final qrData = codigoBarras['qr_data'] ?? '';
          final barcodeDataStr = codigoBarras['barcode_data'] ?? '';

          return qrData == codeToSearch || barcodeDataStr == codeToSearch;
        }).toList();

        return filtered.map<Map<String, dynamic>>((item) {
          final location = item['locat'];
          return {
            ...item,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'coordenadas': location?['coordenadas'],
            'stock_status': _calculateStockStatus(item['cantidad'], item['alerta_cantidad']),
          };
        }).toList();
      } catch (e) {
        if (kDebugMode) print('Error buscando por codigo: $e');
        return [];
      }
    }

    // ========================================================================
    // GENERACIÃ“N Y MANEJO DE CÃ“DIGOS QR/BARRAS
    // ========================================================================

    static String generateQRData(Map<String, dynamic> item) {
      try {
        final qrData = {
          'type': 'mia_inventory',
          'id': item['id_inventario']?.toString() ?? '0',
          'name': item['nombre_producto'] ?? 'Unknown',
          'code': item['codigo_barras']?['barcode_data'] ?? generateBarcodeData(item),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'user': AuthService.currentUser?.id.substring(0, 8) ?? 'unknown',
        };

        return qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
      } catch (e) {
        if (kDebugMode) print('Error generando QR data: $e');
        return 'MIA:${item['id_inventario']}:${item['nombre_producto']}';
      }
    }

    static String generateBarcodeData(Map<String, dynamic> item) {
      try {
        final id = item['id_inventario']?.toString() ?? '0';
        final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final productId = id.padLeft(6, '0');
        final timeCode = timestamp.substring(timestamp.length - 8);

        return 'MIA$productId$timeCode';
      } catch (e) {
        return 'MIA000000${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      }
    }

    static Map<String, dynamic>? parseQRData(String qrData) {
      try {
        if (qrData.contains('|') && qrData.contains(':')) {
          final parts = qrData.split('|');
          final Map<String, dynamic> data = {};

          for (final part in parts) {
            final keyValue = part.split(':');
            if (keyValue.length >= 2) {
              final key = keyValue[0];
              final value = keyValue.sublist(1).join(':');
              data[key] = value;
            }
          }

          if (data['type'] == 'mia_inventory') {
            return data;
          }
        }
        return null;
      } catch (e) {
        if (kDebugMode) print('Error parseando QR data: $e');
        return null;
      }
    }

    static Future<Map<String, dynamic>?> getItemByQRCode(String qrData) async {
      try {
        final parsedData = parseQRData(qrData);
        if (parsedData == null) return null;

        final itemId = int.tryParse(parsedData['id'] ?? '');
        if (itemId == null) return null;

        final companyId = await getCurrentCompanyId();
        if (companyId == null) return null;

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
            .eq('id_company', companyId)
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
        if (kDebugMode) print('Error al obtener producto por QR: $e');
        return null;
      }
    }

    // ========================================================================
    // UTILIDADES
    // ========================================================================

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
          return '#EF4444';
        case 'low_stock':
          return '#F59E0B';
        case 'normal':
          return '#6B8E3D';
        default:
          return '#6B7280';
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

      if (coordenadas is String) {
        try {
          final parts = coordenadas.split(',');
          if (parts.length == 2) {
            return {
              'lat': double.tryParse(parts[0].trim()),
              'lng': double.tryParse(parts[1].trim()),
            };
          }
        } catch (e) {
          if (kDebugMode) print('Error parseando coordenadas string: $e');
        }
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

    static Future<Map<String, dynamic>?> getItemByCode(String code) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return null;

        final qrResult = await getItemByQRCode(code);
        if (qrResult != null) return qrResult;

        final barcodeResults = await searchByBarcode({'barcode_data': code});
        if (barcodeResults.isNotEmpty) return barcodeResults.first;

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
            .eq('id_company', companyId)
            .eq('status', 1)
            .or('nombre_producto.ilike.%$code%,descripcion::text.ilike.%$code%');

        if (response.isNotEmpty) {
          final item = response.first;
          final location = item['locat'];
          return {
            ...item,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'coordenadas': location?['coordenadas'],
            'stock_status': _calculateStockStatus(item['cantidad'], item['alerta_cantidad']),
          };
        }

        return null;
      } catch (e) {
        if (kDebugMode) print('Error al obtener producto por codigo: $e');
        return null;
      }
    }

    static Stream<List<Map<String, dynamic>>> getInventoryStream() async* {
      final companyId = await getCurrentCompanyId();
      if (companyId == null) {
        yield [];
        return;
      }

      yield* _supabase
          .from('inventario')
          .stream(primaryKey: ['id_inventario']).map((List<Map<String, dynamic>> data) {
        return data.where((item) => item['id_company'] == companyId && item['status'] == 1).toList()
          ..sort((a, b) => DateTime.parse(b['fecha_creacion'] ?? DateTime.now().toIso8601String())
              .compareTo(DateTime.parse(a['fecha_creacion'] ?? DateTime.now().toIso8601String())));
      });
    }

    // ========================================================================
    // INTEGRACIÃ“N CON SUPPLY COMPANY
    // ========================================================================

    static Future<List<Map<String, dynamic>>> getInventoryWithSuppliers() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return [];

        final response = await _supabase
            .from('inventario')
            .select('''
            *,
            locat!inventario_id_location_fkey (
              id_locat,
              lugar_fisico,
              coordenadas
            ),
            supply_company!inventario_id_supply_company_fkey (
              id,
              name,
              email,
              phone,
              direccion
            )
          ''')
            .eq('user_id', userId)
            .eq('status', 1)
            .order('fecha_creacion', ascending: false);

        final List<Map<String, dynamic>> inventory = [];

        for (var item in response) {
          final location = item['locat'];
          final supplier = item['supply_company'];
          final distribution = await getProductLocationDistribution(item['id_inventario']);

          inventory.add({
            ...item,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'coordenadas': location?['coordenadas'],
            'proveedor_id': supplier?['id'],
            'proveedor_nombre': supplier?['name'],
            'proveedor_email': supplier?['email'],
            'proveedor_phone': supplier?['phone'],
            'proveedor_direccion': supplier?['direccion'],
            'stock_status': _calculateStockStatus(item['cantidad'], item['alerta_cantidad']),
            'precio': item['precio'] ?? 0.0,
            'image_url': item['imagen'],
            'ubicaciones': distribution,
          });
        }

        return inventory;
      } catch (e) {
        throw Exception('Error al obtener inventario con proveedores: $e');
      }
    }

    static Future<List<Map<String, dynamic>>> getInventoryBySupplier(int supplierId) async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return [];

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
            .eq('id_supply_company', supplierId)
            .eq('status', 1)
            .order('nombre_producto', ascending: true);

        final List<Map<String, dynamic>> inventory = [];

        for (var item in response) {
          final location = item['locat'];
          inventory.add({
            ...item,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'coordenadas': location?['coordenadas'],
            'stock_status': _calculateStockStatus(item['cantidad'], item['alerta_cantidad']),
          });
        }

        return inventory;
      } catch (e) {
        if (kDebugMode) print('Error al obtener productos del proveedor: $e');
        return [];
      }
    }

    static Future<void> assignSupplierToProduct(int productId, int? supplierId) async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) throw Exception('Usuario no autenticado');

        await _supabase
            .from('inventario')
            .update({
          'id_supply_company': supplierId,
          'fecha_modificacion': DateTime.now().toIso8601String(),
        })
            .eq('id_inventario', productId)
            .eq('user_id', userId);
      } catch (e) {
        throw Exception('Error al asignar proveedor: $e');
      }
    }

    static Future<void> updateProductPrice(int productId, double newPrice) async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) throw Exception('Usuario no autenticado');

        await _supabase
            .from('inventario')
            .update({
          'precio': newPrice,
          'fecha_modificacion': DateTime.now().toIso8601String(),
        })
            .eq('id_inventario', productId)
            .eq('user_id', userId);
      } catch (e) {
        throw Exception('Error al actualizar precio: $e');
      }
    }

    static Future<Map<String, dynamic>> getInventoryStatsWithSuppliers() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return _emptyStatsExtended();

        final inventory = await _supabase
            .from('inventario')
            .select('cantidad, alerta_cantidad, status, precio, id_supply_company')
            .eq('user_id', userId);

        final locations = await _supabase
            .from('locat')
            .select('status')
            .eq('user_id', userId);

        final suppliers = await _supabase
            .from('supply_company')
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
        final activeSuppliers = suppliers.where((sup) => sup['status'] == 1).length;

        final totalValue = inventory.where((item) => item['status'] == 1).fold<double>(
            0.0,
                (sum, item) => sum + ((item['cantidad'] ?? 0) * (item['precio'] ?? 0.0))
        );

        final productsWithSupplier = inventory.where((item) =>
        item['status'] == 1 && item['id_supply_company'] != null).length;

        return {
          'total_productos': inventory.length,
          'productos_activos': activeProducts,
          'productos_sin_stock': outOfStock,
          'productos_stock_bajo': lowStock,
          'total_ubicaciones': locations.length,
          'ubicaciones_activas': activeLocations,
          'total_proveedores': suppliers.length,
          'proveedores_activos': activeSuppliers,
          'valor_total_inventario': totalValue,
          'productos_con_proveedor': productsWithSupplier,
          'productos_sin_proveedor': activeProducts - productsWithSupplier,
        };
      } catch (e) {
        if (kDebugMode) print('Error obteniendo estadisticas extendidas: $e');
        return _emptyStatsExtended();
      }
    }

    static Map<String, dynamic> _emptyStatsExtended() {
      return {
        'total_productos': 0,
        'productos_activos': 0,
        'productos_sin_stock': 0,
        'productos_stock_bajo': 0,
        'total_ubicaciones': 0,
        'ubicaciones_activas': 0,
        'total_proveedores': 0,
        'proveedores_activos': 0,
        'valor_total_inventario': 0.0,
        'productos_con_proveedor': 0,
        'productos_sin_proveedor': 0,
      };
    }

    static Future<List<Map<String, dynamic>>> getInventoryValueBySupplier() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return [];

        final inventory = await _supabase
            .from('inventario')
            .select('''
            cantidad,
            precio,
            id_supply_company,
            supply_company!inventario_id_supply_company_fkey (
              id,
              name
            )
          ''')
            .eq('user_id', userId)
            .eq('status', 1)
            .not('id_supply_company', 'is', null);

        final Map<int, Map<String, dynamic>> supplierValues = {};

        for (var item in inventory) {
          final supplier = item['supply_company'];
          if (supplier == null) continue;

          final supplierId = supplier['id'] as int;
          final cantidad = (item['cantidad'] ?? 0) as int;
          final precio = (item['precio'] ?? 0.0) as double;
          final valor = cantidad * precio;

          if (!supplierValues.containsKey(supplierId)) {
            supplierValues[supplierId] = {
              'supplier_id': supplierId,
              'supplier_name': supplier['name'],
              'total_products': 0,
              'total_stock': 0,
              'total_value': 0.0,
            };
          }

          supplierValues[supplierId]!['total_products'] += 1;
          supplierValues[supplierId]!['total_stock'] += cantidad;
          supplierValues[supplierId]!['total_value'] += valor;
        }

        final result = supplierValues.values.toList()
          ..sort((a, b) =>
              (b['total_value'] as double).compareTo(a['total_value'] as double));

        return result;
      } catch (e) {
        if (kDebugMode) print('Error obteniendo valor por proveedor: $e');
        return [];
      }
    }

    static Future<List<Map<String, dynamic>>> getProductsWithoutSupplier() async {
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
            .eq('status', 1)
            .filter('id_supply_company', 'is', null)
            .order('nombre_producto', ascending: true);

        final List<Map<String, dynamic>> inventory = [];

        for (var item in response) {
          final location = item['locat'];
          inventory.add({
            ...item,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'stock_status': _calculateStockStatus(item['cantidad'], item['alerta_cantidad']),
          });
        }

        return inventory;
      } catch (e) {
        if (kDebugMode) print('Error obteniendo productos sin proveedor: $e');
        return [];
      }
    }

    static String formatPrice(dynamic price) {
      if (price == null) return 'Q 0.00';
      final double priceValue = price is double ? price : double.tryParse(price.toString()) ?? 0.0;
      return 'Q ${priceValue.toStringAsFixed(2)}';
    }

    static double calculateProductValue(Map<String, dynamic> product) {
      final cantidad = (product['cantidad'] ?? 0) as int;
      final precio = (product['precio'] ?? 0.0);
      final precioDouble = precio is double ? precio : double.tryParse(precio.toString()) ?? 0.0;
      return cantidad * precioDouble;
    }

    static Future<Map<String, dynamic>?> getCurrentCompanyInfo() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return null;

        final response = await _supabase
            .rpc('get_company_info', params: {'user_uuid': userId});

        if (response != null && response is List && response.isNotEmpty) {
          return response.first as Map<String, dynamic>;
        }
        return null;
      } catch (e) {
        if (kDebugMode) print('Error obteniendo info de compania: $e');
        return null;
      }
    }

    static Future<int?> getCurrentCompanyId() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return null;

        final response = await _supabase
            .from('profiles')
            .select('id_company')
            .eq('id', userId)
            .maybeSingle();

        return response?['id_company'] as int?;
      } catch (e) {
        if (kDebugMode) print('Error obteniendo id_company: $e');
        return null;
      }
    }

    static Future<List<Map<String, dynamic>>> getCompanyUsers() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return [];

        final response = await _supabase
            .rpc('get_company_users_with_emails', params: {'user_uuid': userId});

        if (response == null) return [];

        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        if (kDebugMode) print('Error: $e');
        return [];
      }
    }

    static Future<void> updateCompanyInfo(Map<String, dynamic> updates) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compaÃ±Ã­a');

        await _supabase
            .from('company')
            .update(updates)
            .eq('id_company', companyId);
      } catch (e) {
        throw Exception('Error al actualizar compaÃ±Ã­a: $e');
      }
    }

    static Future<void> distributeStock(
        int productId,
        Map<int, int> distribution,
        ) async {
      try {
        final userId = AuthService.currentUser?.id;
        final companyId = await getCurrentCompanyId();

        if (userId == null) throw Exception('Usuario no autenticado');
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compaÃ±Ã­a');

        final product = await _supabase
            .from('inventario')
            .select('cantidad')
            .eq('id_inventario', productId)
            .eq('id_company', companyId)
            .single();

        final totalStock = product['cantidad'] as int;
        final distributedTotal = distribution.values.fold(0, (sum, qty) => sum + qty);

        if (distributedTotal > totalStock) {
          throw Exception('La distribucion excede el stock total disponible');
        }

        final currentDistributions = await _supabase
            .from('inventory_location_stock')
            .select('id_location, cantidad')
            .eq('id_inventario', productId)
            .eq('id_company', companyId);

        final Set<int> currentLocationIds = currentDistributions
            .map((d) => d['id_location'] as int)
            .toSet();

        final List<Map<String, dynamic>> toUpsert = [];
        final List<int> toDelete = [];

        for (var entry in distribution.entries) {
          final locationId = entry.key;
          final cantidad = entry.value;

          if (cantidad > 0) {
            toUpsert.add({
              'id_inventario': productId,
              'id_location': locationId,
              'id_company': companyId,
              'user_id': userId,
              'cantidad': cantidad,
              'status': 1,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
          } else if (currentLocationIds.contains(locationId)) {
            toDelete.add(locationId);
          }
        }

        for (var locationId in currentLocationIds) {
          if (!distribution.containsKey(locationId)) {
            toDelete.add(locationId);
          }
        }

        if (toUpsert.isNotEmpty) {
          await _supabase
              .from('inventory_location_stock')
              .upsert(
            toUpsert,
            onConflict: 'id_inventario,id_location',
          );
        }

        if (toDelete.isNotEmpty) {
          for (var locationId in toDelete) {
            await _supabase
                .from('inventory_location_stock')
                .delete()
                .eq('id_inventario', productId)
                .eq('id_location', locationId)
                .eq('id_company', companyId);
          }
        }

        if (kDebugMode) {

        }
      } catch (e) {
        if (kDebugMode) print(' Error distribuyendo stock: $e');
        throw Exception('Error al distribuir stock: $e');
      }
    }

    static Future<void> distributeStockRPC(
        int productId,
        Map<int, int> distribution,
        ) async {
      try {
        if (kDebugMode) {

        }

        final Map<String, dynamic> jsonbDistribution = {};
        distribution.forEach((locationId, cantidad) {
          jsonbDistribution[locationId.toString()] = {
            'cantidad': cantidad,
          };
        });


        final response = await _supabase.rpc(
          'distribute_product_stock',
          params: {
            'p_product_id': productId,
            'p_distribution': jsonbDistribution,
          },
        );



        if (response == null) {
          throw Exception('La funcion RPC no retorno respuesta');
        }

        final success = response['success'];

        if (success == true) {

        } else {
          final error = response['error'] ?? 'Error desconocido';
          final detail = response['detail'] ?? '';

          throw Exception('RPC Error: $error');
        }
      } catch (e, stackTrace) {

        rethrow;
      }
    }

    // ========================================================================
    // RESTOCK REQUESTS - SOLICITUDES DE REABASTECIMIENTO
    // ========================================================================

    static Future<Map<String, dynamic>> createRestockRequest({
      required int productId,
      required int requestedQuantity,
      String priority = 'normal',
      String? notes,
    }) async {
      try {
        final userId = AuthService.currentUser?.id;
        final companyId = await getCurrentCompanyId();

        if (userId == null) throw Exception('Usuario no autenticado');
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compaÃ±Ã­a');

        final product = await _supabase
            .from('inventario')
            .select('nombre_producto, imagen, cantidad, id_supply_company')
            .eq('id_inventario', productId)
            .eq('id_company', companyId)
            .single();

        final response = await _supabase
            .from('restock_requests')
            .insert({
          'user_id': userId,
          'id_company': companyId,
          'id_inventario': productId,
          'id_supply_company': product['id_supply_company'],
          'nombre_producto': product['nombre_producto'],
          'imagen': product['imagen'],
          'stock_actual': product['cantidad'],
          'cantidad_solicitada': requestedQuantity,
          'priority': priority,
          'notes': notes,
          'status': 'pending',
          'fecha_solicitud': DateTime.now().toIso8601String(),
        })
            .select()
            .single();

        if (kDebugMode) {

        }

        return response;
      } catch (e) {
        if (kDebugMode) print('âŒ Error creando solicitud de restock: $e');
        throw Exception('Error al crear solicitud de restock: $e');
      }
    }

    static Future<List<Map<String, dynamic>>> getRestockRequests({
      String? status,
      String? priority,
    }) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        var query = _supabase
            .from('restock_requests')
            .select('''
            *,
            supply_company!restock_requests_id_supply_company_fkey (
              id,
              name,
              email,
              phone
            )
          ''')
            .eq('id_company', companyId);

        if (status != null) {
          query = query.eq('status', status);
        }

        if (priority != null) {
          query = query.eq('priority', priority);
        }

        final response = await query.order('fecha_solicitud', ascending: false);
        return List<Map<String, dynamic>>.from(response);
      } catch (e) {
        if (kDebugMode) print('Error obteniendo solicitudes de restock: $e');
        return [];
      }
    }

    static Future<List<Map<String, dynamic>>> getPendingRestockRequests() async {
      return getRestockRequests(status: 'pending');
    }

    static Future<Map<String, dynamic>> getRestockRequestsStats() async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) return _emptyRestockStats();

        final response = await _supabase
            .rpc('get_restock_requests_stats', params: {'user_uuid': userId});

        if (response != null && response is List && response.isNotEmpty) {
          return response.first as Map<String, dynamic>;
        }

        return _emptyRestockStats();
      } catch (e) {
        if (kDebugMode) print('Error obteniendo estadIsticas de restock: $e');
        return _emptyRestockStats();
      }
    }

    static Map<String, dynamic> _emptyRestockStats() {
      return {
        'total_requests': 0,
        'pending_requests': 0,
        'approved_requests': 0,
        'completed_requests': 0,
        'rejected_requests': 0,
        'urgent_requests': 0,
      };
    }

    static Future<void> updateRestockRequestStatus({
      required int requestId,
      required String status,
      String? supplierResponse,
      DateTime? estimatedDeliveryDate,
    }) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compaÃ±Ã­a');

        final updates = <String, dynamic>{
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        };

        if (supplierResponse != null) {
          updates['supplier_response'] = supplierResponse;
          updates['fecha_respuesta'] = DateTime.now().toIso8601String();
        }

        if (estimatedDeliveryDate != null) {
          updates['estimated_delivery_date'] = estimatedDeliveryDate.toIso8601String();
        }

        if (status == 'completed') {
          updates['fecha_completado'] = DateTime.now().toIso8601String();
        }

        await _supabase
            .from('restock_requests')
            .update(updates)
            .eq('id', requestId)
            .eq('id_company', companyId);

        if (kDebugMode) {
        }
      } catch (e) {
        throw Exception('Error al actualizar solicitud: $e');
      }
    }

    static Future<void> cancelRestockRequest(int requestId) async {
      try {
        final userId = AuthService.currentUser?.id;
        if (userId == null) throw Exception('Usuario no autenticado');

        await _supabase
            .from('restock_requests')
            .update({
          'status': 'cancelled',
          'updated_at': DateTime.now().toIso8601String(),
        })
            .eq('id', requestId)
            .eq('user_id', userId);

        if (kDebugMode) {
        }
      } catch (e) {
        throw Exception('Error al cancelar solicitud: $e');
      }
    }

    static String getRestockStatusText(String? status) {
      switch (status?.toLowerCase()) {
        case 'pending':
          return 'Pendiente';
        case 'approved':
          return 'Aprobada';
        case 'rejected':
          return 'Rechazada';
        case 'completed':
          return 'Completada';
        case 'cancelled':
          return 'Cancelada';
        default:
          return 'Desconocido';
      }
    }

    static String getRestockStatusColor(String? status) {
      switch (status?.toLowerCase()) {
        case 'pending':
          return '#F59E0B';
        case 'approved':
          return '#3B82F6';
        case 'rejected':
          return '#EF4444';
        case 'completed':
          return '#6B8E3D';
        case 'cancelled':
          return '#6B7280';
        default:
          return '#6B7280';
      }
    }

    static String getRestockPriorityText(String? priority) {
      switch (priority?.toLowerCase()) {
        case 'low':
          return 'Baja';
        case 'normal':
          return 'Normal';
        case 'high':
          return 'Alta';
        case 'urgent':
          return 'Urgente';
        default:
          return 'Normal';
      }
    }


    // ========================================================================
  // AGREGAR ESTE MÃ‰TODO AL inventory_service.dart
  // ========================================================================

    /// Obtener un producto especfico por ID
    static Future<Map<String, dynamic>?> getProductById(int productId) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return null;

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
            .eq('id_inventario', productId)
            .eq('id_company', companyId)
            .eq('status', 1)
            .maybeSingle();

        if (response == null) return null;

        final location = response['locat'];

        return {
          ...response,
          'id_locat': location?['id_locat'],
          'lugar_fisico': location?['lugar_fisico'],
          'coordenadas': location?['coordenadas'],
          'stock_status': _calculateStockStatus(
              response['cantidad'],
              response['alerta_cantidad']
          ),
        };
      } catch (e) {
        if (kDebugMode) print('Error obteniendo producto: $e');
        return null;
      }
    }
    static String getRestockPriorityColor(String? priority) {
      switch (priority?.toLowerCase()) {
        case 'low':
          return '#6B7280';
        case 'normal':
          return '#3B82F6';
        case 'high':
          return '#F59E0B';
        case 'urgent':
          return '#EF4444';
        default:
          return '#3B82F6';
      }
    }

    // ========================================================================
// EXTENSIÓN PARA inventory_service.dart
// Agregar estos métodos al final de la clase InventoryService
// ========================================================================

// AGREGAR AL INICIO DE LA CLASE (después de las constantes):
/*
  // Caché en memoria
  static final Map<String, dynamic> _cache = {};
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration = Duration(minutes: 5);
  static const int _pageSize = 20;
*/

// AGREGAR ESTOS MÉTODOS AL FINAL DE LA CLASE InventoryService:

    // ========================================================================
    // MÉTODOS OPTIMIZADOS CON PAGINACIÓN
    // ========================================================================

    /// Obtiene inventario paginado (optimizado)
    static Future<Map<String, dynamic>> getInventoryPaged({
      int page = 0,
      int pageSize = 20,
      bool forceRefresh = false,
    }) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) {
          return {'items': [], 'hasMore': false, 'total': 0};
        }

        // Verificar caché
        if (page == 0 && !forceRefresh && _isCacheValid()) {
          final cached = _cache['inventory_page_0'];
          if (cached != null) {
            if (kDebugMode) print('📦 Usando caché');
            return cached as Map<String, dynamic>;
          }
        }

        final from = page * pageSize;
        final to = from + pageSize - 1;

        if (kDebugMode) print('🔄 Cargando página $page');

        // Query optimizado
        final response = await _supabase
            .from('inventario')
            .select('''
            id_inventario,
            nombre_producto,
            imagen,
            cantidad,
            alerta_cantidad,
            precio,
            fecha_modificacion,
            locat!inventario_id_location_fkey (
              id_locat,
              lugar_fisico
            )
          ''')
            .eq('id_company', companyId)
            .eq('status', 1)
            .order('fecha_creacion', ascending: false)
            .range(from, to);

        final items = List<Map<String, dynamic>>.from(response as List);

        final processedItems = items.map((item) {
          final location = item['locat'];
          return {
            'id_inventario': item['id_inventario'],
            'nombre_producto': item['nombre_producto'],
            'imagen': item['imagen'],
            'image_url': item['imagen'],
            'cantidad': item['cantidad'] ?? 0,
            'alerta_cantidad': item['alerta_cantidad'] ?? 5,
            'precio': item['precio'] ?? 0.0,
            'fecha_modificacion': item['fecha_modificacion'],
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'stock_status': _calculateStockStatus(
              item['cantidad'],
              item['alerta_cantidad'],
            ),
            '_ubicaciones_loaded': false,
          };
        }).toList();

        final result = {
          'items': processedItems,
          'hasMore': items.length == pageSize,
          'total': items.length,
          'page': page,
        };

        // Guardar en caché primera página
        if (page == 0) {
          _cache['inventory_page_0'] = result;
          _cacheTimestamp = DateTime.now();
        }

        if (kDebugMode) print('✅ Cargados ${items.length} productos');

        return result;
      } catch (e) {
        if (kDebugMode) print('❌ Error: $e');
        return {'items': [], 'hasMore': false, 'total': 0};
      }
    }

    /// Búsqueda paginada
    static Future<Map<String, dynamic>> searchInventoryPaged({
      required String searchText,
      int page = 0,
      int pageSize = 20,
    }) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) {
          return {'items': [], 'hasMore': false, 'total': 0};
        }

        final from = page * pageSize;
        final to = from + pageSize - 1;

        final response = await _supabase
            .from('inventario')
            .select('''
            id_inventario,
            nombre_producto,
            imagen,
            cantidad,
            alerta_cantidad,
            precio,
            locat!inventario_id_location_fkey (
              id_locat,
              lugar_fisico
            )
          ''')
            .eq('id_company', companyId)
            .eq('status', 1)
            .or('nombre_producto.ilike.%$searchText%')
            .order('nombre_producto', ascending: true)
            .range(from, to);

        final items = List<Map<String, dynamic>>.from(response as List);

        final processedItems = items.map((item) {
          final location = item['locat'];
          return {
            'id_inventario': item['id_inventario'],
            'nombre_producto': item['nombre_producto'],
            'imagen': item['imagen'],
            'image_url': item['imagen'],
            'cantidad': item['cantidad'] ?? 0,
            'alerta_cantidad': item['alerta_cantidad'] ?? 5,
            'precio': item['precio'] ?? 0.0,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'stock_status': _calculateStockStatus(
              item['cantidad'],
              item['alerta_cantidad'],
            ),
          };
        }).toList();

        return {
          'items': processedItems,
          'hasMore': items.length == pageSize,
          'total': items.length,
          'page': page,
        };
      } catch (e) {
        if (kDebugMode) print('Error en búsqueda: $e');
        return {'items': [], 'hasMore': false, 'total': 0};
      }
    }

    /// Obtiene contadores para filtros (rápido)
    static Future<Map<String, int>> getFilterCounts() async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) {
          return {'all': 0, 'normal': 0, 'low_stock': 0, 'out_of_stock': 0};
        }

        // Usar caché
        if (_isCacheValid() && _cache.containsKey('filter_counts')) {
          return _cache['filter_counts'] as Map<String, int>;
        }

        final response = await _supabase
            .from('inventario')
            .select('cantidad, alerta_cantidad')
            .eq('id_company', companyId)
            .eq('status', 1);

        final items = List<Map<String, dynamic>>.from(response as List);
        final total = items.length;

        int normal = 0;
        int lowStock = 0;
        int outOfStock = 0;

        for (var item in items) {
          final cantidad = item['cantidad'] ?? 0;
          final alerta = item['alerta_cantidad'] ?? 5;

          if (cantidad == 0) {
            outOfStock++;
          } else if (cantidad <= alerta) {
            lowStock++;
          } else {
            normal++;
          }
        }

        final counts = {
          'all': total,
          'normal': normal,
          'low_stock': lowStock,
          'out_of_stock': outOfStock,
        };

        _cache['filter_counts'] = counts;
        return counts;
      } catch (e) {
        if (kDebugMode) print('Error obteniendo contadores: $e');
        return {'all': 0, 'normal': 0, 'low_stock': 0, 'out_of_stock': 0};
      }
    }

    /// Inventario filtrado por estado
    static Future<Map<String, dynamic>> getInventoryFiltered({
      required String filter,
      int page = 0,
      int pageSize = 20,
    }) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) {
          return {'items': [], 'hasMore': false, 'total': 0};
        }

        final from = page * pageSize;
        final to = from + pageSize - 1;

        var query = _supabase
            .from('inventario')
            .select('''
            id_inventario,
            nombre_producto,
            imagen,
            cantidad,
            alerta_cantidad,
            precio,
            locat!inventario_id_location_fkey (
              id_locat,
              lugar_fisico
            )
          ''')
            .eq('id_company', companyId)
            .eq('status', 1);

        if (filter == 'out_of_stock') {
          query = query.eq('cantidad', 0);
        }

        final response = await query
            .order('fecha_creacion', ascending: false)
            .range(from, to);

        var items = List<Map<String, dynamic>>.from(response as List);

        // Filtrar en cliente si es necesario
        if (filter == 'low_stock' || filter == 'normal') {
          items = items.where((item) {
            final cantidad = item['cantidad'] ?? 0;
            final alerta = item['alerta_cantidad'] ?? 5;

            if (filter == 'low_stock') {
              return cantidad > 0 && cantidad <= alerta;
            } else {
              return cantidad > alerta;
            }
          }).toList();
        }

        final processedItems = items.map((item) {
          final location = item['locat'];
          return {
            'id_inventario': item['id_inventario'],
            'nombre_producto': item['nombre_producto'],
            'imagen': item['imagen'],
            'image_url': item['imagen'],
            'cantidad': item['cantidad'] ?? 0,
            'alerta_cantidad': item['alerta_cantidad'] ?? 5,
            'precio': item['precio'] ?? 0.0,
            'id_locat': location?['id_locat'],
            'lugar_fisico': location?['lugar_fisico'],
            'stock_status': _calculateStockStatus(
              item['cantidad'],
              item['alerta_cantidad'],
            ),
          };
        }).toList();

        return {
          'items': processedItems,
          'hasMore': items.length == pageSize,
          'total': items.length,
          'page': page,
        };
      } catch (e) {
        if (kDebugMode) print('Error en filtro: $e');
        return {'items': [], 'hasMore': false, 'total': 0};
      }
    }

    // ========================================================================
    // UTILIDADES DE CACHÉ
    // ========================================================================

    static bool _isCacheValid() {
      if (_cacheTimestamp == null) return false;
      final elapsed = DateTime.now().difference(_cacheTimestamp!);
      return elapsed < _cacheDuration;
    }

    static void invalidateCache() {
      _cache.clear();
      _cacheTimestamp = null;
      if (kDebugMode) print('🗑️ Caché invalidado');
    }




// ============================================================================
// MÉTODOS FALTANTES PARA AGREGAR A inventory_service.dart
// ============================================================================
// Agregar estos métodos al final de la clase InventoryService

    // ========================================================================
    // MÉTODO: loadProductDistribution (LAZY LOADING)
    // ========================================================================

    /// Carga la distribución de un producto de forma lazy (bajo demanda)
    static Future<List<Map<String, dynamic>>> loadProductDistribution(int productId) async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        if (kDebugMode) {
          print('📍 Cargando distribución para producto $productId');
        }

        final response = await _supabase
            .from('inventory_location_stock')
            .select('''
            cantidad,
            id_location,
            locat!inner(
              id_locat,
              lugar_fisico,
              coordenadas
            )
          ''')
            .eq('id_inventario', productId)
            .eq('id_company', companyId)
            .eq('status', 1)
            .gt('cantidad', 0);

        final ubicaciones = response.map<Map<String, dynamic>>((item) {
          final location = item['locat'];
          return {
            'id_locat': location['id_locat'],
            'lugar_fisico': location['lugar_fisico'],
            'coordenadas': location['coordenadas'],
            'cantidad': item['cantidad'],
          };
        }).toList();

        if (kDebugMode) {
          print('✅ ${ubicaciones.length} ubicaciones cargadas');
        }

        return ubicaciones;
      } catch (e) {
        if (kDebugMode) print('❌ Error cargando distribución: $e');
        return [];
      }
    }

    // ========================================================================
    // MÉTODO: Obtener todos los productos (sin paginación) - USADO EN CART
    // ========================================================================

    /// Obtiene todos los productos activos (usado en cart_service)
    static Future<List<Map<String, dynamic>>> getAllProducts() async {
      try {
        final companyId = await getCurrentCompanyId();
        if (companyId == null) return [];

        final response = await _supabase
            .from('inventario')
            .select('''
            id_inventario,
            nombre_producto,
            imagen,
            cantidad,
            alerta_cantidad,
            precio,
            descripcion
          ''')
            .eq('id_company', companyId)
            .eq('status', 1)
            .order('nombre_producto', ascending: true);

        return List<Map<String, dynamic>>.from(response as List).map((item) {
          return {
            ...item,
            'image_url': item['imagen'],
            'stock_status': _calculateStockStatus(
              item['cantidad'],
              item['alerta_cantidad'],
            ),
          };
        }).toList();
      } catch (e) {
        if (kDebugMode) print('Error obteniendo productos: $e');
        return [];
      }
    }

    // ========================================================================
    // MÉTODO ALTERNATIVO: distributeStockSimple (Si RPC falla)
    // ========================================================================

    /// Distribución sin RPC (fallback si la función RPC no existe)
    static Future<void> distributeStockSimple(
        int productId,
        Map<int, int> distribution,
        ) async {
      try {
        final userId = AuthService.currentUser?.id;
        final companyId = await getCurrentCompanyId();

        if (userId == null) throw Exception('Usuario no autenticado');
        if (companyId == null) throw Exception('Usuario no pertenece a ninguna compañía');

        // 1. Validar stock total
        final product = await _supabase
            .from('inventario')
            .select('cantidad')
            .eq('id_inventario', productId)
            .eq('id_company', companyId)
            .single();

        final totalStock = product['cantidad'] as int;
        final distributedTotal = distribution.values.fold(0, (sum, qty) => sum + qty);

        if (distributedTotal > totalStock) {
          throw Exception('La distribución ($distributedTotal) excede el stock total ($totalStock)');
        }

        // 2. Eliminar distribuciones existentes
        await _supabase
            .from('inventory_location_stock')
            .delete()
            .eq('id_inventario', productId)
            .eq('id_company', companyId);

        if (kDebugMode) print('🗑️ Distribuciones anteriores eliminadas');

        // 3. Insertar nuevas distribuciones
        final toInsert = <Map<String, dynamic>>[];

        for (var entry in distribution.entries) {
          if (entry.value > 0) {
            toInsert.add({
              'id_inventario': productId,
              'id_location': entry.key,
              'id_company': companyId,
              'user_id': userId,
              'cantidad': entry.value,
              'status': 1,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }

        if (toInsert.isNotEmpty) {
          await _supabase
              .from('inventory_location_stock')
              .insert(toInsert);

          if (kDebugMode) {
            print('✅ ${toInsert.length} ubicaciones distribuidas');
          }
        }

        // 4. Actualizar fecha_modificacion en inventario
        await _supabase
            .from('inventario')
            .update({'fecha_modificacion': DateTime.now().toIso8601String()})
            .eq('id_inventario', productId)
            .eq('id_company', companyId);

      } catch (e) {
        if (kDebugMode) print('❌ Error en distributeStockSimple: $e');
        rethrow;
      }
    }

    // ========================================================================
    // MÉTODO: Wrapper que intenta RPC primero, luego fallback
    // ========================================================================

    /// Intenta usar RPC, si falla usa método simple
    static Future<void> distributeStockSafe(
        int productId,
        Map<int, int> distribution,
        ) async {
      try {
        // Intentar primero con RPC
        await distributeStockRPC(productId, distribution);
      } catch (e) {
        if (kDebugMode) {
          print('⚠️ RPC falló, usando método alternativo: $e');
        }

        // Fallback al método simple
        await distributeStockSimple(productId, distribution);
      }
    }

// ============================================================================
// FIN DE MÉTODOS FALTANTES
// ============================================================================
  }