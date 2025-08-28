import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseUtils {
  // Manejar errores de Supabase de forma consistente
  static String handleSupabaseError(dynamic error) {
    if (error is AuthException) {
      switch (error.statusCode) {
        case '400':
          if (error.message.contains('Invalid login credentials')) {
            return 'Email o contraseña incorrectos';
          } else if (error.message.contains('Email not confirmed')) {
            return 'Por favor verifica tu email antes de iniciar sesión';
          }
          break;
        case '422':
          if (error.message.contains('User already registered')) {
            return 'Este email ya está registrado. Intenta iniciar sesión.';
          }
          break;
        case '429':
          return 'Demasiados intentos. Por favor espera unos minutos.';
        default:
          return error.message;
      }
    }

    if (error is PostgrestException) {
      switch (error.code) {
        case '23505': // Unique violation
          return 'Este registro ya existe. Verifica los datos únicos como asset_tag.';
        case '23503': // Foreign key violation
          return 'Error de referencia: el registro relacionado no existe.';
        case '23502': // Not null violation
          return 'Todos los campos requeridos deben ser completados.';
        case '42501': // Insufficient privilege
          return 'No tienes permisos para realizar esta acción.';
        default:
          return 'Error de base de datos: ${error.message}';
      }
    }

    // Error genérico
    return 'Error desconocido: ${error.toString()}';
  }

  // Validar conexión a internet
  static Future<bool> hasInternetConnection() async {
    try {
      final client = Supabase.instance.client;
      await client.from('assets').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Formatear fechas para Supabase
  static String formatDateForSupabase(DateTime date) {
    return date.toIso8601String();
  }

  // Parsear fechas desde Supabase
  static DateTime? parseDateFromSupabase(dynamic dateString) {
    if (dateString == null) return null;
    try {
      return DateTime.parse(dateString.toString());
    } catch (e) {
      return null;
    }
  }

  // Validar UUID
  static bool isValidUuid(String? uuid) {
    if (uuid == null) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(uuid);
  }

  // Limpiar datos antes de enviar a Supabase
  static Map<String, dynamic> sanitizeData(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};

    for (final entry in data.entries) {
      if (entry.value != null) {
        if (entry.value is String && (entry.value as String).isNotEmpty) {
          cleaned[entry.key] = entry.value;
        } else if (entry.value is! String) {
          cleaned[entry.key] = entry.value;
        }
      }
    }

    return cleaned;
  }

  // Generar asset tag único
  static String generateAssetTag(String prefix) {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
    return '$prefix-$timestamp';
  }

  // Validar email
  static bool isValidEmail(String email) {
    return RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(email);
  }

  // Formatear moneda
  static String formatCurrency(double? amount, {String symbol = '\$'}) {
    if (amount == null) return 'N/A';
    return '$symbol${amount.toStringAsFixed(2)}';
  }

  // Formatear estado para mostrar
  static String formatStatus(String? status) {
    if (status == null) return 'Sin estado';
    switch (status.toLowerCase()) {
      case 'active':
        return 'Activo';
      case 'inactive':
        return 'Inactivo';
      case 'maintenance':
        return 'En mantenimiento';
      case 'disposed':
        return 'Dado de baja';
      case 'pending':
        return 'Pendiente';
      case 'in_progress':
        return 'En progreso';
      case 'completed':
        return 'Completado';
      case 'cancelled':
        return 'Cancelado';
      default:
        return status;
    }
  }

  // Obtener color para estado
  static String getStatusColor(String? status) {
    if (status == null) return '#6B8E3D';
    switch (status.toLowerCase()) {
      case 'active':
      case 'completed':
        return '#6B8E3D'; // Verde
      case 'pending':
      case 'in_progress':
        return '#F59E0B'; // Amarillo
      case 'maintenance':
        return '#EF4444'; // Rojo
      case 'inactive':
      case 'cancelled':
      case 'disposed':
        return '#6B7280'; // Gris
      default:
        return '#2B5F8C'; // Azul por defecto
    }
  }

  // Retry logic para operaciones críticas
  static Future<T> retryOperation<T>(
      Future<T> Function() operation, {
        int maxRetries = 3,
        Duration delay = const Duration(seconds: 1),
      }) async {
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        return await operation();
      } catch (e) {
        if (attempt == maxRetries) {
          rethrow;
        }
        await Future.delayed(delay * attempt);
      }
    }
    throw Exception('Max retries reached');
  }

  // Log de errores para debugging
  static void logError(String operation, dynamic error) {
    final timestamp = DateTime.now().toIso8601String();
    if (kDebugMode) {
      print('[$timestamp] ERROR en $operation: $error');
    }
  }

  // Verificar si el usuario tiene permisos
  static bool hasPermission(String permission) {
    // Por ahora retorna true, pero aquí podrías implementar
    // lógica de permisos basada en roles
    return true;
  }
}