import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class ProfileService {
  static final SupabaseClient _supabase = AuthService.client;

  // Asegurar que el perfil del usuario existe
  static Future<void> ensureProfileExists() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return;

      // Verificar si el perfil ya existe
      final existingProfile = await _supabase
          .from('profiles')
          .select('id')
          .eq('id', user.id)
          .maybeSingle();

      if (existingProfile == null) {
        // Crear perfil si no existe
        await _supabase.from('profiles').insert({
          'id': user.id,
          'full_name': user.userMetadata?['full_name'] ?? 'Usuario',
          'username': user.userMetadata?['username'],
          'company': user.userMetadata?['company'],
          'avatar_url': user.userMetadata?['avatar_url'],
          'updated_at': DateTime.now().toIso8601String(),
        });

        if (kDebugMode) {
          print('Perfil creado para usuario: ${user.email}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error al asegurar perfil: $e');
      }
      // No lanzar excepción para no bloquear la app
    }
  }

  // Obtener el perfil completo del usuario
  static Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return null;

      final profile = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return profile;
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener perfil: $e');
      }
      return null;
    }
  }

  // Actualizar perfil del usuario
  static Future<void> updateUserProfile(Map<String, dynamic> profileData) async {
    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      await _supabase
          .from('profiles')
          .update({
        ...profileData,
        'updated_at': DateTime.now().toIso8601String(),
      })
          .eq('id', user.id);

      if (kDebugMode) {
        print('Perfil actualizado exitosamente');
      }
    } catch (e) {
      throw Exception('Error al actualizar perfil: $e');
    }
  }

  // Obtener nombre para mostrar del usuario
  static Future<String> getUserDisplayName() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return 'Usuario';

      final profile = await getUserProfile();

      if (profile != null) {
        // Prioridad: full_name > username > email > "Usuario"
        return profile['full_name']?.toString().isNotEmpty == true
            ? profile['full_name']
            : profile['username']?.toString().isNotEmpty == true
            ? profile['username']
            : user.email?.split('@').first ?? 'Usuario';
      }

      // Si no hay perfil, usar metadata del auth
      return user.userMetadata?['full_name']?.toString().isNotEmpty == true
          ? user.userMetadata!['full_name']
          : user.userMetadata?['username']?.toString().isNotEmpty == true
          ? user.userMetadata!['username']
          : user.email?.split('@').first ?? 'Usuario';
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener nombre de usuario: $e');
      }
      return 'Usuario';
    }
  }

  // Obtener avatar URL del usuario
  static Future<String?> getUserAvatarUrl() async {
    try {
      final profile = await getUserProfile();
      return profile?['avatar_url'];
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener avatar: $e');
      }
      return null;
    }
  }

  // Actualizar avatar del usuario
  static Future<void> updateUserAvatar(String avatarUrl) async {
    try {
      await updateUserProfile({'avatar_url': avatarUrl});
    } catch (e) {
      throw Exception('Error al actualizar avatar: $e');
    }
  }

  // Obtener información de la empresa del usuario
  static Future<String?> getUserCompany() async {
    try {
      final profile = await getUserProfile();
      return profile?['company'];
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener empresa: $e');
      }
      return null;
    }
  }

  // Actualizar información de la empresa
  static Future<void> updateUserCompany(String company) async {
    try {
      await updateUserProfile({'company': company});
    } catch (e) {
      throw Exception('Error al actualizar empresa: $e');
    }
  }

  // Obtener rol del usuario
  static Future<String> getUserRole() async {
    try {
      final profile = await getUserProfile();
      return profile?['role'] ?? 'user';
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener rol: $e');
      }
      return 'user';
    }
  }

  // Verificar si el usuario es administrador
  static Future<bool> isUserAdmin() async {
    try {
      final role = await getUserRole();
      return role == 'admin';
    } catch (e) {
      return false;
    }
  }

  // Eliminar perfil del usuario (soft delete)
  static Future<void> deleteUserProfile() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) throw Exception('Usuario no autenticado');

      // No eliminamos el perfil completamente, solo marcamos como inactivo
      await updateUserProfile({
        'role': 'inactive',
        'updated_at': DateTime.now().toIso8601String(),
      });

      if (kDebugMode) {
        print('Perfil marcado como inactivo');
      }
    } catch (e) {
      throw Exception('Error al eliminar perfil: $e');
    }
  }

  // Obtener estadísticas del perfil
  static Future<Map<String, dynamic>> getProfileStats() async {
    try {
      final user = AuthService.currentUser;
      if (user == null) return {};

      final profile = await getUserProfile();
      if (profile == null) return {};

      // Calcular días desde la creación del perfil
      final createdAt = DateTime.tryParse(profile['updated_at'] ?? '');
      final daysSinceCreation = createdAt != null
          ? DateTime.now().difference(createdAt).inDays
          : 0;

      return {
        'days_since_creation': daysSinceCreation,
        'has_avatar': profile['avatar_url'] != null,
        'has_company': profile['company'] != null && profile['company'].toString().isNotEmpty,
        'profile_completion': _calculateProfileCompletion(profile),
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error al obtener estadísticas del perfil: $e');
      }
      return {};
    }
  }

  // Calcular porcentaje de completitud del perfil
  static double _calculateProfileCompletion(Map<String, dynamic> profile) {
    double completion = 0.0;
    const fields = ['full_name', 'username', 'company', 'avatar_url', 'website'];

    for (final field in fields) {
      if (profile[field] != null && profile[field].toString().isNotEmpty) {
        completion += 20.0; // 20% por cada campo completado
      }
    }

    return completion;
  }

  // Stream para cambios en el perfil
  static Stream<Map<String, dynamic>?> getProfileStream() {
    final user = AuthService.currentUser;
    if (user == null) {
      return Stream.value(null);
    }

    return _supabase
        .from('profiles')
        .stream(primaryKey: ['id'])
        .map((List<Map<String, dynamic>> data) {
      final profile = data.where((item) => item['id'] == user.id).firstOrNull;
      return profile;
    });
  }

  // Validar datos del perfil antes de actualizar
  static Map<String, String> validateProfileData(Map<String, dynamic> data) {
    final errors = <String, String>{};

    // Validar nombre completo
    if (data['full_name'] != null && data['full_name'].toString().length < 2) {
      errors['full_name'] = 'El nombre debe tener al menos 2 caracteres';
    }

    // Validar username
    if (data['username'] != null) {
      final username = data['username'].toString();
      if (username.length < 3) {
        errors['username'] = 'El username debe tener al menos 3 caracteres';
      }
      if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
        errors['username'] = 'El username solo puede contener letras, números y guiones bajos';
      }
    }

    // Validar website
    if (data['website'] != null && data['website'].toString().isNotEmpty) {
      final website = data['website'].toString();
      if (!Uri.tryParse(website)!.hasAbsolutePath == true) {
        errors['website'] = 'La URL del website no es válida';
      }
    }

    return errors;
  }


}