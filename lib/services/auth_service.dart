import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  static final SupabaseClient _supabase = Supabase.instance.client;

  // Obtener el cliente de Supabase
  static SupabaseClient get client => _supabase;

  // Obtener usuario actual
  static User? get currentUser => _supabase.auth.currentUser;

  // Verificar si el usuario está autenticado
  static bool get isAuthenticated => currentUser != null;

  // Iniciar sesión con email y contraseña
  static Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Registrar nuevo usuario
  static Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error de registro: $e');
    }
  }

  // Cerrar sesión
  static Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  // Restablecer contraseña
  static Future<void> resetPassword(String email) async {
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: kIsWeb
            ? 'https://www.miatracker.com/app/#/reset-password'
            : 'io.supabase.miatracker://reset-password',
      );
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al restablecer contraseña: $e');
    }
  }

  // Actualizar contraseña (MÉTODO NECESARIO PARA RESET PASSWORD)
  static Future<UserResponse> updatePassword(String newPassword) async {
    try {
      if (!isAuthenticated) {
        throw Exception('Usuario no autenticado');
      }

      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        throw Exception('Error al actualizar la contraseña');
      }

      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al actualizar contraseña: $e');
    }
  }

  // Escuchar cambios de autenticación
  static Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  // Obtener información del perfil del usuario
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      if (!isAuthenticated) return null;

      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', currentUser!.id)
          .single();

      return response;
    } catch (e) {
      throw Exception('Error al obtener perfil: $e');
    }
  }

  // Actualizar perfil del usuario
  static Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      if (!isAuthenticated) throw Exception('Usuario no autenticado');

      await _supabase
          .from('profiles')
          .update(profileData)
          .eq('id', currentUser!.id);
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  // Reenviar email de confirmación
  static Future<void> resendEmailConfirmation(String email) async {
    try {
      await _supabase.auth.resend(
        type: OtpType.signup,
        email: email,
      );
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al reenviar email de confirmación: $e');
    }
  }

  // Verificar estado de la sesión actual
  static Future<Session?> getCurrentSession() async {
    try {
      final session = _supabase.auth.currentSession;
      return session;
    } catch (e) {
      return null;
    }
  }

  // Refrescar la sesión actual
  static Future<AuthResponse> refreshSession() async {
    try {
      final response = await _supabase.auth.refreshSession();
      return response;
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al refrescar sesión: $e');
    }
  }

  // Método para manejar deep links de reset de contraseña
  static Future<bool> handlePasswordResetLink(String link) async {
    try {
      final uri = Uri.parse(link);

      // Extraer parámetros del fragment o query
      String? accessToken;
      String? type;

      if (uri.fragment.isNotEmpty) {
        final fragmentParams = Uri.splitQueryString(uri.fragment);
        accessToken = fragmentParams['access_token'];
        type = fragmentParams['type'];
      } else if (uri.queryParameters.isNotEmpty) {
        accessToken = uri.queryParameters['access_token'];
        type = uri.queryParameters['type'];
      }

      if (accessToken != null && type == 'recovery') {
        try {
          // Usar el método correcto para Supabase Flutter 2.6.0+
          final response = await _supabase.auth.setSession(accessToken);
          return response.session != null;
        } catch (e) {
          // Método alternativo si el anterior falla
          try {
            await _supabase.auth.recoverSession(accessToken);
            return true;
          } catch (e2) {
            return false;
          }
        }
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // Validar si un enlace es válido para la app
  static bool isValidAppLink(String link) {
    try {
      final uri = Uri.parse(link);
      return uri.scheme == 'io.supabase.miatracker' ||
          uri.host.contains('supabase.co') ||
          uri.host.contains('miatracker.com');
    } catch (e) {
      return false;
    }
  }
}