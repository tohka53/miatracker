import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

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
      await _supabase.auth.resetPasswordForEmail(email);
    } on AuthException catch (e) {
      throw AuthException(e.message);
    } catch (e) {
      throw Exception('Error al restablecer contraseña: $e');
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
}