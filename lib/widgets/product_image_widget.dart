import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget reutilizable para mostrar imágenes de productos
/// Maneja automáticamente URLs remotas y archivos locales
class ProductImageWidget extends StatelessWidget {
  final dynamic imageData;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const ProductImageWidget({
    super.key,
    required this.imageData,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Extraer URL de la imagen
    String? imageUrl = _extractImageUrl(imageData);

    if (imageUrl == null || imageUrl.trim().isEmpty) {
      return _buildDefaultErrorWidget();
    }

    // Si es URL remota
    if (imageUrl.startsWith('http')) {
      return _buildRemoteImage(imageUrl);
    }

    // Si es archivo local
    return _buildLocalImage(imageUrl);
  }

  /// Extrae la URL de diferentes formatos de datos
  String? _extractImageUrl(dynamic data) {
    if (data == null) return null;

    // Si es String directo
    if (data is String) {
      return data;
    }

    // Si es Map (JSONB de Supabase)
    if (data is Map) {
      return data['url'] ??
          data['public_url'] ??
          data['path'] ??
          data['imagen'] ??
          data['image_url'];
    }

    return null;
  }

  /// Construye imagen remota con CachedNetworkImage
  Widget _buildRemoteImage(String url) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) =>
        placeholder ?? _buildDefaultPlaceholder(),
        errorWidget: (context, url, error) {
          debugPrint('❌ Error cargando imagen remota: $url');
          debugPrint('❌ Error: $error');
          return errorWidget ?? _buildDefaultErrorWidget();
        },
      ),
    );
  }

  /// Construye imagen local desde archivo
  Widget _buildLocalImage(String path) {
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('❌ Error cargando imagen local: $path');
          debugPrint('❌ Error: $error');
          return errorWidget ?? _buildDefaultErrorWidget();
        },
      ),
    );
  }

  /// Placeholder por defecto mientras carga
  Widget _buildDefaultPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6B8E3D),
          strokeWidth: 2,
        ),
      ),
    );
  }

  /// Widget de error por defecto
  Widget _buildDefaultErrorWidget() {
    return Container(
      width: width,
      height: height,
      color: Colors.grey.shade200,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, size: 30, color: Colors.grey),
          SizedBox(height: 4),
          Text(
            'Sin imagen',
            style: TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}