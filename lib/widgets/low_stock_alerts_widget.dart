// lib/widgets/low_stock_alerts_widget.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/low_stock_alert_service.dart';

/// Widget que muestra alertas de stock bajo en el home screen
class LowStockAlertsWidget extends StatelessWidget {
  final VoidCallback? onViewAll;

  const LowStockAlertsWidget({
    super.key,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: LowStockAlertService.getActiveAlerts(),
      builder: (context, snapshot) {
        // Si está cargando
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.all(16),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // Si hay error
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final alerts = snapshot.data ?? [];

        // Si no hay alertas, no mostrar nada
        if (alerts.isEmpty) {
          return const SizedBox.shrink();
        }

        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Colors.orange.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '⚠️ Low Stock Alerts',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade900,
                            ),
                          ),
                          Text(
                            '${alerts.length} product${alerts.length > 1 ? 's' : ''} need${alerts.length > 1 ? '' : 's'} restock',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange.shade700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onViewAll != null)
                      TextButton(
                        onPressed: onViewAll,
                        child: Text(
                          'View all',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Lista de alertas (mostrar máximo 3)
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: alerts.length > 3 ? 3 : alerts.length,
                itemBuilder: (context, index) {
                  final alert = alerts[index];
                  return _buildAlertItem(context, alert);
                },
              ),

              // Ver más si hay más de 3
              if (alerts.length > 3 && onViewAll != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: onViewAll,
                      icon: const Icon(Icons.expand_more),
                      label: Text('View ${alerts.length - 3} more alert${alerts.length - 3 > 1 ? 's' : ''}'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange.shade700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAlertItem(BuildContext context, Map<String, dynamic> alert) {
    final productName = alert['producto_nombre'] ?? 'Producto';
    final currentStock = alert['cantidad_actual'] ?? 0;
    final alertThreshold = alert['alerta_cantidad'] ?? 0;
    final fechaAlerta = alert['fecha_alerta'];

    // Calcular hace cuánto tiempo fue la alerta
    String timeAgo = 'Now';
    if (fechaAlerta != null) {
      try {
        final date = DateTime.parse(fechaAlerta);
        final difference = DateTime.now().difference(date);
        if (difference.inMinutes < 60) {
          timeAgo = '${difference.inMinutes} min ago';
        } else if (difference.inHours < 24) {
          timeAgo = '${difference.inHours}h ago';
        } else {
          timeAgo = DateFormat('MM/dd/yyyy').format(date);
        }
      } catch (e) {
        // Si hay error parseando la fecha, dejar el default
      }
    }

    final isOutOfStock = currentStock == 0;
    final stockColor = isOutOfStock ? Colors.red : Colors.orange;
    final stockIcon = isOutOfStock ? Icons.error : Icons.warning_amber_rounded;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          backgroundColor: stockColor.withOpacity(0.1),
          child: Icon(
            stockIcon,
            color: stockColor,
            size: 24,
          ),
        ),
        title: Text(
          productName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 14,
                  color: stockColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'Stock: $currentStock / $alertThreshold unidades',
                  style: TextStyle(
                    fontSize: 12,
                    color: stockColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              timeAgo,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: stockColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            isOutOfStock ? 'OUT' : 'LOW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: stockColor,
            ),
          ),
        ),
        onTap: () {
          _showAlertDetails(context, alert);
        },
      ),
    );
  }

  void _showAlertDetails(BuildContext context, Map<String, dynamic> alert) {
    final productName = alert['producto_nombre'] ?? 'Producto';
    final currentStock = alert['cantidad_actual'] ?? 0;
    final alertThreshold = alert['alerta_cantidad'] ?? 0;
    final alertId = alert['id'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              currentStock == 0 ? Icons.error : Icons.warning_amber_rounded,
              color: currentStock == 0 ? Colors.red : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Alert Details',
                style: TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              productName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildDetailRow(
              'Current stock:',
              '$currentStock units',
              currentStock == 0 ? Colors.red : Colors.orange,
            ),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Alert threshold:',
              '$alertThreshold units',
              Colors.grey.shade700,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: Colors.blue.shade700,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Recommended actions:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Create restock request\n'
                        '• Check pending orders\n'
                        '• Contact supplier',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.amber.shade900,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This alert will remain visible until the product is restocked',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade900,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () async {
              final resolved = await LowStockAlertService.resolveAlert(alertId);
              if (context.mounted) {
                Navigator.pop(context);
                if (resolved) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Alert marked as resolved'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Resolve'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}