// lib/screens/restock_approval_example.dart
// EJEMPLO DE PANTALLA PARA APROBAR SOLICITUDES DE RESTOCK
// VERSIÓN DEFINITIVA CORREGIDA Y COMPLETA

import 'package:flutter/material.dart';
import '../services/restock_service.dart';
import '../services/inventory_service.dart';
import '../widgets/supplier_selection_dialog.dart'; // ✅ Import correcto (sin duplicate)
import '../widgets/base_screen.dart';

class RestockApprovalExampleScreen extends StatefulWidget {
  const RestockApprovalExampleScreen({super.key});

  @override
  State<RestockApprovalExampleScreen> createState() =>
      _RestockApprovalExampleScreenState();
}

class _RestockApprovalExampleScreenState
    extends State<RestockApprovalExampleScreen> {
  bool _isLoading = false;

  /// Ejemplo de flujo completo para aprobar una solicitud
  Future<void> _approveRequestExample(int requestId) async {
    setState(() => _isLoading = true);

    try {
      // PASO 1: VALIDAR LA SOLICITUD
      final validation = await _validateRestockRequest(requestId);

      if (validation['valid'] != true) {
        _showSnackBar(validation['error'], isError: true);
        return;
      }

      // PASO 2: OBTENER O SELECCIONAR PROVEEDOR
      int? supplierId = validation['supplier_id'];

      if (supplierId == null) {
        // No tiene proveedor, mostrar selector
        final supplier = await showSupplierSelectionDialog(
          context,
          currentSupplierId: null,
          productName: validation['product_name'],
        );

        if (supplier == null) {
          _showSnackBar(
            'Debes asignar un proveedor para continuar',
            isError: true,
          );
          return;
        }

        supplierId = supplier['id'] as int;

        // Asignar proveedor al producto
        await InventoryService.assignSupplierToProduct(
          validation['product_id'],
          supplierId,
        );

        _showSnackBar('✅ Proveedor asignado al producto');
      }

      // PASO 3: APROBAR LA SOLICITUD
      await RestockService.approveRequest(
        requestId: requestId,
        supplierId: supplierId, // ✅ Ahora supplierId nunca es null
        internalNotes: 'Aprobado desde ejemplo',
        estimatedDeliveryDate: null,
      );

      _showSnackBar('✅ Solicitud aprobada exitosamente');
    } catch (e) {
      _showSnackBar('Error: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Validar solicitud antes de aprobar
  Future<Map<String, dynamic>> _validateRestockRequest(int requestId) async {
    try {
      final request = await RestockService.getRequestById(requestId);

      if (request == null) {
        return {
          'valid': false,
          'error': 'Solicitud no encontrada',
        };
      }

      if (request['status'] == 'approved') {
        return {
          'valid': false,
          'error': 'La solicitud ya está aprobada',
        };
      }

      // Obtener ID del producto
      final productId = request['id_inventario'] as int?;
      if (productId == null) {
        return {
          'valid': false,
          'error': 'Producto no encontrado en la solicitud',
        };
      }

      // Obtener datos del producto
      final product = await InventoryService.getProductById(productId);
      final supplierId = product?['id_supply_company'] as int?;

      return {
        'valid': true,
        'request': request,
        'product_id': productId,
        'product_name': request['nombre_producto'] ?? 'Producto',
        'supplier_id': supplierId, // null si no tiene proveedor
        'has_supplier': supplierId != null,
      };
    } catch (e) {
      return {
        'valid': false,
        'error': 'Error al validar: $e',
      };
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF6B8E3D),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      currentRoute: '/restock-approval-example',
      title: 'Ejemplo de Aprobación',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 80,
                color: Color(0xFF6B8E3D),
              ),
              const SizedBox(height: 24),
              const Text(
                'Flujo de Aprobación de Restock',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Este ejemplo demuestra cómo aprobar\nuna solicitud de restock con validación\ny asignación automática de proveedor',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _approveRequestExample(1), // ✅ Request ID de ejemplo
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.approval),
                label: const Text(
                  'Aprobar Solicitud de Ejemplo',
                  style: TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 0),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 8),
                        Text(
                          'Flujo de Aprobación',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildStepItem('1', 'Validar la solicitud'),
                    _buildStepItem('2', 'Verificar proveedor'),
                    _buildStepItem('3', 'Asignar si es necesario'),
                    _buildStepItem('4', 'Aprobar solicitud'),
                    _buildStepItem('5', 'Enviar email al proveedor'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF6B8E3D),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}