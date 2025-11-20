// lib/widgets/supplier_selection_dialog.dart
// WIDGET MEJORADO PARA SELECCIONAR PROVEEDOR

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/inventory_service.dart';

class SupplierSelectionDialog extends StatefulWidget {
  final int? currentSupplierId;
  final String? productName;

  const SupplierSelectionDialog({
    Key? key,
    this.currentSupplierId,
    this.productName,
  }) : super(key: key);

  @override
  State<SupplierSelectionDialog> createState() =>
      _SupplierSelectionDialogState();
}

class _SupplierSelectionDialogState extends State<SupplierSelectionDialog> {
  List<Map<String, dynamic>> _suppliers = [];
  bool _isLoading = true;
  String? _errorMessage;
  int? _selectedSupplierId;

  @override
  void initState() {
    super.initState();
    _selectedSupplierId = widget.currentSupplierId;
    _loadSuppliers();
  }

  Future<void> _loadSuppliers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final companyId = await InventoryService.getCurrentCompanyId();
      if (companyId == null) {
        throw Exception('No perteneces a ninguna compañía');
      }

      final supabase = AuthService.client;
      final response = await supabase
          .from('supply_company')
          .select('*')
          .eq('id_company', companyId)
          .eq('status', 1)
          .order('name');

      setState(() {
        _suppliers = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
      });

      if (_suppliers.isEmpty) {
        setState(() {
          _errorMessage = 'No hay proveedores disponibles.\nPor favor crea uno primero.';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error al cargar proveedores: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // HEADER
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Color(0xFF6B8E3D),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Icon(Icons.business, color: Colors.white, size: 28),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Seleccionar Proveedor',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (widget.productName != null) ...[
                          SizedBox(height: 4),
                          Text(
                            'Para: ${widget.productName}',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // CONTENT
            Expanded(
              child: _buildContent(),
            ),

            // FOOTER
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.all(16),
                        side: BorderSide(color: Colors.grey),
                      ),
                      child: Text('Cancelar'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _selectedSupplierId == null
                          ? null
                          : () {
                        final selectedSupplier = _suppliers.firstWhere(
                              (s) => s['id'] == _selectedSupplierId,
                        );
                        Navigator.pop(context, selectedSupplier);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF6B8E3D),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.all(16),
                      ),
                      child: Text('Confirmar'),
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

  Widget _buildContent() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF6B8E3D)),
            SizedBox(height: 16),
            Text(
              'Cargando proveedores...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              SizedBox(height: 16),
              Text(
                'Error',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadSuppliers,
                icon: Icon(Icons.refresh),
                label: Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_suppliers.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No hay proveedores',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Debes crear al menos un proveedor\nantes de continuar',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Navegar a pantalla de crear proveedor
                },
                icon: Icon(Icons.add),
                label: Text('Crear Proveedor'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _suppliers.length,
      itemBuilder: (context, index) {
        final supplier = _suppliers[index];
        final isSelected = supplier['id'] == _selectedSupplierId;

        return Card(
          margin: EdgeInsets.only(bottom: 12),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? Color(0xFF6B8E3D) : Colors.transparent,
              width: 2,
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedSupplierId = supplier['id'];
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  // ÍCONO
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Color(0xFF6B8E3D).withOpacity(0.1)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.business,
                      color: isSelected ? Color(0xFF6B8E3D) : Colors.grey[400],
                      size: 28,
                    ),
                  ),

                  SizedBox(width: 16),

                  // INFO
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          supplier['name'] ?? 'Sin nombre',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Color(0xFF6B8E3D) : Colors.black87,
                          ),
                        ),
                        if (supplier['email'] != null) ...[
                          SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.email_outlined,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  supplier['email'],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (supplier['phone'] != null) ...[
                          SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.phone_outlined,
                                size: 14,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Text(
                                supplier['phone'],
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // RADIO BUTTON
                  Radio<int>(
                    value: supplier['id'],
                    groupValue: _selectedSupplierId,
                    onChanged: (value) {
                      setState(() {
                        _selectedSupplierId = value;
                      });
                    },
                    activeColor: Color(0xFF6B8E3D),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ========================================================================
// FUNCIÓN HELPER PARA MOSTRAR EL DIÁLOGO
// ========================================================================

Future<Map<String, dynamic>?> showSupplierSelectionDialog(
    BuildContext context, {
      int? currentSupplierId,
      String? productName,
    }) async {
  return await showDialog<Map<String, dynamic>>(
    context: context,
    barrierDismissible: false,
    builder: (context) => SupplierSelectionDialog(
      currentSupplierId: currentSupplierId,
      productName: productName,
    ),
  );
}