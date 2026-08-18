// lib/widgets/product_card_with_restock.dart
// CARD DE PRODUCTO CON INDICADOR DE STOCK BAJO Y BOTÓN DE RESTOCK

import 'package:flutter/material.dart';
import '../widgets/create_restock_request_dialog.dart';

/// Widget reutilizable para mostrar un producto con indicador de stock
/// y botón para solicitar restock cuando el stock está bajo
class ProductCardWithRestock extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onRefresh;

  const ProductCardWithRestock({
    Key? key,
    required this.product,
    required this.onRefresh,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Obtener datos del producto
    final nombre = product['nombre_producto'] ?? 'Sin nombre';
    final cantidad = product['cantidad'] ?? 0;
    final alertaCantidad = product['alerta_cantidad'] ?? 5;
    final imagenUrl = product['image_url'] ?? product['imagen'];
    final precio = product['precio']?.toDouble() ?? 0.0;
    final ubicacion = product['lugar_fisico'] ?? 'Sin ubicación';

    // Determinar estado del stock
    final isOutOfStock = cantidad == 0;
    final isLowStock = cantidad > 0 && cantidad <= alertaCantidad;
    final isNormalStock = cantidad > alertaCantidad;

    // Colores según estado
    final statusColor = isOutOfStock
        ? Colors.red
        : isLowStock
        ? Colors.orange
        : const Color(0xFF6B8E3D);

    final statusText = isOutOfStock
        ? 'SIN STOCK'
        : isLowStock
        ? 'STOCK BAJO'
        : 'Stock Normal';

    final cardColor = isOutOfStock
        ? Colors.red.withOpacity(0.15)
        : isLowStock
        ? Colors.orange.withOpacity(0.1)
        : null;

    return Card(
      elevation: isOutOfStock || isLowStock ? 6 : 2,
      color: cardColor,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isOutOfStock || isLowStock
              ? statusColor
              : Colors.transparent,
          width: isOutOfStock || isLowStock ? 2 : 0,
        ),
      ),
      child: InkWell(
        onTap: () {
          // Navegar a detalle del producto (opcional)
          // Navigator.push(...);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER: Imagen y datos principales
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Imagen del producto
                  _buildProductImage(imagenUrl, statusColor),
                  const SizedBox(width: 16),

                  // Info principal
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre del producto
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B5F8C),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),

                        // Ubicación
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                ubicacion,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // Precio
                        if (precio > 0)
                          Text(
                            '\$${precio.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B8E3D),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // STOCK STATUS BANNER
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: statusColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isOutOfStock
                          ? Icons.cancel
                          : isLowStock
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle,
                      color: statusColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Cantidad: $cantidad / Alerta: $alertaCantidad',
                            style: TextStyle(
                              color: statusColor.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // BOTÓN DE RESTOCK (solo si stock bajo o sin stock)
              if (isOutOfStock || isLowStock) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _handleRestockRequest(context),
                    icon: const Icon(Icons.add_shopping_cart),
                    label: Text(
                      isOutOfStock
                          ? 'Solicitar Restock Urgente'
                          : 'Solicitar Restock',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isOutOfStock
                          ? Colors.red
                          : const Color(0xFF6B8E3D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductImage(String? imageUrl, Color borderColor) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: borderColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: imageUrl != null && imageUrl.isNotEmpty
            ? Image.network(
          imageUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage();
          },
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                    : null,
                strokeWidth: 2,
              ),
            );
          },
        )
            : _buildPlaceholderImage(),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return Icon(
      Icons.inventory_2_outlined,
      size: 40,
      color: Colors.grey[400],
    );
  }

  void _handleRestockRequest(BuildContext context) async {
    final cantidad = product['cantidad'] ?? 0;
    final isUrgent = cantidad == 0;

    final result = await showCreateRestockRequestDialog(
      context,
      product: product,
    );

    if (result == true) {
      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isUrgent
                      ? 'Solicitud urgente creada exitosamente'
                      : 'Solicitud de restock creada',
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF6B8E3D),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'VER',
            textColor: Colors.white,
            onPressed: () {
              // Navegar a pantalla de solicitudes (opcional)
              // Navigator.pushNamed(context, '/restock-requests');
            },
          ),
        ),
      );

      // Refrescar la lista
      onRefresh();
    }
  }
}