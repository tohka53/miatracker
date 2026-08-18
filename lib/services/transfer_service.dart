import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class TransferService {
  static final SupabaseClient _supabase = AuthService.client;

  // ========================================================================
  // OBTENER INVENTARIO CON UBICACIONES PARA TRANSFERENCIAS
  // ========================================================================

  static Future<List<Map<String, dynamic>>> getInventoryWithLocations() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      // Obtener inventario con stock por ubicación
      final response = await _supabase
          .from('inventory_location_stock')
          .select('''
            id,
            id_inventario,
            id_location,
            cantidad,
            inventario!inner(
              id_inventario,
              nombre_producto,
              imagen,
              descripcion,
              codigo_barras,
              status
            ),
            locat!inner(
              id_locat,
              lugar_fisico,
              coordenadas
            )
          ''')
          .eq('user_id', userId)
          .eq('status', 1)
          .gt('cantidad', 0)
          .order('inventario(nombre_producto)');

      if (kDebugMode) print('Raw inventory data: $response');

      // Agrupar por producto
      final Map<int, Map<String, dynamic>> productosAgrupados = {};

      for (var item in response) {
        final inventario = item['inventario'];
        final locat = item['locat'];
        final idInventario = item['id_inventario'] as int;
        final cantidad = item['cantidad'] as int;

        if (!productosAgrupados.containsKey(idInventario)) {
          productosAgrupados[idInventario] = {
            'id_inventario': idInventario,
            'nombre_producto': inventario['nombre_producto'],
            'imagen': inventario['imagen'],
            'descripcion': inventario['descripcion'],
            'codigo_barras': inventario['codigo_barras'],
            'cantidad_total': 0,
            'ubicaciones': <Map<String, dynamic>>[],
          };
        }

        productosAgrupados[idInventario]!['cantidad_total'] =
            (productosAgrupados[idInventario]!['cantidad_total'] as int) + cantidad;

        (productosAgrupados[idInventario]!['ubicaciones'] as List).add({
          'id_location': locat['id_locat'],
          'lugar_fisico': locat['lugar_fisico'],
          'coordenadas': locat['coordenadas'],
          'cantidad': cantidad,
        });
      }

      final resultado = productosAgrupados.values.toList();
      if (kDebugMode) print('Productos agrupados: ${resultado.length}');

      return resultado;
    } catch (e) {
      if (kDebugMode) print('Error obteniendo inventario con ubicaciones: $e');
      return [];
    }
  }

  // ========================================================================
  // CREAR ORDEN DE TRANSFERENCIA
  // ========================================================================

  static Future<Map<String, dynamic>> createTransferOrder({
    int? originLocationId,
    required int destinationLocationId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Preparar items para la función
      final itemsForFunction = items.map((item) {
        final itemData = <String, dynamic>{
          'id_inventario': item['id_inventario'],
          'quantity': item['cantidad'],
        };

        // Solo agregar from_location_id si hay origen
        if (originLocationId != null) {
          itemData['from_location_id'] = originLocationId;
        }

        return itemData;
      }).toList();

      if (kDebugMode) {
        print('Creando transferencia:');
        print('- Usuario: $userId');
        print('- Destino: $destinationLocationId');
        print('- Items: $itemsForFunction');
      }

      // Llamar a la función de Supabase
      final result = await _supabase.rpc(
        'create_transfer_order',
        params: {
          'user_uuid': userId,
          'p_to_location_id': destinationLocationId,
          'p_items': itemsForFunction,
          'p_notes': notes,
        },
      );

      if (kDebugMode) print('Resultado de create_transfer_order: $result');

      if (result['success'] == true) {
        return {
          'success': true,
          'transfer_id': result['transfer_id'],
          'transfer_code': result['transfer_code'],
          'qr_code_data': result['qr_code_data'],
          'message': result['message'],
        };
      } else {
        throw Exception(result['message'] ?? 'Error desconocido al crear transferencia');
      }
    } catch (e) {
      if (kDebugMode) print('Error creando orden de transferencia: $e');
      throw Exception('Error al crear transferencia: $e');
    }
  }

  // ========================================================================
  // VALIDAR TRANSFERENCIA ANTES DE CREAR
  // ========================================================================

  static Future<Map<String, dynamic>> validateTransfer({
    int? originLocationId,
    required List<Map<String, dynamic>> items,
  }) async {
    try {
      if (items.isEmpty) {
        return {'isValid': false, 'error': 'No hay productos para transferir'};
      }

      // Si hay origen, validar que hay suficiente stock
      if (originLocationId != null) {
        for (final item in items) {
          final productId = item['id_inventario'];
          final requestedQty = item['cantidad'] as int;

          // Obtener stock en ubicación origen
          final stockResult = await _supabase.rpc(
            'get_product_stock_at_location',
            params: {
              'p_inventario_id': productId,
              'p_location_id': originLocationId,
            },
          );

          final availableQty = stockResult as int? ?? 0;

          if (requestedQty > availableQty) {
            return {
              'isValid': false,
              'error': 'Stock insuficiente de ${item['nombre_producto']}. Disponible: $availableQty, Solicitado: $requestedQty'
            };
          }
        }
      }

      return {'isValid': true};
    } catch (e) {
      if (kDebugMode) print('Error validando transferencia: $e');
      return {'isValid': false, 'error': 'Error validando transferencia: $e'};
    }
  }

  // ========================================================================
  // PROCESAR/COMPLETAR TRANSFERENCIA
  // ========================================================================

  static Future<void> processTransfer(int transferId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Obtener información de la transferencia
      final transfer = await _supabase
          .from('transfer_orders')
          .select('transfer_code')
          .eq('id', transferId)
          .eq('user_id', userId)
          .eq('status', 'pending')
          .single();

      if (kDebugMode) print('Procesando transferencia: ${transfer['transfer_code']}');

      // Llamar a la función de Supabase para autorizar
      final result = await _supabase.rpc(
        'authorize_transfer',
        params: {
          'user_uuid': userId,
          'p_transfer_code': transfer['transfer_code'],
        },
      );

      if (kDebugMode) print('Resultado de authorize_transfer: $result');

      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Error al procesar transferencia');
      }
    } catch (e) {
      if (kDebugMode) print('Error procesando transferencia: $e');
      throw Exception('Error al procesar transferencia: $e');
    }
  }

  // ========================================================================
  // CANCELAR TRANSFERENCIA
  // ========================================================================

  static Future<void> cancelTransfer(int transferId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('transfer_orders')
          .update({
        'status': 'cancelled',
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', transferId)
          .eq('user_id', userId);

      if (kDebugMode) print('Transferencia cancelada: $transferId');
    } catch (e) {
      if (kDebugMode) print('Error cancelando transferencia: $e');
      throw Exception('Error al cancelar transferencia: $e');
    }
  }

  // ========================================================================
  // HISTORIAL DE TRANSFERENCIAS
  // ========================================================================

  static Future<List<Map<String, dynamic>>> getTransferHistory() async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('transfer_orders')
          .select('''
            *,
            from_location:locat!from_location_id(lugar_fisico),
            to_location:locat!to_location_id(lugar_fisico)
          ''')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      if (kDebugMode) print('Transfer history: $response');

      return response.map<Map<String, dynamic>>((transfer) {
        return {
          ...transfer,
          'transfer_code': transfer['transfer_code'],
          'id': transfer['id'],
          'status': transfer['status'],
          'total_items': transfer['total_items'],
          'origen': transfer['from_location']?['lugar_fisico'],
          'destino': transfer['to_location']?['lugar_fisico'] ?? 'N/A',
          'fecha_creacion': transfer['created_at'],
        };
      }).toList();
    } catch (e) {
      if (kDebugMode) print('Error obteniendo historial: $e');
      return [];
    }
  }

  // ========================================================================
  // BUSCAR TRANSFERENCIA POR CÓDIGO
  // ========================================================================

  static Future<Map<String, dynamic>?> getTransferByCode(String code) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) return null;

      // Obtener la transferencia
      final transfer = await _supabase
          .from('transfer_orders')
          .select('''
            *,
            from_location:locat!transfer_orders_from_location_id_fkey(*),
            to_location:locat!transfer_orders_to_location_id_fkey(*)
          ''')
          .eq('transfer_code', code)
          .eq('user_id', userId)
          .maybeSingle();

      if (transfer == null) return null;

      // Obtener los items de la transferencia
      final items = await _supabase
          .from('transfer_order_items')
          .select('''
            *,
            inventario(nombre_producto, imagen)
          ''')
          .eq('transfer_order_id', transfer['id']);

      final details = items.map((item) {
        return {
          ...item,
          'nombre_producto': item['inventario']?['nombre_producto'] ?? 'N/A',
          'imagen': item['inventario']?['imagen'],
        };
      }).toList();

      return {
        ...transfer,
        'locat_origen': transfer['from_location'],
        'locat_destino': transfer['to_location'],
        'details': details,
      };
    } catch (e) {
      if (kDebugMode) print('Error buscando transferencia: $e');
      return null;
    }
  }

  // ========================================================================
  // GENERACIÓN Y PARSEO DE QR PARA TRANSFERENCIAS
  // ========================================================================

  static String generateTransferQRData(Map<String, dynamic> transfer) {
    try {
      final qrData = {
        'type': 'mia_transfer',
        'code': transfer['transfer_code'],
        'id': transfer['id']?.toString() ?? '0',
        'destination': transfer['to_location_id']?.toString() ??
            transfer['id_locat_destino']?.toString() ?? '0',
        'items': transfer['total_items']?.toString() ?? '0',
        'status': transfer['status'] ?? 'pending',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      return qrData.entries.map((e) => '${e.key}:${e.value}').join('|');
    } catch (e) {
      if (kDebugMode) print('Error generando QR de transferencia: $e');
      return 'TRANS:${transfer['transfer_code']}';
    }
  }

  static Map<String, dynamic>? parseTransferQRData(String qrData) {
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

        if (data['type'] == 'mia_transfer') {
          return data;
        }
      }

      // Intentar extraer código si es formato simple
      if (qrData.startsWith('TRF-')) {
        return {'code': qrData, 'type': 'mia_transfer'};
      }

      return null;
    } catch (e) {
      if (kDebugMode) print('Error parseando QR de transferencia: $e');
      return null;
    }
  }

  // ========================================================================
  // UTILIDADES
  // ========================================================================

  static String getTransferStatusText(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'in_transit':
        return 'In Transit';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Desconocido';
    }
  }

  static String getTransferStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return '#F59E0B';
      case 'in_transit':
        return '#2B5F8C';
      case 'completed':
        return '#6B8E3D';
      case 'cancelled':
        return '#EF4444';
      default:
        return '#6B7280';
    }
  }
}