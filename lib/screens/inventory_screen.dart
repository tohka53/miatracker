import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:barcode_widget/barcode_widget.dart' as barcode_widget;
import 'package:mobile_scanner/mobile_scanner.dart' as scanner;
import 'package:permission_handler/permission_handler.dart';
import '../widgets/drawer_scaffold.dart';
import '../services/inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _filteredInventory = [];
  List<Map<String, dynamic>> _locations = [];

  bool _isLoading = true;
  bool _isLoadingLocations = false;
  String _searchQuery = '';
  String _selectedFilter = 'all';

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadLocations();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final inventory = await InventoryService.getInventory();

      if (mounted) {
        setState(() {
          _inventory = inventory;
          _filteredInventory = inventory;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        _showErrorSnackBar('Error al cargar inventario: ${e.toString()}');
      }
    }
  }

  Future<void> _loadLocations() async {
    try {
      setState(() {
        _isLoadingLocations = true;
      });

      final locations = await InventoryService.getLocations();

      if (mounted) {
        setState(() {
          _locations = locations;
          _isLoadingLocations = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingLocations = false;
        });
      }
    }
  }

  void _filterInventory() {
    String query = _searchQuery.toLowerCase();

    setState(() {
      _filteredInventory = _inventory.where((item) {
        bool matchesSearch = query.isEmpty ||
            item['nombre_producto']?.toString().toLowerCase().contains(query) == true ||
            item['descripcion']?.toString().toLowerCase().contains(query) == true ||
            item['lugar_fisico']?.toString().toLowerCase().contains(query) == true;

        bool matchesFilter = _selectedFilter == 'all' ||
            (_selectedFilter == 'low_stock' && item['stock_status'] == 'low_stock') ||
            (_selectedFilter == 'out_of_stock' && item['stock_status'] == 'out_of_stock') ||
            (_selectedFilter == 'normal' && item['stock_status'] == 'normal');

        return matchesSearch && matchesFilter;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DrawerScaffold(
      title: 'Inventario',
      currentRoute: '/inventory',
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          onPressed: _showQRScanner,
          tooltip: 'Escanear QR',
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
        ),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: _showAddItemDialog,
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddItemDialog,
        backgroundColor: const Color(0xFF6B8E3D),
        icon: const Icon(Icons.add),
        label: const Text('Agregar Producto'),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildInventoryList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            color: Color(0xFF2B5F8C),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar productos...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.grey),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
                _filterInventory();
              },
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, color: Colors.grey),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                });
                _filterInventory();
              },
            ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'Todos', 'count': _inventory.length},
      {
        'key': 'normal',
        'label': 'Normal',
        'count': _inventory.where((item) => item['stock_status'] == 'normal').length
      },
      {
        'key': 'low_stock',
        'label': 'Stock Bajo',
        'count': _inventory.where((item) => item['stock_status'] == 'low_stock').length
      },
      {
        'key': 'out_of_stock',
        'label': 'Sin Stock',
        'count': _inventory.where((item) => item['stock_status'] == 'out_of_stock').length
      },
    ];

    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];

          return Container(
            margin: const EdgeInsets.only(right: 12),
            child: FilterChip(
              label: Text(
                '${filter['label']} (${filter['count']})',
                style: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF2B5F8C),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter['key'] as String;
                });
                _filterInventory();
              },
              backgroundColor: Colors.white,
              selectedColor: const Color(0xFF6B8E3D),
              checkmarkColor: Colors.white,
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF6B8E3D)
                    : Colors.grey.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInventoryList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF6B8E3D),
        ),
      );
    }

    if (_filteredInventory.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      itemCount: _filteredInventory.length,
      itemBuilder: (context, index) {
        final item = _filteredInventory[index];
        return _buildInventoryCard(item);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off
                : Icons.inventory_2_outlined,
            size: 80,
            color: Colors.grey.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No se encontraron productos'
                : 'No hay productos en el inventario',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Intenta con otros términos de búsqueda'
                : 'Comienza agregando tu primer producto',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _searchQuery.isNotEmpty
                ? () {
              _searchController.clear();
              setState(() {
                _searchQuery = '';
              });
              _filterInventory();
            }
                : _showAddItemDialog,
            icon: Icon(_searchQuery.isNotEmpty ? Icons.clear : Icons.add),
            label: Text(_searchQuery.isNotEmpty ? 'Limpiar búsqueda' : 'Agregar Producto'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryCard(Map<String, dynamic> item) {
    final stockStatus = item['stock_status'] ?? 'normal';
    final cantidad = item['cantidad'] ?? 0;
    final coordenadas = InventoryService.formatCoordinates(item['coordenadas']);
    final lugarFisico = item['lugar_fisico'] ?? 'Sin ubicación';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['nombre_producto'] ?? 'Sin nombre',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2B5F8C),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stock: $cantidad unidades',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(int.parse(
                            InventoryService.getStockStatusColor(stockStatus).replaceFirst('#', '0xFF')
                        )),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Color(int.parse(
                      InventoryService.getStockStatusColor(stockStatus).replaceFirst('#', '0xFF')
                  )).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  InventoryService.getStockStatusText(stockStatus),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(int.parse(
                        InventoryService.getStockStatusColor(stockStatus).replaceFirst('#', '0xFF')
                    )),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (item['descripcion'] != null && item['descripcion'].toString().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3E8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Descripción:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2B5F8C),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDescription(item['descripcion']),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Color(0xFF6B8E3D),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Ubicación:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B8E3D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      lugarFisico,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _showCoordinatesDialog(coordenadas, lugarFisico),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.map,
                            size: 14,
                            color: Color(0xFF2B5F8C),
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              coordenadas,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF2B5F8C),
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) => _handleMenuAction(value, item),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'qr',
                    child: Row(
                      children: [
                        Icon(Icons.qr_code, size: 18),
                        SizedBox(width: 8),
                        Text('Ver QR'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 18),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, size: 18, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Eliminar', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDescription(dynamic description) {
    if (description == null) return 'Sin descripción';

    if (description is Map) {
      final desc = description as Map<String, dynamic>;
      return desc.entries
          .map((e) => '${e.key}: ${e.value}')
          .join(' • ');
    }

    return description.toString();
  }

  void _showCoordinatesDialog(String coordinates, String location) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.map, color: Color(0xFF2B5F8C)),
            SizedBox(width: 8),
            Text('Ubicación'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lugar: $location',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Coordenadas: $coordinates'),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: coordinates));
                      Navigator.pop(context);
                      _showSuccessSnackBar('Coordenadas copiadas');
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _handleMenuAction(String action, Map<String, dynamic> item) {
    switch (action) {
      case 'qr':
        _showQRCode(item);
        break;
      case 'edit':
        _showEditItemDialog(item);
        break;
      case 'delete':
        _showDeleteConfirmation(item);
        break;
    }
  }

  void _showAddItemDialog() {
    _showItemDialog();
  }

  void _showEditItemDialog(Map<String, dynamic> item) {
    _showItemDialog(item: item);
  }

  void _showItemDialog({Map<String, dynamic>? item}) {
    final isEditing = item != null;
    final nameController = TextEditingController(text: item?['nombre_producto'] ?? '');
    final cantidadController = TextEditingController(text: item?['cantidad']?.toString() ?? '');
    final alertaController = TextEditingController(text: item?['alerta_cantidad']?.toString() ?? '');
    final descripcionController = TextEditingController(text: _formatDescription(item?['descripcion']));
    final qrController = TextEditingController(text: item?['codigo_barras']?['qr_data'] ?? '');
    int? selectedLocationId = item?['id_locat'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEditing ? 'Editar Producto' : 'Agregar Producto'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre del Producto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descripcionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: cantidadController,
                      decoration: const InputDecoration(
                        labelText: 'Cantidad',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: alertaController,
                      decoration: const InputDecoration(
                        labelText: 'Alerta Stock',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              TextField(
                controller: qrController,
                decoration: InputDecoration(
                  labelText: 'Código QR/Barras (Opcional)',
                  border: const OutlineInputBorder(),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: () => _scanQRForForm(qrController),
                        tooltip: 'Escanear QR',
                      ),
                      IconButton(
                        icon: const Icon(Icons.auto_awesome),
                        onPressed: () => _generateQRForForm(qrController, nameController.text),
                        tooltip: 'Generar automático',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: selectedLocationId,
                decoration: const InputDecoration(
                  labelText: 'Ubicación',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Sin ubicación'),
                  ),
                  ..._locations.map((location) => DropdownMenuItem<int>(
                    value: location['id_locat'],
                    child: Text(location['lugar_fisico'] ?? 'Ubicación sin nombre'),
                  )),
                ],
                onChanged: (value) {
                  selectedLocationId = value;
                },
              ),
              if (_locations.isEmpty && !_isLoadingLocations)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: TextButton.icon(
                    onPressed: _showAddLocationDialog,
                    icon: const Icon(Icons.add_location),
                    label: const Text('Crear primera ubicación'),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showErrorSnackBar('El nombre del producto es requerido');
                return;
              }

              try {
                final itemData = {
                  'nombre_producto': nameController.text.trim(),
                  'descripcion': descripcionController.text.trim().isEmpty
                      ? null
                      : {'descripcion': descripcionController.text.trim()},
                  'cantidad': int.tryParse(cantidadController.text) ?? 0,
                  'alerta_cantidad': int.tryParse(alertaController.text) ?? 5,
                  'id_location': selectedLocationId,
                  'codigo_barras': qrController.text.trim().isEmpty
                      ? null
                      : {
                    'qr_data': qrController.text.trim(),
                    'type': 'custom',
                    'generated_at': DateTime.now().toIso8601String(),
                  },
                };

                if (isEditing) {
                  await InventoryService.updateInventoryItem(
                    item['id_inventario'],
                    itemData,
                  );
                  _showSuccessSnackBar('Producto actualizado exitosamente');
                } else {
                  await InventoryService.createInventoryItem(itemData);
                  _showSuccessSnackBar('Producto agregado exitosamente');
                }

                Navigator.pop(context);
                _loadData();
              } catch (e) {
                _showErrorSnackBar('Error: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: Text(isEditing ? 'Actualizar' : 'Agregar'),
          ),
        ],
      ),
    );
  }

  void _showAddLocationDialog() {
    final nameController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Ubicación'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del Lugar',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: latController,
                    decoration: const InputDecoration(
                      labelText: 'Latitud',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: lngController,
                    decoration: const InputDecoration(
                      labelText: 'Longitud',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                _showErrorSnackBar('El nombre del lugar es requerido');
                return;
              }

              try {
                final locationData = {
                  'lugar_fisico': nameController.text.trim(),
                  'coordenadas': (latController.text.isNotEmpty && lngController.text.isNotEmpty)
                      ? {
                    'lat': double.tryParse(latController.text) ?? 0.0,
                    'lng': double.tryParse(lngController.text) ?? 0.0,
                  }
                      : null,
                };

                await InventoryService.createLocation(locationData);
                _showSuccessSnackBar('Ubicación agregada exitosamente');
                Navigator.pop(context);
                await _loadLocations();
              } catch (e) {
                _showErrorSnackBar('Error al crear ubicación: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('Confirmar Eliminación'),
          ],
        ),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${item['nombre_producto']}"?\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await InventoryService.deleteInventoryItem(item['id_inventario']);
                _showSuccessSnackBar('Producto eliminado exitosamente');
                Navigator.pop(context);
                _loadData();
              } catch (e) {
                _showErrorSnackBar('Error al eliminar producto: ${e.toString()}');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // Funciones para códigos QR
  void _generateQRForForm(TextEditingController controller, String productName) {
    if (productName.trim().isEmpty) {
      _showErrorSnackBar('Ingresa un nombre de producto primero');
      return;
    }

    // Generar código para código de barras (alfanumérico)
    final barcodeData = 'MIA${productName.replaceAll(' ', '').toUpperCase().substring(0, productName.length > 3 ? 3 : productName.length)}${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
    controller.text = barcodeData;
    _showSuccessSnackBar('Código de barras generado automáticamente');
  }

  void _scanQRForForm(TextEditingController controller) async {
    final permission = await Permission.camera.request();
    if (permission != PermissionStatus.granted) {
      _showErrorSnackBar('Se requiere permiso de cámara para escanear QR');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QRScannerScreen(
          onQRDetected: (qrData) {
            controller.text = qrData;
            _showSuccessSnackBar('Código QR capturado');
          },
        ),
      ),
    );
  }

  void _showQRCode(Map<String, dynamic> item) {
    // Obtener o generar códigos
    String qrData;
    String barcodeData;

    if (item['codigo_barras'] != null) {
      if (item['codigo_barras']['qr_data'] != null) {
        qrData = item['codigo_barras']['qr_data'];
        barcodeData = item['codigo_barras']['qr_data']; // Usar el mismo código para el barcode
      } else if (item['codigo_barras']['barcode_data'] != null) {
        barcodeData = item['codigo_barras']['barcode_data'];
        qrData = InventoryService.generateQRData(item);
      } else {
        qrData = InventoryService.generateQRData(item);
        barcodeData = InventoryService.generateBarcodeData(item);
      }
    } else {
      qrData = InventoryService.generateQRData(item);
      barcodeData = InventoryService.generateBarcodeData(item);
    }

    final productCode = InventoryService.generateProductCode(item);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.qr_code, color: Color(0xFF2B5F8C)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Códigos - ${item['nombre_producto']}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pestañas para alternar entre QR y Código de Barras
              DefaultTabController(
                length: 2,
                child: Column(
                  children: [
                    const TabBar(
                      labelColor: Color(0xFF2B5F8C),
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: Color(0xFF6B8E3D),
                      tabs: [
                        Tab(
                          icon: Icon(Icons.qr_code),
                          text: 'Código QR',
                        ),
                        Tab(
                          icon: Icon(Icons.view_stream),
                          text: 'Código de Barras',
                        ),
                      ],
                    ),
                    SizedBox(
                      height: 300,
                      child: TabBarView(
                        children: [
                          // Tab 1: Código QR
                          _buildQRCodeTab(qrData),
                          // Tab 2: Código de Barras
                          _buildBarcodeTab(barcodeData),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Información del producto
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 16, color: Color(0xFF2B5F8C)),
                        const SizedBox(width: 4),
                        const Text(
                          'Información del producto:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2B5F8C),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Código: $productCode', style: const TextStyle(fontSize: 12)),
                    Text('Stock: ${item['cantidad']} unidades', style: const TextStyle(fontSize: 12)),
                    Text('Ubicación: ${item['lugar_fisico'] ?? 'Sin ubicación'}', style: const TextStyle(fontSize: 12)),
                    Text('Código QR: ${qrData.length > 30 ? '${qrData.substring(0, 30)}...' : qrData}',
                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                    Text('Código de Barras: $barcodeData',
                        style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic)),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Botones de acción
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: qrData));
                        _showSuccessSnackBar('Código QR copiado');
                      },
                      icon: const Icon(Icons.qr_code, size: 16),
                      label: const Text('Copiar QR'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B8E3D),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: barcodeData));
                        _showSuccessSnackBar('Código de barras copiado');
                      },
                      icon: const Icon(Icons.view_stream, size: 16),
                      label: const Text('Copiar Barras'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2B5F8C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _buildQRCodeTab(String qrData) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: QrImageView(
              data: qrData,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Código QR',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5F8C),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarcodeTab(String barcodeData) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              children: [
                barcode_widget.BarcodeWidget(
                  barcode: barcode_widget.Barcode.code128(),
                  data: barcodeData,
                  width: 250,
                  height: 80,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black,
                  ),
                  drawText: true,
                  errorBuilder: (context, error) {
                    return Column(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.red,
                          size: 32,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Error generando código de barras',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          barcodeData,
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                // Intentar también con Code39 si Code128 falla
                barcode_widget.BarcodeWidget(
                  barcode: barcode_widget.Barcode.code39(),
                  data: barcodeData.replaceAll(RegExp(r'[^A-Z0-9\-\. \$/\+%]'), ''), // Solo caracteres válidos para Code39
                  width: 250,
                  height: 60,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Colors.black,
                  ),
                  drawText: true,
                  errorBuilder: (context, error) {
                    return Container(
                      height: 60,
                      child: Center(
                        child: Text(
                          'Code39: ${barcodeData.substring(0, barcodeData.length > 20 ? 20 : barcodeData.length)}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Código de Barras (Code128 / Code39)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2B5F8C),
            ),
          ),
        ],
      ),
    );
  }

  void _showQRScanner() async {
    final permission = await Permission.camera.request();
    if (permission != PermissionStatus.granted) {
      _showErrorSnackBar('Se requiere permiso de cámara para escanear QR');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _QRScannerScreen(
          onQRDetected: _handleQRDetected,
        ),
      ),
    );
  }

  void _handleQRDetected(String qrData) async {
    try {
      final item = await InventoryService.getItemByQRCode(qrData);

      if (item != null) {
        _showQRResultDialog(item);
      } else {
        final parsedData = InventoryService.parseQRData(qrData);
        if (parsedData != null) {
          _showErrorSnackBar('Producto no encontrado o no pertenece a tu inventario');
        } else {
          _showErrorSnackBar('Código QR no válido para M.I.A Tracker');
        }
      }
    } catch (e) {
      _showErrorSnackBar('Error al procesar código QR: ${e.toString()}');
    }
  }

  void _showQRResultDialog(Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF6B8E3D)),
            SizedBox(width: 8),
            Text('Producto Encontrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item['nombre_producto'] ?? 'Sin nombre',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
            ),
            const SizedBox(height: 8),
            Text('Stock: ${item['cantidad']} unidades'),
            Text('Estado: ${InventoryService.getStockStatusText(item['stock_status'])}'),
            Text('Ubicación: ${item['lugar_fisico'] ?? 'Sin ubicación'}'),
            if (item['descripcion'] != null)
              Text('Descripción: ${_formatDescription(item['descripcion'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditItemDialog(item);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Editar'),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E3D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

// Widget para escanear códigos QR
class _QRScannerScreen extends StatefulWidget {
  final Function(String) onQRDetected;

  const _QRScannerScreen({required this.onQRDetected});

  @override
  State<_QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<_QRScannerScreen> {
  bool _screenOpened = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear Código QR'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          scanner.MobileScanner(
            onDetect: _foundBarcode,
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
            ),
            child: Center(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0xFF6B8E3D),
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Coloca el código QR dentro del marco',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Se detectará automáticamente',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _foundBarcode(scanner.BarcodeCapture capture) {
    if (!_screenOpened && capture.barcodes.isNotEmpty) {
      final String code = capture.barcodes.first.rawValue ?? '';
      if (code.isNotEmpty) {
        _screenOpened = true;
        Navigator.pop(context);
        widget.onQRDetected(code);
      }
    }
  }
}