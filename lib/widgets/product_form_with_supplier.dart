import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/inventory_service.dart';
import '../widgets/supplier_selector.dart';

/// Ejemplo de formulario de producto con selector de proveedor
class ProductFormWithSupplier extends StatefulWidget {
  final Map<String, dynamic>? product;

  const ProductFormWithSupplier({super.key, this.product});

  @override
  State<ProductFormWithSupplier> createState() => _ProductFormWithSupplierState();
}

class _ProductFormWithSupplierState extends State<ProductFormWithSupplier> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _cantidadController = TextEditingController();
  final _alertaCantidadController = TextEditingController();
  final _precioController = TextEditingController();

  int? _selectedSupplierId;
  int? _selectedLocationId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nombreController.text = widget.product!['nombre_producto'] ?? '';
      _descripcionController.text = widget.product!['descripcion']?['texto'] ?? '';
      _cantidadController.text = widget.product!['cantidad']?.toString() ?? '0';
      _alertaCantidadController.text = widget.product!['alerta_cantidad']?.toString() ?? '5';
      _precioController.text = widget.product!['precio']?.toString() ?? '0.00';
      _selectedSupplierId = widget.product!['id_supply_company'];
      _selectedLocationId = widget.product!['id_location'];
    } else {
      _cantidadController.text = '0';
      _alertaCantidadController.text = '5';
      _precioController.text = '0.00';
    }
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _descripcionController.dispose();
    _cantidadController.dispose();
    _alertaCantidadController.dispose();
    _precioController.dispose();
    super.dispose();
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final productData = {
        'nombre_producto': _nombreController.text.trim(),
        'descripcion': {
          'texto': _descripcionController.text.trim(),
        },
        'cantidad': int.parse(_cantidadController.text),
        'alerta_cantidad': int.parse(_alertaCantidadController.text),
        'precio': double.parse(_precioController.text),
        'id_location': _selectedLocationId,
        'id_supply_company': _selectedSupplierId,
      };

      if (widget.product != null) {
        await InventoryService.updateInventoryItem(
          widget.product!['id_inventario'],
          productData,
        );
      } else {
        await InventoryService.createInventoryItem(productData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.product != null
                ? 'Producto actualizado'
                : 'Producto creado'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product != null
            ? 'Editar Producto'
            : 'Nuevo Producto'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _saveProduct,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Información básica
            Text(
              'Información básica',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(
                labelText: 'Nombre del producto *',
                prefixIcon: Icon(Icons.inventory_2),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'El nombre es requerido';
                }
                return null;
              },
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                prefixIcon: Icon(Icons.description),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),

            // Cantidad y precio
            Text(
              'Cantidad y precio',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Cantidad',
                      prefixIcon: Icon(Icons.inventory),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Número inválido';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _alertaCantidadController,
                    decoration: const InputDecoration(
                      labelText: 'Alerta stock',
                      prefixIcon: Icon(Icons.warning),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Requerido';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Número inválido';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _precioController,
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                prefixIcon: Icon(Icons.attach_money),
                border: OutlineInputBorder(),
                prefixText: 'Q ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'El precio es requerido';
                }
                if (double.tryParse(value) == null) {
                  return 'Precio inválido';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Proveedor
            Text(
              'Proveedor',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona el proveedor de este producto (opcional)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),

            // Widget selector de proveedor
            SupplierSelector(
              selectedSupplierId: _selectedSupplierId,
              onSupplierSelected: (supplierId) {
                setState(() => _selectedSupplierId = supplierId);
              },
              label: 'Seleccionar proveedor (opcional)',
            ),
            const SizedBox(height: 24),

            // Ubicación (aquí iría el LocationSelector si lo tienes)
            Text(
              'Ubicación',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Placeholder para selector de ubicación
            Card(
              child: ListTile(
                leading: Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                ),
                title: const Text('Seleccionar ubicación'),
                subtitle: const Text('Opcional'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  // Aquí iría la lógica para seleccionar ubicación
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Selector de ubicación no implementado'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 32),

            // Botón guardar
            FilledButton.icon(
              onPressed: _isLoading ? null : _saveProduct,
              icon: _isLoading
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.save),
              label: Text(widget.product != null ? 'Actualizar' : 'Guardar'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
              ),
            ),

            // Resumen de valores calculados
            if (_cantidadController.text.isNotEmpty &&
                _precioController.text.isNotEmpty) ...[
              const SizedBox(height: 24),
              Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resumen',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Cantidad:'),
                          Text(
                            _cantidadController.text,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Precio unitario:'),
                          Text(
                            InventoryService.formatPrice(
                                double.tryParse(_precioController.text) ?? 0),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor total:'),
                          Text(
                            InventoryService.formatPrice(
                              (int.tryParse(_cantidadController.text) ?? 0) *
                                  (double.tryParse(_precioController.text) ?? 0),
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Widget de ejemplo para mostrar productos con su proveedor
class ProductCardWithSupplier extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback? onTap;

  const ProductCardWithSupplier({
    super.key,
    required this.product,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasSupplier = product['id_supply_company'] != null;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Imagen del producto
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: product['image_url'] != null
                        ? Image.network(
                      product['image_url'],
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    )
                        : Container(
                      width: 60,
                      height: 60,
                      color: Colors.grey[200],
                      child: const Icon(Icons.inventory_2),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Información del producto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product['nombre_producto'] ?? 'Sin nombre',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.inventory,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text('Stock: ${product['cantidad'] ?? 0}'),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.attach_money,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            Text(InventoryService.formatPrice(product['precio'])),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (hasSupplier) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.business,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Proveedor',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                          Text(
                            product['proveedor_nombre'] ?? 'N/A',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}