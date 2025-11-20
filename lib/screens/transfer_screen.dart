import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/transfer_service.dart';
import '../services/inventory_service.dart';
import '../widgets/collapsible_drawer.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<Map<String, dynamic>> _transferCart = [];
  List<Map<String, dynamic>> _inventory = [];
  List<Map<String, dynamic>> _locations = [];

  int? _selectedOriginLocation;
  int? _selectedDestinationLocation;

  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final inventory = await TransferService.getInventoryWithLocations();
      final locations = await InventoryService.getLocations();

      if (mounted) {
        setState(() {
          _inventory = inventory;
          _locations = locations;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Error cargando datos: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return CollapsibleDrawer(
      currentRoute: '/transfers',
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F3E8),
        appBar: AppBar(
          leading: const SizedBox.shrink(),
          title: const Text('Transferencias'),
          backgroundColor: const Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildTabBar(),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNewTransferTab(),
                  _buildHistoryTab(),
                  _buildScanTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF2B5F8C),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF6B8E3D),
        tabs: const [
          Tab(icon: Icon(Icons.add_circle_outline), text: 'Nueva'),
          Tab(icon: Icon(Icons.history), text: 'Historial'),
          Tab(icon: Icon(Icons.qr_code_scanner), text: 'Escanear'),
        ],
      ),
    );
  }

  Widget _buildNewTransferTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildLocationSelectors(),
          const SizedBox(height: 20),
          _buildTransferCart(),
          const SizedBox(height: 20),
          _buildProductSelector(),
        ],
      ),
    );
  }

  Widget _buildLocationSelectors() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.location_on, color: Color(0xFF2B5F8C)),
              SizedBox(width: 8),
              Text(
                'Seleccionar Localizaciones',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            value: _selectedOriginLocation,
            decoration: InputDecoration(
              labelText: 'Desde (Opcional)',
              prefixIcon: const Icon(Icons.arrow_upward, color: Color(0xFF6B8E3D)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('Entrada Nueva / Sin Origen'),
              ),
              ..._locations.map((loc) => DropdownMenuItem<int?>(
                value: loc['id_locat'],
                child: Text(loc['lugar_fisico'] ?? 'Sin nombre'),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedOriginLocation = value;
                _transferCart.clear();
              });
            },
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            value: _selectedDestinationLocation,
            decoration: InputDecoration(
              labelText: 'Hacia (Destino) *',
              prefixIcon: const Icon(Icons.arrow_downward, color: Colors.orange),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            items: _locations
                .where((loc) => loc['id_locat'] != _selectedOriginLocation)
                .map((loc) => DropdownMenuItem<int?>(
              value: loc['id_locat'],
              child: Text(loc['lugar_fisico'] ?? 'Sin nombre'),
            ))
                .toList(),
            onChanged: (value) {
              setState(() => _selectedDestinationLocation = value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCart() {
    if (_transferCart.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Carrito Vacío',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona productos para transferir',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF2B5F8C),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_shipping, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Productos a Transferir (${_transferCart.length})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  onPressed: () {
                    setState(() => _transferCart.clear());
                  },
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _transferCart.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              return _buildTransferCartItem(_transferCart[index], index);
            },
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _canProcessTransfer() && !_isProcessing
                    ? _processTransfer
                    : null,
                icon: _isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Icon(Icons.send),
                label: Text(_isProcessing ? 'Procesando...' : 'Crear Transferencia'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCartItem(Map<String, dynamic> item, int index) {
    final imageUrl = item['imagen'];
    final fromLocationName = item['from_location_name'];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.grey.shade100,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: imageUrl != null
                  ? _buildProductImage(imageUrl)
                  : const Icon(Icons.image_not_supported, color: Colors.grey),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['nombre_producto'],
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Cantidad: ${item['cantidad']}',
                  style: const TextStyle(
                    color: Color(0xFF6B8E3D),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
                if (fromLocationName != null) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Colors.grey),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(
                          fromLocationName,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: Colors.orange,
                iconSize: 20,
                onPressed: () => _updateTransferQuantity(index, item['cantidad'] - 1),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: const Color(0xFF6B8E3D),
                iconSize: 20,
                onPressed: () => _updateTransferQuantity(index, item['cantidad'] + 1),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                color: Colors.red,
                iconSize: 20,
                onPressed: () {
                  setState(() => _transferCart.removeAt(index));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelector() {
    final availableProducts = _inventory.where((product) {
      final alreadyInCart = _transferCart.any(
              (item) => item['id_inventario'] == product['id_inventario']
      );
      return !alreadyInCart;
    }).toList();

    if (availableProducts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'No hay productos disponibles',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _transferCart.isEmpty
                  ? 'Agrega productos a tu inventario primero'
                  : 'Todos los productos ya están en el carrito',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.add_shopping_cart, color: Color(0xFF6B8E3D)),
              SizedBox(width: 8),
              Text(
                'Agregar Productos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: availableProducts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return _buildProductSelectorItem(availableProducts[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductSelectorItem(Map<String, dynamic> product) {
    final ubicaciones = product['ubicaciones'] as List? ?? [];

    if (_selectedOriginLocation != null) {
      final stockInOrigin = _getStockInLocation(ubicaciones, _selectedOriginLocation!);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.grey.shade100,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: product['imagen'] != null
                    ? _buildProductImage(product['imagen'])
                    : const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['nombre_producto'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stock en origen: $stockInOrigin',
                    style: TextStyle(
                      color: stockInOrigin > 0 ? const Color(0xFF6B8E3D) : Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle, color: Color(0xFF6B8E3D)),
              onPressed: stockInOrigin > 0
                  ? () => _showAddToTransferDialog(product, stockInOrigin, _selectedOriginLocation)
                  : null,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: product['imagen'] != null
                      ? _buildProductImage(product['imagen'])
                      : const Icon(Icons.image_not_supported, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product['nombre_producto'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Stock total: ${product['cantidad_total']}',
                      style: const TextStyle(
                        color: Color(0xFF6B8E3D),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (ubicaciones.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const Text(
              'Selecciona ubicación de origen:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...ubicaciones.map((loc) => InkWell(
              onTap: () => _showAddToTransferDialog(
                  product,
                  loc['cantidad'],
                  loc['id_location']
              ),
              child: Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3E8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc['lugar_fisico'] ?? 'Sin nombre',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${loc['cantidad']} uds disponibles',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B8E3D),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.add_circle,
                      color: Color(0xFF6B8E3D),
                      size: 24,
                    ),
                  ],
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildProductImage(String imageUrl) {
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF6B8E3D),
              strokeWidth: 2,
            ),
          ),
        ),
        errorWidget: (context, url, error) => const Icon(
          Icons.broken_image,
          color: Colors.grey,
        ),
      );
    } else {
      return Image.file(
        File(imageUrl),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.image_not_supported,
          color: Colors.grey,
        ),
      );
    }
  }

  Widget _buildHistoryTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: TransferService.getTransferHistory(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF6B8E3D)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 80,
                  color: Colors.grey.withOpacity(0.3),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Sin Transferencias',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildHistoryItem(snapshot.data![index]);
          },
        );
      },
    );
  }

  Widget _buildHistoryItem(Map<String, dynamic> transfer) {
    final status = transfer['status'] as String?;
    final statusColor = _getStatusColor(status);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(_getStatusIcon(status), color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transfer['transfer_code'] ?? 'N/A',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        TransferService.getTransferStatusText(status),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.qr_code),
                  color: const Color(0xFF2B5F8C),
                  onPressed: () => _showTransferQR(transfer),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.place, color: Color(0xFF6B8E3D), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${transfer['origen'] ?? 'Nueva Entrada'} → ${transfer['destino']}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${transfer['total_items']} productos',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      _formatDate(transfer['fecha_creacion']),
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (status == 'pending') ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _cancelTransfer(transfer['id']),
                          icon: const Icon(Icons.cancel, size: 16),
                          label: const Text('Cancelar'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _completeTransfer(transfer['id']),
                          icon: const Icon(Icons.check_circle, size: 16),
                          label: const Text('Completar'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6B8E3D),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanTab() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.qr_code_scanner,
              size: 100,
              color: Color(0xFF2B5F8C),
            ),
            const SizedBox(height: 24),
            const Text(
              'Escanear Código de Transferencia',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Escanea el código QR para autorizar\no completar una transferencia',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _scanTransferCode,
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Escanear Código'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _enterTransferCodeManually,
              icon: const Icon(Icons.keyboard),
              label: const Text('Ingresar Código Manualmente'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2B5F8C),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getStockInLocation(List ubicaciones, int locationId) {
    try {
      final location = ubicaciones.firstWhere(
            (loc) => loc['id_location'] == locationId,
        orElse: () => {'cantidad': 0},
      );
      return location['cantidad'] ?? 0;
    } catch (e) {
      return 0;
    }
  }

  void _updateTransferQuantity(int index, int newQuantity) {
    if (newQuantity <= 0) {
      setState(() => _transferCart.removeAt(index));
      return;
    }

    final item = _transferCart[index];
    final product = _inventory.firstWhere(
            (p) => p['id_inventario'] == item['id_inventario']
    );
    final ubicaciones = product['ubicaciones'] as List? ?? [];
    final fromLocationId = item['from_location_id'];

    final maxStock = fromLocationId != null
        ? _getStockInLocation(ubicaciones, fromLocationId)
        : product['cantidad_total'];

    if (newQuantity <= maxStock) {
      setState(() {
        _transferCart[index]['cantidad'] = newQuantity;
      });
    } else {
      _showError('Stock máximo: $maxStock');
    }
  }

  void _showAddToTransferDialog(Map<String, dynamic> product, int maxStock, int? fromLocationId) {
    final quantityController = TextEditingController(text: '1');
    String? locationName;

    if (fromLocationId != null) {
      final ubicaciones = product['ubicaciones'] as List? ?? [];
      final location = ubicaciones.firstWhere(
            (loc) => loc['id_location'] == fromLocationId,
        orElse: () => {'lugar_fisico': 'Ubicación desconocida'},
      );
      locationName = location['lugar_fisico'];
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar a Transferencia'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              product['nombre_producto'],
              style: const TextStyle(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            if (locationName != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Color(0xFF2B5F8C)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        locationName,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'Stock disponible: $maxStock',
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Cantidad',
                border: const OutlineInputBorder(),
                suffixText: '/ $maxStock',
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text) ?? 0;
              if (quantity > 0 && quantity <= maxStock) {
                setState(() {
                  _transferCart.add({
                    'id_inventario': product['id_inventario'],
                    'nombre_producto': product['nombre_producto'],
                    'imagen': product['imagen'],
                    'cantidad': quantity,
                    'cantidad_total': product['cantidad_total'],
                    'from_location_id': fromLocationId,
                    'from_location_name': locationName,
                  });
                });
                Navigator.pop(context);
              } else {
                Navigator.pop(context);
                _showError('Cantidad inválida (máx: $maxStock)');
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

  bool _canProcessTransfer() {
    return _transferCart.isNotEmpty &&
        _selectedDestinationLocation != null &&
        !_isProcessing;
  }

  Future<void> _processTransfer() async {
    if (!_canProcessTransfer()) return;

    setState(() => _isProcessing = true);

    try {
      final itemsWithLocations = _transferCart.map((item) {
        return {
          'id_inventario': item['id_inventario'],
          'cantidad': item['cantidad'],
          'from_location_id': item['from_location_id'] ?? _selectedOriginLocation,
        };
      }).toList();

      final validation = await TransferService.validateTransfer(
        originLocationId: _selectedOriginLocation,
        items: itemsWithLocations,
      );

      if (validation['isValid'] != true) {
        throw Exception(validation['error']);
      }

      final result = await TransferService.createTransferOrder(
        originLocationId: _selectedOriginLocation,
        destinationLocationId: _selectedDestinationLocation!,
        items: itemsWithLocations,
      );

      if (result['success'] == true) {
        _showTransferCreatedDialog(result['transfer_code']);
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  void _showTransferCreatedDialog(String transferCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(Icons.check_circle, color: Color(0xFF6B8E3D), size: 48),
            SizedBox(height: 8),
            Text('Transferencia Creada'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Tu transferencia ha sido creada exitosamente',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F3E8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Text(
                    'Código de Transferencia:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transferCode,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            QrImageView(
              data: TransferService.generateTransferQRData({
                'transfer_code': transferCode,
                'to_location_id': _selectedDestinationLocation,
                'total_items': _transferCart.length,
                'status': 'pending',
              }),
              version: QrVersions.auto,
              size: 200,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _transferCart.clear();
                _selectedOriginLocation = null;
                _selectedDestinationLocation = null;
              });
              _tabController.animateTo(1);
              _loadData();
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _completeTransfer(int transferId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Completar Transferencia'),
        content: const Text(
          '¿Confirmas que esta transferencia ha sido recibida?\n\n'
              'El stock se actualizará automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Completar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TransferService.processTransfer(transferId);
      _showSuccess('Transferencia completada exitosamente');
      setState(() {});
    } catch (e) {
      _showError('Error: $e');
    }
  }

  Future<void> _cancelTransfer(int transferId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Transferencia'),
        content: const Text('¿Estás seguro de cancelar esta transferencia?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TransferService.cancelTransfer(transferId);
      _showSuccess('Transferencia cancelada');
      setState(() {});
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showTransferQR(Map<String, dynamic> transfer) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transfer['transfer_code'] ?? 'N/A',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              QrImageView(
                data: TransferService.generateTransferQRData(transfer),
                version: QrVersions.auto,
                size: 250,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2B5F8C),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _scanTransferCode() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (context) => const _TransferScannerScreen()),
    );

    if (result != null) {
      _handleScannedTransferCode(result);
    }
  }

  void _enterTransferCodeManually() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresar Código'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Código de Transferencia',
            hintText: 'TRF-YYYYMMDD-XXXX',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _handleScannedTransferCode(codeController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6B8E3D),
              foregroundColor: Colors.white,
            ),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleScannedTransferCode(String code) async {
    try {
      final qrData = TransferService.parseTransferQRData(code);
      final searchCode = qrData?['code'] ?? code;

      final transfer = await TransferService.getTransferByCode(searchCode);

      if (transfer == null) {
        _showError('Transferencia no encontrada');
        return;
      }

      _showTransferDetailsDialog(transfer);
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showTransferDetailsDialog(Map<String, dynamic> transfer) {
    final details = transfer['details'] as List? ?? [];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          children: [
            Text(transfer['transfer_code'] ?? 'N/A'),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _getStatusColor(transfer['status']).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                TransferService.getTransferStatusText(transfer['status']),
                style: TextStyle(
                  color: _getStatusColor(transfer['status']),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Origen:',
                  transfer['locat_origen']?['lugar_fisico'] ?? 'Nueva Entrada'),
              _buildDetailRow('Destino:',
                  transfer['locat_destino']?['lugar_fisico'] ?? 'N/A'),
              const Divider(),
              const Text(
                'Productos:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...details.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  '• ${item['nombre_producto']} (${item['quantity']})',
                  style: const TextStyle(fontSize: 12),
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          if (transfer['status'] == 'pending')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _completeTransfer(transfer['id']);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Completar'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'in_transit':
        return const Color(0xFF2B5F8C);
      case 'completed':
        return const Color(0xFF6B8E3D);
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case 'pending':
        return Icons.schedule;
      case 'in_transit':
        return Icons.local_shipping;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dt = DateTime.parse(date.toString());
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (e) {
      return 'N/A';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E3D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _TransferScannerScreen extends StatefulWidget {
  const _TransferScannerScreen();

  @override
  State<_TransferScannerScreen> createState() => _TransferScannerScreenState();
}

class _TransferScannerScreenState extends State<_TransferScannerScreen> {
  late MobileScannerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Escanear Transferencia'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final code = barcodes.first.rawValue ?? '';
                if (code.isNotEmpty) {
                  Navigator.pop(context, code);
                }
              }
            },
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFF6B8E3D), width: 3),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}