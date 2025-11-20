// lib/screens/restock_management_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/email_service.dart';
import '../services/restock_service.dart';
import '../services/profile_service.dart';
import '../widgets/base_screen.dart';
import '../widgets/supplier_selection_dialog.dart';
import '../widgets/reject_restock_dialog.dart';
import '../services/restock_approval_service.dart';
import '../screens/qr_complete_order_screen.dart'; // 🔥 IMPORTAR

class RestockManagementScreen extends StatefulWidget {
  const RestockManagementScreen({super.key});

  @override
  State<RestockManagementScreen> createState() =>
      _RestockManagementScreenState();
}

class _RestockManagementScreenState extends State<RestockManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = false;
  bool _isAdmin = false;
  List<Map<String, dynamic>> _allRequests = [];
  Map<String, dynamic> _stats = {};

  String? _filterStatus;
  String? _filterPriority;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _checkAdminAndLoad();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAndLoad() async {
    setState(() => _isLoading = true);
    try {
      final isAdmin = await ProfileService.isUserAdmin();
      setState(() => _isAdmin = isAdmin);
      await _loadData();
    } catch (e) {
      _showErrorSnackBar('Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadData() async {
    try {
      final requests = await RestockService.getAllRequests(
        status: _filterStatus,
        priority: _filterPriority,
      );
      final stats = await RestockService.getRestockStats();

      if (mounted) {
        setState(() {
          _allRequests = requests;
          _stats = stats;
        });
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error loading data: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScreen(
      currentRoute: '/restock-management',
      title: 'Restock Requests',
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterDialog,
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
        ),
      ],
      child: Column(
        children: [
          Container(
            color: const Color(0xFF2B5F8C),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              isScrollable: true,
              tabs: const [
                Tab(icon: Icon(Icons.pending), text: 'Pending'),
                Tab(icon: Icon(Icons.check_circle), text: 'Approved'),
                Tab(icon: Icon(Icons.done_all), text: 'Completed'),
                Tab(icon: Icon(Icons.list), text: 'All'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
              onRefresh: _loadData,
              child: Column(
                children: [
                  if (_isAdmin) _buildAdminStatsCard(),
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildRequestsList('pending'),
                        _buildRequestsList('approved'),
                        _buildRequestsList('completed'),
                        _buildRequestsList(null),
                      ],
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

  Widget _buildAdminStatsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings,
                  color: Color(0xFF2B5F8C), size: 24),
              SizedBox(width: 8),
              Text(
                'Administrator Panel',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Pending',
                _stats['pending']?.toString() ?? '0',
                Icons.pending,
                const Color(0xFFF59E0B),
              ),
              _buildStatItem(
                'Approved',
                _stats['approved']?.toString() ?? '0',
                Icons.check_circle,
                const Color(0xFF3B82F6),
              ),
              _buildStatItem(
                'Urgent',
                _stats['urgent']?.toString() ?? '0',
                Icons.priority_high,
                const Color(0xFFEF4444),
              ),
              _buildStatItem(
                'Completed',
                _stats['completed']?.toString() ?? '0',
                Icons.done_all,
                const Color(0xFF6B8E3D),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildRequestsList(String? status) {
    final filteredRequests = status == null
        ? _allRequests
        : _allRequests.where((r) => r['status'] == status).toList();

    if (filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No requests found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return _buildRequestCard(request);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final status = request['status'] as String?;
    final priority = request['priority'] as String?;
    final statusColor =
    Color(int.parse(RestockService.getStatusColor(status).substring(1), radix: 16) +
        0xFF000000);
    final priorityColor = Color(
        int.parse(RestockService.getPriorityColor(priority).substring(1), radix: 16) +
            0xFF000000);

    final inventario = request['inventario'] as Map<String, dynamic>?;
    final nombreProducto = inventario?['nombre_producto'] ?? 'Unknown Product';
    final stockActual = request['stock_actual'] ?? 0;
    final cantidadSolicitada = request['cantidad_solicitada'] ?? 0;

    final usuario = request['profiles'] as Map<String, dynamic>?;
    final nombreUsuario = usuario?['full_name'] ?? 'User';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(color: statusColor.withOpacity(0.3), width: 2),
      ),
      child: InkWell(
        onTap: () => _showRequestDetails(request),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_getStatusIcon(status),
                            size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          RestockService.getStatusText(status),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag, size: 14, color: priorityColor),
                        const SizedBox(width: 4),
                        Text(
                          RestockService.getPriorityText(priority),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: priorityColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  if (inventario?['imagen'] != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        inventario!['imagen'],
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey[300],
                              child: const Icon(Icons.image_not_supported),
                            ),
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombreProducto,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Requested by: $nombreUsuario',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Divider(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInfoColumn(
                    'Current',
                    stockActual.toString(),
                    Icons.inventory,
                    Colors.grey,
                  ),
                  _buildInfoColumn(
                    'Requested',
                    cantidadSolicitada.toString(),
                    Icons.add_shopping_cart,
                    const Color(0xFF3B82F6),
                  ),
                  _buildInfoColumn(
                    'Projected',
                    (stockActual + cantidadSolicitada).toString(),
                    Icons.trending_up,
                    const Color(0xFF6B8E3D),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(request['fecha_solicitud']),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),

              // 🔥 BOTONES DE ADMIN - PENDING
              if (_isAdmin && status == 'pending') ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showRejectDialog(request),
                        icon: const Icon(Icons.cancel, size: 18),
                        label: const Text('Decline'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showApproveDialog(request),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Approve'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6B8E3D),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              // 🔥 BOTONES DE ADMIN - APPROVED (TEST + SCAN QR)
              if (_isAdmin && status == 'approved') ...[
                const Divider(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCompleteDialog(request),
                        icon: const Icon(Icons.done_all, size: 18),
                        label: const Text('Complete (Test)'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF3B82F6),
                          side: const BorderSide(color: Color(0xFF3B82F6)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _navigateToQRScanner(request['id']),
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('Scan QR'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
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
      ),
    );
  }

  // 🔥 NAVEGAR AL SCANNER CON REQUEST_ID
  void _navigateToQRScanner(int requestId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QRCompleteOrderScreen(requestId: requestId),
      ),
    ).then((completed) {
      if (completed == true) {
        _loadData(); // Recargar si se completó
      }
    });
  }

  Widget _buildInfoColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  void _showRequestDetails(Map<String, dynamic> request) {
    final inventario = request['inventario'] as Map<String, dynamic>?;
    final supplier = request['supply_company'] as Map<String, dynamic>?;
    final usuario = request['profiles'] as Map<String, dynamic>?;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Product', inventario?['nombre_producto'] ?? 'N/A'),
              _buildDetailRow('Requested by', usuario?['full_name'] ?? 'N/A'),
              _buildDetailRow('Email', usuario?['email'] ?? 'N/A'),
              if (supplier != null) ...[
                const Divider(),
                _buildDetailRow('Supplier', supplier['name'] ?? 'N/A'),
                _buildDetailRow('Supplier Phone', supplier['phone'] ?? 'N/A'),
              ],
              const Divider(),
              _buildDetailRow('Current Stock', request['stock_actual'].toString()),
              _buildDetailRow(
                  'Requested Quantity', request['cantidad_solicitada'].toString()),
              _buildDetailRow('Priority',
                  RestockService.getPriorityText(request['priority'])),
              if (request['notes'] != null) ...[
                const Divider(),
                const Text('Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(request['notes']),
              ],
              if (request['internal_notes'] != null) ...[
                const Divider(),
                const Text('Internal Notes:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(request['internal_notes']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
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
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(Map<String, dynamic> request) {
    final notesController = TextEditingController();
    DateTime? estimatedDeliveryDate;
    Map<String, dynamic>? selectedSupplier;

    final inventario = request['inventario'] as Map<String, dynamic>?;
    final nombreProducto = inventario?['nombre_producto'] ?? 'Unknown Product';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Color(0xFF6B8E3D)),
              SizedBox(width: 12),
              Text('Approve Request'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Confirm restock approval for "$nombreProducto"?',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),

                const SizedBox(height: 20),

                Text(
                  'Supplier *',
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
                          : 'Select Supplier',
                      style: TextStyle(
                        fontWeight: selectedSupplier != null ? FontWeight.bold : FontWeight.normal,
                        color: selectedSupplier == null ? Colors.red : null,
                      ),
                    ),
                    subtitle: selectedSupplier != null && selectedSupplier!['email'] != null
                        ? Text(selectedSupplier!['email'], style: const TextStyle(fontSize: 12))
                        : const Text(
                      'Required to send notification',
                      style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                    trailing: selectedSupplier != null
                        ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () => setState(() => selectedSupplier = null),
                    )
                        : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.red),
                    onTap: () async {
                      final supplier = await showSupplierSelectionDialog(
                        context,
                        currentSupplierId: selectedSupplier?['id'],
                        productName: nombreProducto,
                      );
                      if (supplier != null) {
                        setState(() => selectedSupplier = supplier);
                      }
                    },
                  ),
                ),

                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 16),

                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Internal notes (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Team observations',
                    prefixIcon: Icon(Icons.notes),
                  ),
                  maxLines: 3,
                ),

                const SizedBox(height: 16),

                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_shipping, color: Color(0xFF6B8E3D)),
                    title: const Text('Estimated delivery date'),
                    subtitle: Text(
                      estimatedDeliveryDate != null
                          ? DateFormat('dd/MM/yyyy').format(estimatedDeliveryDate!)
                          : 'Not specified (optional)',
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        estimatedDeliveryDate != null ? Icons.edit : Icons.add,
                        color: const Color(0xFF6B8E3D),
                      ),
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now().add(const Duration(days: 7)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() => estimatedDeliveryDate = date);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: selectedSupplier == null
                  ? null
                  : () async {
                Navigator.pop(context);
                await _approveRequestWithQR(
                  request['id'],
                  selectedSupplier!['id'],
                  notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  estimatedDeliveryDate,
                );
              },
              icon: const Icon(Icons.check_circle),
              label: const Text('Approve & Notify'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequestWithQR(
      int requestId,
      int supplierId,
      String? notes,
      DateTime? estimatedDeliveryDate) async {
    _showLoadingDialog();
    try {
      await RestockService.approveRequest(
        requestId: requestId,
        supplierId: supplierId,
        internalNotes: notes,
        estimatedDeliveryDate: estimatedDeliveryDate,
      );

      final qrData = 'miatracker://restock/complete/$requestId';

      await EmailService.sendApprovalEmailWithQR(
        requestId: requestId,
        supplierId: supplierId,
        deliveryDate: estimatedDeliveryDate,
        internalNotes: notes,
        qrData: qrData,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('✅ Request approved with QR code sent');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showRejectDialog(Map<String, dynamic> request) {
    final inventario = request['inventario'] as Map<String, dynamic>?;
    final nombreProducto = inventario?['nombre_producto'] ?? 'Unknown Product';

    showDialog(
      context: context,
      builder: (context) => RejectRestockDialog(
        requestId: request['id'],
        productName: nombreProducto,
        currentSupplierId: request['id_supply_company'],
        onReject: (requestId, reason, supplierId) async {
          Navigator.pop(context);
          await _rejectRequest(requestId, reason, supplierId);
        },
      ),
    );
  }

  void _showCompleteDialog(Map<String, dynamic> request) {
    final inventario = request['inventario'] as Map<String, dynamic>?;
    final nombreProducto = inventario?['nombre_producto'] ?? 'Unknown Product';
    final stockActual = request['stock_actual'] ?? 0;
    final cantidadSolicitada = request['cantidad_solicitada'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Complete Restock'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '⚠️ TEST MODE',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFF59E0B),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This will simulate that the supplier confirmed delivery and will update the inventory.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product: $nombreProducto',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Current stock: $stockActual'),
                  Text('Quantity to add: $cantidadSolicitada'),
                  const Divider(),
                  Text(
                    'New stock: ${stockActual + cantidadSolicitada}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B8E3D),
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
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _completeRestock(request['id']);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }

  Future<void> _approveRequest(
      int requestId,
      int supplierId,
      String? notes,
      DateTime? estimatedDate) async {
    _showLoadingDialog();
    try {
      await RestockService.approveRequest(
        requestId: requestId,
        supplierId: supplierId,
        internalNotes: notes,
        estimatedDeliveryDate: estimatedDate,
      );
      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('✅ Request approved and supplier notified');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  Future<void> _rejectRequest(int requestId, String reason, int? supplierId) async {
    _showLoadingDialog();
    try {
      await RestockApprovalService.rejectRequest(
        requestId: requestId,
        reason: reason,
        supplierId: supplierId,
      );

      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('❌ Request rejected');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  Future<void> _completeRestock(int requestId) async {
    _showLoadingDialog();
    try {
      await RestockService.completeRestockAndUpdateInventory(
          requestId: requestId);
      if (mounted) {
        Navigator.pop(context);
        _showSuccessSnackBar('✅ Restock completed and inventory updated');
        await _loadData();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        _showErrorSnackBar('Error: $e');
      }
    }
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filters'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: _filterStatus,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                setState(() => _filterStatus = value);
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _filterPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'low', child: Text('Low')),
                DropdownMenuItem(value: 'normal', child: Text('Normal')),
                DropdownMenuItem(value: 'high', child: Text('High')),
                DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
              ],
              onChanged: (value) {
                setState(() => _filterPriority = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterStatus = null;
                _filterPriority = null;
              });
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Clear'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  IconData _getStatusIcon(String? status) {
    switch (status) {
      case 'pending':
        return Icons.pending;
      case 'approved':
        return Icons.check_circle;
      case 'rejected':
        return Icons.cancel;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.block;
      default:
        return Icons.help;
    }
  }

  String _formatDate(dynamic date) {
    if (date == null) return 'N/A';
    try {
      final dateTime = DateTime.parse(date.toString());
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return 'Invalid date';
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF6B8E3D),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}