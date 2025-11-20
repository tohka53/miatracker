// lib/widgets/reject_restock_dialog.dart
// MODAL DE RECHAZO CON SELECTOR DE PROVEEDOR (IDÉNTICO A APROBACIÓN)

import 'package:flutter/material.dart';
import '../widgets/supplier_selection_dialog.dart'; // ✅ IMPORT DEL SELECTOR

class RejectRestockDialog extends StatefulWidget {
  final int requestId;
  final String productName;
  final int? currentSupplierId;
  final Function(int requestId, String reason, int? supplierId) onReject;

  const RejectRestockDialog({
    Key? key,
    required this.requestId,
    required this.productName,
    this.currentSupplierId,
    required this.onReject,
  }) : super(key: key);

  @override
  State<RejectRestockDialog> createState() => _RejectRestockDialogState();
}

class _RejectRestockDialogState extends State<RejectRestockDialog> {
  final _reasonController = TextEditingController();
  Map<String, dynamic>? selectedSupplier; // ✅ IGUAL QUE EN APROBACIÓN
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Si ya tiene proveedor asignado, mostrarlo (opcional)
    // Esto requeriría cargar los datos del proveedor actual
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _handleReject() {
    // Validar razón
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa la razón del rechazo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar proveedor (CRÍTICO)
    if (selectedSupplier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un proveedor para continuar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    widget.onReject(
      widget.requestId,
      _reasonController.text.trim(),
      selectedSupplier!['id'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.cancel, color: Colors.red, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rechazar Solicitud',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¿Estás seguro de rechazar esta solicitud?',
                          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // PRODUCTO INFO
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.productName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // ✅ SELECTOR DE PROVEEDOR (IDÉNTICO A APROBACIÓN)
              Text(
                'Proveedor *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),

              Card(
                elevation: selectedSupplier == null ? 0 : 2,
                color: selectedSupplier == null
                    ? Colors.red.withOpacity(0.05)
                    : Colors.green.withOpacity(0.05),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: selectedSupplier == null
                        ? Colors.red.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: ListTile(
                  leading: Icon(
                    selectedSupplier != null ? Icons.business : Icons.business_outlined,
                    color: selectedSupplier != null ? const Color(0xFF6B8E3D) : Colors.red,
                    size: 28,
                  ),
                  title: Text(
                    selectedSupplier != null
                        ? selectedSupplier!['name']
                        : 'Seleccionar Proveedor',
                    style: TextStyle(
                      fontWeight:
                      selectedSupplier != null ? FontWeight.bold : FontWeight.normal,
                      color: selectedSupplier == null ? Colors.red : null,
                    ),
                  ),
                  subtitle: selectedSupplier != null && selectedSupplier!['email'] != null
                      ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.email_outlined,
                              size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              selectedSupplier!['email'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      if (selectedSupplier!['phone'] != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.phone_outlined,
                                size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              selectedSupplier!['phone'],
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ],
                  )
                      : const Text(
                    'Requerido para enviar notificación',
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: selectedSupplier != null
                      ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () => setState(() => selectedSupplier = null),
                    tooltip: 'Limpiar selección',
                  )
                      : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                  onTap: () async {
                    // ✅ ABRIR SELECTOR (IGUAL QUE EN APROBACIÓN)
                    final supplier = await showSupplierSelectionDialog(
                      context,
                      currentSupplierId: selectedSupplier?['id'],
                      productName: widget.productName,
                    );
                    if (supplier != null) {
                      setState(() => selectedSupplier = supplier);
                    }
                  },
                ),
              ),

              // ✅ WARNING SI NO HAY PROVEEDOR (IGUAL QUE EN APROBACIÓN)
              if (selectedSupplier == null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Debes seleccionar un proveedor para continuar',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.red[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 16),

              // RAZÓN DEL RECHAZO
              const Text(
                'Razón del rechazo *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              TextField(
                controller: _reasonController,
                maxLines: 3,
                enabled: !_isSubmitting,
                decoration: const InputDecoration(
                  labelText: 'Razón del rechazo (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'Explica por qué se rechaza',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),

              const SizedBox(height: 24),

              // BOTONES
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting || selectedSupplier == null
                        ? null
                        : _handleReject,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text('Rechazar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}