// lib/widgets/create_restock_request_dialog.dart
// DIÁLOGO PARA CREAR SOLICITUD DE RESTOCK DESDE INVENTARIO

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/restock_request_service.dart';
import '../services/restock_request_service.dart';
/// Muestra un diálogo para crear una solicitud de restock
///
/// [product]: Datos del producto (debe incluir id_inventario, nombre_producto, cantidad)
///
/// Retorna `true` si se creó exitosamente, `false` o `null` si se canceló
Future<bool?> showCreateRestockRequestDialog(
    BuildContext context, {
      required Map<String, dynamic> product,
    }) async {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => CreateRestockRequestDialog(product: product),
  );
}

class CreateRestockRequestDialog extends StatefulWidget {
  final Map<String, dynamic> product;

  const CreateRestockRequestDialog({
    Key? key,
    required this.product,
  }) : super(key: key);

  @override
  State<CreateRestockRequestDialog> createState() => _CreateRestockRequestDialogState();
}

class _CreateRestockRequestDialogState extends State<CreateRestockRequestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController();
  final _notesController = TextEditingController();

  String _selectedPriority = 'medium';
  bool _isCreating = false;
  bool _isValidating = true;
  Map<String, dynamic>? _validationResult;

  @override
  void initState() {
    super.initState();
    _validateBeforeShow();
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _validateBeforeShow() async {
    final result = await RestockRequestService.validateBeforeCreating(

      productId: widget.product['id_inventario'],
      requestedQuantity: 1, // Solo validar que existe
    );

    setState(() {
      _validationResult = result;
      _isValidating = false;
    });
  }

  Future<void> _createRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isCreating = true);

    try {
      final quantity = int.parse(_quantityController.text);

      final result = await RestockRequestService.createRestockRequest(
        productId: widget.product['id_inventario'],
        requestedQuantity: quantity,
        priority: _selectedPriority,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      if (result['success'] == true) {
        if (mounted) {
          _showSuccessSnackBar(
            result['message'] ?? 'Solicitud creada exitosamente',
          );

          // Si el producto no tiene proveedor, avisar
          if (result['has_supplier'] != true) {
            _showWarningDialog(
              'El producto no tiene proveedor asignado. '
                  'Un administrador deberá asignarlo antes de aprobar la solicitud.',
            );
          }

          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          _showErrorSnackBar(
            result['error'] ?? 'Error al crear solicitud',
          );
        }
        setState(() => _isCreating = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
      setState(() => _isCreating = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFF6B8E3D),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _showWarningDialog(String message) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            const SizedBox(width: 12),
            const Text('Aviso'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2B5F8C).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.add_shopping_cart,
              color: Color(0xFF2B5F8C),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Solicitar Restock',
              style: TextStyle(fontSize: 20),
            ),
          ),
        ],
      ),
      content: _isValidating
          ? const SizedBox(
        height: 100,
        child: Center(child: CircularProgressIndicator()),
      )
          : _validationResult?['valid'] != true
          ? _buildErrorContent()
          : _buildFormContent(),
      actions: _isValidating || _validationResult?['valid'] != true
          ? [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cerrar'),
        ),
      ]
          : [
        TextButton(
          onPressed: _isCreating
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _isCreating ? null : _createRequest,
          icon: _isCreating
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.send),
          label: Text(_isCreating ? 'Creando...' : 'Crear Solicitud'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6B8E3D),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorContent() {
    final error = _validationResult?['error'] ?? 'Error desconocido';
    final isWarning = _validationResult?['warning'] == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isWarning ? Icons.warning_amber_rounded : Icons.error_outline,
          size: 64,
          color: isWarning ? Colors.orange : Colors.red,
        ),
        const SizedBox(height: 16),
        Text(
          error,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildFormContent() {
    final productName = widget.product['nombre_producto'] ?? 'Producto';
    final currentStock = widget.product['cantidad'] ?? 0;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info del producto
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_2, size: 20, color: Color(0xFF2B5F8C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          productName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.inventory, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 8),
                      Text(
                        'Stock actual: $currentStock unidades',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Campo de cantidad
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Cantidad a solicitar *',
                hintText: 'Ej: 100',
                prefixIcon: Icon(Icons.numbers),
                border: OutlineInputBorder(),
                helperText: 'Cantidad de unidades que necesitas',
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Ingresa la cantidad';
                }
                final quantity = int.tryParse(value);
                if (quantity == null || quantity <= 0) {
                  return 'Debe ser un número mayor a 0';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Selector de prioridad
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prioridad',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildPriorityChip('Baja', 'low'),
                    _buildPriorityChip('Media', 'medium'),
                    _buildPriorityChip('Alta', 'high'),
                    _buildPriorityChip('Urgente', 'urgent'),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Notas opcionales
            TextFormField(
              controller: _notesController,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                hintText: 'Motivo de la solicitud, detalles adicionales...',
                prefixIcon: Icon(Icons.note_outlined),
                border: OutlineInputBorder(),
                helperText: 'Información adicional sobre la solicitud',
              ),
            ),

            const SizedBox(height: 12),

            // Info adicional
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.05),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 20, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'La solicitud será revisada por un administrador',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[900],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriorityChip(String label, String value) {
    final isSelected = _selectedPriority == value;
    final color = _getPriorityColor(value);

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedPriority = value);
        }
      },
      backgroundColor: color.withOpacity(0.1),
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      side: BorderSide(
        color: isSelected ? color : color.withOpacity(0.3),
        width: isSelected ? 2 : 1,
      ),
      labelStyle: TextStyle(
        color: color,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'low':
        return const Color(0xFF10B981);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'high':
        return const Color(0xFFEF4444);
      case 'urgent':
        return const Color(0xFFDC2626);
      default:
        return const Color(0xFFF59E0B);
    }
  }
}