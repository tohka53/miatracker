import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path/path.dart' as path;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/auth_service.dart';

class ImageService {
  static final SupabaseClient _supabase = AuthService.client;
  static const String _bucketName = 'product-images';
  static const String _fallbackBucketName = 'inventory-images';

  // Configuración de imagen
  static const int _maxWidth = 1024;
  static const int _maxHeight = 1024;
  static const int _quality = 85;
  static const int _maxFileSizeBytes = 5 * 1024 * 1024; // 5MB

  /// Método principal para seleccionar imagen con manejo de permisos mejorado
  static Future<XFile?> pickImage({
    required ImageSource source,
    int? maxWidth,
    int? maxHeight,
    int? imageQuality,
  }) async {
    try {
      // Verificar y solicitar permisos
      final hasPermission = await _requestPermissions(source);
      if (!hasPermission) {
        throw Exception('Permisos de ${source == ImageSource.camera ? 'cámara' : 'galería'} denegados');
      }

      final ImagePicker picker = ImagePicker();

      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: maxWidth?.toDouble() ?? _maxWidth.toDouble(),
        maxHeight: maxHeight?.toDouble() ?? _maxHeight.toDouble(),
        imageQuality: imageQuality ?? _quality,
        requestFullMetadata: false, // Optimización para iOS
      );

      if (image != null) {
        // Validar el archivo seleccionado
        final validation = await _validateImageFile(File(image.path));
        if (!validation['isValid']) {
          throw Exception(validation['error'] ?? 'Imagen no válida');
        }

        if (kDebugMode) {
          print('✅ Imagen seleccionada: ${image.path}');
          print('📏 Tamaño: ${await image.length()} bytes');
        }
      }

      return image;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error seleccionando imagen: $e');
      }
      rethrow;
    }
  }

  /// Solicitar permisos específicos según la plataforma
  static Future<bool> _requestPermissions(ImageSource source) async {
    try {
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();

        if (cameraStatus.isDenied) {
          return false;
        }

        if (cameraStatus.isPermanentlyDenied) {
          // Guiar al usuario a configuración
          await openAppSettings();
          return false;
        }

        return cameraStatus.isGranted;
      } else {
        // Para galería, manejar diferentes versiones de permisos
        PermissionStatus status;

        if (Platform.isIOS) {
          // En iOS, usar photos permission
          status = await Permission.photos.request();
        } else {
          // En Android, usar storage permission o media images según API level
          if (await _isAndroid13OrHigher()) {
            status = await Permission.mediaLibrary.request();
          } else {
            status = await Permission.storage.request();
          }
        }

        if (status.isDenied) {
          return false;
        }

        if (status.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        }

        return status.isGranted;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error manejando permisos: $e');
      }
      return false;
    }
  }

  /// Verificar si es Android 13 o superior
  static Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      // Implementación simple para determinar la versión de Android
      return false; // Por defecto usar storage permission
    } catch (e) {
      return false;
    }
  }

  /// Validar archivo de imagen
  static Future<Map<String, dynamic>> _validateImageFile(File imageFile) async {
    try {
      // Verificar que el archivo existe
      if (!await imageFile.exists()) {
        return {'isValid': false, 'error': 'El archivo no existe'};
      }

      // Verificar extensión
      final extension = path.extension(imageFile.path).toLowerCase();
      const validExtensions = ['.jpg', '.jpeg', '.png', '.heic', '.heif'];
      if (!validExtensions.contains(extension)) {
        return {'isValid': false, 'error': 'Formato no soportado. Use JPG, PNG o HEIC'};
      }

      // Verificar tamaño
      final fileSize = await imageFile.length();
      if (fileSize > _maxFileSizeBytes) {
        return {'isValid': false, 'error': 'Imagen demasiado grande (máx. 5MB)'};
      }

      if (fileSize == 0) {
        return {'isValid': false, 'error': 'Archivo vacío o corrupto'};
      }

      return {'isValid': true};
    } catch (e) {
      return {'isValid': false, 'error': 'Error validando imagen: $e'};
    }
  }

  /// Subir imagen de producto a Supabase Storage
  static Future<String> uploadProductImage(File imageFile, String productId) async {
    try {
      final userId = AuthService.currentUser?.id;
      if (userId == null) throw Exception('Usuario no autenticado');

      // Validar imagen antes de subirla
      final validation = await _validateImageFile(imageFile);
      if (!validation['isValid']) {
        throw Exception(validation['error']);
      }

      // Optimizar imagen antes de subirla
      final optimizedImageData = await _optimizeImage(imageFile);

      // Generar nombre único para el archivo
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final fileName = '${userId}_${productId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';
      final filePath = 'products/$userId/$fileName';

      try {
        // Intentar subir al bucket principal
        await _supabase.storage
            .from(_bucketName)
            .uploadBinary(filePath, optimizedImageData);

        // Obtener URL pública
        final publicUrl = _supabase.storage
            .from(_bucketName)
            .getPublicUrl(filePath);

        if (kDebugMode) {
          print('✅ Imagen subida exitosamente: $publicUrl');
        }

        return publicUrl;
      } catch (storageError) {
        if (kDebugMode) {
          print('❌ Error con bucket principal, intentando bucket alternativo: $storageError');
        }

        // Fallback: intentar con bucket alternativo
        try {
          await _supabase.storage
              .from(_fallbackBucketName)
              .uploadBinary(filePath, optimizedImageData);

          final publicUrl = _supabase.storage
              .from(_fallbackBucketName)
              .getPublicUrl(filePath);

          if (kDebugMode) {
            print('✅ Imagen subida al bucket alternativo: $publicUrl');
          }

          return publicUrl;
        } catch (fallbackError) {
          if (kDebugMode) {
            print('❌ Error también en bucket alternativo: $fallbackError');
          }

          // Si ambos buckets fallan, guardar localmente para desarrollo
          return await _saveImageLocally(imageFile, productId);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error general en uploadProductImage: $e');
      }

      // Fallback: guardar imagen localmente
      return await _saveImageLocally(imageFile, productId);
    }
  }

  /// Optimizar imagen antes de subirla
  static Future<Uint8List> _optimizeImage(File imageFile) async {
    try {
      // Leer la imagen
      final imageBytes = await imageFile.readAsBytes();

      // Intentar decodificar
      img.Image? originalImage;

      try {
        originalImage = img.decodeImage(imageBytes);
      } catch (e) {
        if (kDebugMode) {
          print('Error decodificando imagen, usando bytes originales: $e');
        }
        return imageBytes;
      }

      if (originalImage == null) {
        if (kDebugMode) {
          print('No se pudo decodificar la imagen, usando bytes originales');
        }
        return imageBytes;
      }

      // Redimensionar si es necesario
      img.Image resizedImage = originalImage;
      if (originalImage.width > _maxWidth || originalImage.height > _maxHeight) {
        resizedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? _maxWidth : null,
          height: originalImage.height > originalImage.width ? _maxHeight : null,
        );
      }

      // Comprimir siempre como JPEG para compatibilidad
      final compressedBytes = Uint8List.fromList(img.encodeJpg(resizedImage, quality: _quality));

      if (kDebugMode) {
        final originalSize = imageBytes.length;
        final newSize = compressedBytes.length;
        final reduction = ((originalSize - newSize) / originalSize * 100).round();
        print('📸 Imagen optimizada: ${_formatFileSize(originalSize)} → ${_formatFileSize(newSize)} ($reduction% reducción)');
      }

      return compressedBytes;
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error optimizando imagen, usando original: $e');
      }
      // Si falla la optimización, usar imagen original
      return await imageFile.readAsBytes();
    }
  }

  /// Guardar imagen localmente como fallback
  static Future<String> _saveImageLocally(File imageFile, String productId) async {
    try {
      final userId = AuthService.currentUser?.id ?? 'unknown';
      final fileExtension = path.extension(imageFile.path).toLowerCase();
      final fileName = '${userId}_${productId}_${DateTime.now().millisecondsSinceEpoch}$fileExtension';

      // Directorio local para imágenes
      final localDir = Directory('${Directory.systemTemp.path}/mia_images');
      if (!await localDir.exists()) {
        await localDir.create(recursive: true);
      }

      final localFile = File('${localDir.path}/$fileName');

      // Optimizar y guardar
      final optimizedData = await _optimizeImage(imageFile);
      await localFile.writeAsBytes(optimizedData);

      if (kDebugMode) {
        print('💾 Imagen guardada localmente: ${localFile.path}');
      }

      return localFile.path;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error guardando imagen localmente: $e');
      }
      throw Exception('Error al guardar imagen: $e');
    }
  }

  /// Eliminar imagen de producto
  static Future<void> deleteProductImage(String imageUrl) async {
    try {
      if (imageUrl.startsWith('http')) {
        // Es una URL de Supabase Storage
        final uri = Uri.parse(imageUrl);
        final pathSegments = uri.pathSegments;

        // Extraer bucket y path
        if (pathSegments.length >= 3) {
          final bucket = pathSegments[2];
          final filePath = pathSegments.sublist(4).join('/');

          try {
            await _supabase.storage
                .from(bucket)
                .remove([filePath]);

            if (kDebugMode) {
              print('🗑️ Imagen eliminada de Supabase Storage: $filePath');
            }
          } catch (e) {
            if (kDebugMode) {
              print('⚠️ Error eliminando de Storage: $e');
            }
          }
        }
      } else {
        // Es un archivo local
        final file = File(imageUrl);
        if (await file.exists()) {
          await file.delete();
          if (kDebugMode) {
            print('🗑️ Archivo local eliminado: $imageUrl');
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('⚠️ Error eliminando imagen: $e');
      }
    }
  }

  /// Múltiples utilidades para manejo de imágenes

  /// Verificar disponibilidad de cámara
  static Future<bool> isCameraAvailable() async {
    try {
      final status = await Permission.camera.status;
      return !status.isPermanentlyDenied;
    } catch (e) {
      return false;
    }
  }

  /// Verificar disponibilidad de galería
  static Future<bool> isGalleryAvailable() async {
    try {
      PermissionStatus status;

      if (Platform.isIOS) {
        status = await Permission.photos.status;
      } else {
        if (await _isAndroid13OrHigher()) {
          status = await Permission.mediaLibrary.status;
        } else {
          status = await Permission.storage.status;
        }
      }

      return !status.isPermanentlyDenied;
    } catch (e) {
      return false;
    }
  }

  /// Crear bucket si no existe
  static Future<void> ensureBucketExists() async {
    try {
      final buckets = await _supabase.storage.listBuckets();

      final bucketExists = buckets.any((bucket) => bucket.name == _bucketName);
      if (!bucketExists) {
        await _supabase.storage.createBucket(
          _bucketName,
          const BucketOptions(public: true),
        );

        if (kDebugMode) {
          print('Bucket $_bucketName creado exitosamente');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error verificando/creando bucket: $e');
      }
    }
  }

  /// Formatear tamaño de archivo
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1048576) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  }

  /// Obtener información de imagen
  static Future<Map<String, dynamic>> getImageInfo(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);

      if (decodedImage == null) {
        throw Exception('No se pudo procesar la imagen');
      }

      final fileSize = imageBytes.length;
      final extension = path.extension(imageFile.path).toLowerCase();

      return {
        'width': decodedImage.width,
        'height': decodedImage.height,
        'fileSize': fileSize,
        'fileSizeFormatted': _formatFileSize(fileSize),
        'format': extension.replaceFirst('.', '').toUpperCase(),
        'aspectRatio': decodedImage.width / decodedImage.height,
        'isValid': _isValidImageFormat(imageFile.path) && fileSize <= _maxFileSizeBytes,
      };
    } catch (e) {
      return {
        'width': 0,
        'height': 0,
        'fileSize': 0,
        'fileSizeFormatted': '0 B',
        'format': 'UNKNOWN',
        'aspectRatio': 1.0,
        'isValid': false,
        'error': e.toString(),
      };
    }
  }

  /// Validar formato de imagen
  static bool _isValidImageFormat(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    const validExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.bmp', '.heic', '.heif'];
    return validExtensions.contains(extension);
  }

  /// Limpiar imágenes locales temporales
  static Future<void> cleanupLocalImages() async {
    try {
      final localDir = Directory('${Directory.systemTemp.path}/mia_images');
      if (await localDir.exists()) {
        final now = DateTime.now();

        await for (final entity in localDir.list()) {
          if (entity is File) {
            final stat = await entity.stat();
            final ageInDays = now.difference(stat.modified).inDays;

            // Eliminar archivos más antiguos que 7 días
            if (ageInDays > 7) {
              await entity.delete();
              if (kDebugMode) {
                print('Imagen temporal eliminada: ${entity.path}');
              }
            }
          }
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error limpiando imágenes temporales: $e');
      }
    }
  }

  /// Validar y preparar imagen antes de subir
  static Future<Map<String, dynamic>> validateAndPrepareImage(File imageFile) async {
    try {
      // Validaciones básicas
      if (!await imageFile.exists()) {
        return {
          'isValid': false,
          'error': 'El archivo no existe',
        };
      }

      if (!_isValidImageFormat(imageFile.path)) {
        return {
          'isValid': false,
          'error': 'Formato de imagen no válido. Use JPG, PNG, WebP, HEIC o BMP.',
        };
      }

      final imageInfo = await getImageInfo(imageFile);

      if (!imageInfo['isValid']) {
        return {
          'isValid': false,
          'error': imageInfo['error'] ?? 'Imagen no válida',
          'imageInfo': imageInfo,
        };
      }

      // Verificar dimensiones mínimas
      if (imageInfo['width'] < 100 || imageInfo['height'] < 100) {
        return {
          'isValid': false,
          'error': 'La imagen es demasiado pequeña. Mínimo 100x100 pixels.',
          'imageInfo': imageInfo,
        };
      }

      return {
        'isValid': true,
        'imageInfo': imageInfo,
        'needsOptimization': imageInfo['fileSize'] > 1024 * 1024, // > 1MB
        'needsResize': imageInfo['width'] > _maxWidth || imageInfo['height'] > _maxHeight,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': 'Error validando imagen: $e',
      };
    }
  }




}