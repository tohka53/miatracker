// lib/screens/restock_requests_screen.dart
// EJEMPLO DE PANTALLA DE RESTOCK CON MANEJO ROBUSTO DE ERRORES

import 'package:flutter/material.dart';
import '../services/restock_service.dart';

class RestockRequestsScreen extends StatefulWidget {
  const RestockRequestsScreen({Key? key}) : super(key: key);

  @override
  State<RestockRequestsScreen> createState() => _RestockRequestsScreenState();
}

class _RestockRequestsScreenState extends State<RestockRequestsScreen> {
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('🔄 UI: Cargando solicitudes de restock...');

      List<Map<String, dynamic>> requests;

      // Aplicar filtro
      switch (_selectedFilter) {
        case 'pending':
          requests = await RestockService.getPendingRequests();
          break;
        case 'approved':
          requests = await RestockService.getApprovedRequests();
          break;
        case 'all':
        default:
          requests = await RestockService.getAllRequests();
      }

      print('✅ UI: Solicitudes cargadas exitosamente: ${requests.length}');

      setState(() {
        _requests = requests;
        _isLoading = false;
      });

    } catch (e, stackTrace) {
      print('❌ UI ERROR: $e');
      print('Stack trace: $stackTrace');

      setState(() {
        _errorMessage = 'Error al cargar solicitudes: ${e.toString()}';
        _isLoading = false;
      });

      // Mostrar SnackBar con el error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _loadRequests,
            ),
          ),
        );
      }
    }
  }

  Color _parseColor(String colorHex) {
    final hex = colorHex.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes de Restock'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
            tooltip: 'Recargar',
          ),
        ],
      ),
      body: Column(
        children: [
          // FILTROS
          _buildFilterChips(),

          // CONTENIDO PRINCIPAL
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Navegar a pantalla de crear solicitud
          print('Crear nueva solicitud');
        },
        child: const Icon(Icons.add),
        tooltip: 'Nueva Solicitud',
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Todas', 'all'),
            const SizedBox(width: 8),
            _buildFilterChip('Pendientes', 'pending'),
            const SizedBox(width: 8),
            _buildFilterChip('Aprobadas', 'approved'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFilter = value;
          });
          _loadRequests();
        }
      },
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
    );
  }

  Widget _buildContent() {
    // ESTADO: CARGANDO
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              'Cargando solicitudes...',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // ESTADO: ERROR
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error al cargar',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.red[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadRequests,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  // Mostrar diálogo con ayuda de debugging
                  _showDebuggingHelp();
                },
                child: const Text('Ver guía de solución'),
              ),
            ],
          ),
        ),
      );
    }

    // ESTADO: VACÍO
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No hay solicitudes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedFilter == 'all'
                  ? 'Aún no hay solicitudes de restock'
                  : 'No hay solicitudes ${_selectedFilter == "pending" ? "pendientes" : "aprobadas"}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Navegar a crear solicitud
                print('Crear nueva solicitud');
              },
              icon: const Icon(Icons.add),
              label: const Text('Crear Solicitud'),
            ),
          ],
        ),
      );
    }

    // ESTADO: CON DATOS
    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          return _buildRequestCard(_requests[index]);
        },
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String?;
    final priority = request['priority'] as String?;

    // Intentar obtener datos del inventario
    final inventario = request['inventario'];
    final nombreProducto = inventario is Map
        ? (inventario['nombre_producto'] as String? ?? 'Producto sin nombre')
        : 'Producto sin nombre';

    final cantidad = request['cantidad_solicitada'] as int? ?? 0;

    final statusColor = _parseColor(RestockService.getStatusColor(status));
    final priorityColor = _parseColor(RestockService.getPriorityColor(priority));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          // TODO: Navegar a detalle
          print('Ver detalle de solicitud ${request['id']}');
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER
              Row(
                children: [
                  // Ícono del producto
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.inventory_2_outlined,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Info del producto
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreProducto,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Cantidad: $cantidad unidades',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // BADGES
              Row(
                children: [
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      RestockService.getStatusText(status),
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Priority Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      RestockService.getPriorityText(priority),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // FECHA
              if (request['fecha_solicitud'] != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(request['fecha_solicitud']),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
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

  String _formatDate(dynamic date) {
    try {
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (e) {
      return 'Fecha no disponible';
    }
  }

  void _showDebuggingHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Guía de Solución'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Si las solicitudes no cargan, verifica:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHelpItem('1', 'Los logs en la consola de Flutter'),
              _buildHelpItem('2', 'Que RLS esté configurado en Supabase'),
              _buildHelpItem('3', 'Que existan foreign keys correctas'),
              _buildHelpItem('4', 'Tu id_company en la tabla profiles'),
              const SizedBox(height: 12),
              Text(
                'Revisa el archivo RESTOCK_DEBUGGING_GUIDE.md para más detalles.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}