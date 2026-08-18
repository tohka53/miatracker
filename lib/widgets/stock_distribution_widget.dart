import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/inventory_service.dart';

class StockDistributionWidget extends StatefulWidget {
  final int totalStock;
  final List<Map<String, dynamic>> locations;
  final Function(Map<int, int>) onDistributionChanged;
  final Map<int, int>? initialDistribution;

  const StockDistributionWidget({
    super.key,
    required this.totalStock,
    required this.locations,
    required this.onDistributionChanged,
    this.initialDistribution,
  });

  @override
  State<StockDistributionWidget> createState() => _StockDistributionWidgetState();
}

class _StockDistributionWidgetState extends State<StockDistributionWidget> {
  final Map<int, TextEditingController> _controllers = {};
  final Map<int, int> _distribution = {};

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    for (final location in widget.locations) {
      final locationId = location['id_locat'] as int;
      final initialValue = widget.initialDistribution?[locationId] ?? 0;
      _controllers[locationId] = TextEditingController(text: initialValue.toString());
      _distribution[locationId] = initialValue;
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int get _totalDistributed {
    return _distribution.values.fold(0, (sum, value) => sum + value);
  }

  bool get _isValidDistribution {
    return _totalDistributed == widget.totalStock;
  }

  void _updateDistribution(int locationId, int quantity) {
    setState(() {
      _distribution[locationId] = quantity;
      widget.onDistributionChanged(_distribution);
    });
  }

  void _distributeEqually() {
    if (widget.locations.isEmpty) return;

    final perLocation = widget.totalStock ~/ widget.locations.length;
    final remainder = widget.totalStock % widget.locations.length;

    setState(() {
      for (int i = 0; i < widget.locations.length; i++) {
        final locationId = widget.locations[i]['id_locat'] as int;
        final quantity = perLocation + (i < remainder ? 1 : 0);
        _distribution[locationId] = quantity;
        _controllers[locationId]?.text = quantity.toString();
      }
      widget.onDistributionChanged(_distribution);
    });
  }

  void _clearDistribution() {
    setState(() {
      for (final entry in _controllers.entries) {
        entry.value.text = '0';
        _distribution[entry.key] = 0;
      }
      widget.onDistributionChanged(_distribution);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isValidDistribution
              ? const Color(0xFF6B8E3D)
              : Colors.orange.shade300,
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.warehouse, color: Color(0xFF2B5F8C)),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Stock Distribution',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                color: Colors.grey,
                onPressed: () => _showDistributionInfo(),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Indicador de progreso
          _buildProgressIndicator(),
          const SizedBox(height: 16),

          // Botones de acción rápida
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _distributeEqually,
                  icon: const Icon(Icons.compare_arrows, size: 16),
                  label: const Text('Distribute Evenly', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF6B8E3D),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _clearDistribution,
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Lista de ubicaciones
          if (widget.locations.isEmpty)
            _buildEmptyLocations()
          else
            ...widget.locations.map((location) => _buildLocationItem(location)),

          // Mensaje de validación
          if (!_isValidDistribution && _totalDistributed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Distribuido: $_totalDistributed / ${widget.totalStock}\n'
                            'Remaining: ${widget.totalStock - _totalDistributed}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Mensaje de éxito
          if (_isValidDistribution && _totalDistributed > 0)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B8E3D).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6B8E3D)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle, color: Color(0xFF6B8E3D), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '✓ Valid distribution',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B8E3D),
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildProgressIndicator() {
    final progress = widget.totalStock > 0
        ? _totalDistributed / widget.totalStock
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Total: ${widget.totalStock} units',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
            ),
            Text(
              'Distribuido: $_totalDistributed',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _isValidDistribution
                    ? const Color(0xFF6B8E3D)
                    : Colors.orange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(
              _isValidDistribution
                  ? const Color(0xFF6B8E3D)
                  : Colors.orange,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocationItem(Map<String, dynamic> location) {
    final locationId = location['id_locat'] as int;
    final locationName = location['lugar_fisico'] ?? 'No name';
    final controller = _controllers[locationId];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            // Icono
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2B5F8C).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.place,
                color: Color(0xFF2B5F8C),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),

            // Nombre de ubicación
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    locationName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (location['coordenadas'] != null)
                    Text(
                      InventoryService.formatCoordinates(location['coordenadas']),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                ],
              ),
            ),

            // Campo de cantidad
            SizedBox(
              width: 80,
              child: TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  suffixText: 'uds',
                  suffixStyle: const TextStyle(fontSize: 10),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(5),
                ],
                onChanged: (value) {
                  final quantity = int.tryParse(value) ?? 0;
                  _updateDistribution(locationId, quantity);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyLocations() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Column(
        children: [
          Icon(Icons.location_off, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(
            'No locations available',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea ubicaciones primero para distribuir el stock',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showDistributionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info, color: Color(0xFF2B5F8C)),
            SizedBox(width: 8),
            Text('Stock Distribution'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'What is stock distribution?',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'It lets you specify how many units of the product will be '
                    'available at each location or branch.',
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              Text(
                'Ejemplo:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                '• Total: 100 units\n'
                    '• Central Warehouse: 60 units\n'
                    '• Sucursal Norte: 25 unidades\n'
                    '• Sucursal Sur: 15 unidades',
                style: TextStyle(fontSize: 12),
              ),
              SizedBox(height: 16),
              Text(
                '✓ The sum must equal the total',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B8E3D),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5F8C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }
}