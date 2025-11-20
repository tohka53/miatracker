  // lib/screens/home_screen.dart
  // VERSIÓN OPTIMIZADA - Sin carga pesada de inventario

  import 'package:flutter/material.dart';
  import 'package:mobile_scanner/mobile_scanner.dart';
  import '../services/auth_service.dart';
  import '../services/inventory_service.dart';
  import '../services/cart_service.dart';
  import '../services/low_stock_alert_service.dart';
  import '../widgets/base_screen.dart';
  import '../widgets/low_stock_alerts_widget.dart';
  import '../screens/shopping_cart_screen.dart';
  import '../widgets/scanned_product_dialog_with_cart.dart';

  class HomeScreen extends StatefulWidget {
    const HomeScreen({super.key});

    @override
    State<HomeScreen> createState() => _HomeScreenState();
  }

  class _HomeScreenState extends State<HomeScreen> {
    Map<String, dynamic>? _stats;
    bool _isLoading = true;
    String? _errorMessage;
    final CartService _cartService = CartService();
    String _userRole = 'user';

    @override
    void initState() {
      super.initState();
      _loadLightData(); // ✅ Solo carga datos ligeros
      _cartService.addListener(_onCartChanged);
    }

    @override
    void dispose() {
      _cartService.removeListener(_onCartChanged);
      super.dispose();
    }

    void _onCartChanged() {
      if (mounted) setState(() {});
    }

    // ========================================================================
    // ✅ OPTIMIZACIÓN: Solo carga estadísticas (SIN inventario completo)
    // ========================================================================
    Future<void> _loadLightData() async {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        // 1. Cargar solo estadísticas (muy rápido)
        final stats = await InventoryService.getFilterCounts(); // ← Solo contadores

        // 2. Obtener rol del usuario
        final profile = await AuthService.getUserProfile();
        final role = profile?['role'] ?? 'user';

        if (mounted) {
          setState(() {
            _stats = {
              'total_productos': stats['all'] ?? 0,
              'productos_activos': stats['all'] ?? 0,
              'productos_sin_stock': stats['out_of_stock'] ?? 0,
              'productos_stock_bajo': stats['low_stock'] ?? 0,
            };
            _userRole = role;
            _isLoading = false;
          });
        }

        // 3. Procesar alertas en background (sin bloquear UI)
        if (_isAdminOrSupervisor) {
          _processAlertsInBackground();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Error al cargar datos: $e';
          });
        }
      }
    }

    // ========================================================================
    // ✅ OPTIMIZACIÓN: Procesar alertas en background sin bloquear
    // ========================================================================
    Future<void> _processAlertsInBackground() async {
      try {
        // Esto se ejecuta sin await para no bloquear
        LowStockAlertService.processPendingAlerts().then((_) {
          debugPrint('✅ Alertas procesadas en background');
        }).catchError((e) {
          debugPrint('⚠️ Error procesando alertas: $e');
        });
      } catch (e) {
        debugPrint('Error en background alerts: $e');
      }
    }

    bool get _isAdminOrSupervisor {
      return _userRole == 'admin' || _userRole == 'supervisor';
    }

    @override
    Widget build(BuildContext context) {
      return BaseScreen(
        currentRoute: '/home',
        title: 'Home',
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _showScanner,
            tooltip: 'Scan Code',
          ),
          _buildCartButton(),
        ],
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
            ? _buildErrorState()
            : _buildDashboard(),
      );
    }

    Widget _buildCartButton() {
      return Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.shopping_cart_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const ShoppingCartScreen()),
              );
            },
            tooltip: 'View Cart',
          ),
          if (_cartService.totalItems > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B8E3D),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  _cartService.totalItems > 99
                      ? '99+'
                      : '${_cartService.totalItems}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      );
    }

    Widget _buildErrorState() {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadLightData,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    Widget _buildDashboard() {
      return RefreshIndicator(
        onRefresh: () async {
          await _loadLightData();
          if (_isAdminOrSupervisor) {
            await _processAlertsInBackground();
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildUserWelcome(),
            const SizedBox(height: 16),
            _buildConnectionStatus(),
            const SizedBox(height: 24),
            _buildQuickActions(),

            if (_isAdminOrSupervisor) ...[
              const SizedBox(height: 24),
              LowStockAlertsWidget(
                onViewAll: () {
                  Navigator.pushReplacementNamed(context, '/inventory');
                },
              ),
            ],

            const SizedBox(height: 24),
            _buildStatsSection(),
          ],
        ),
      );
    }

    Widget _buildUserWelcome() {
      final user = AuthService.currentUser;
      final email = user?.email ?? 'User';
      final fullName = user?.userMetadata?['full_name'] ?? 'User';

      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2B5F8C), Color(0xFF6B8E3D)],
            ),
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.3),
                child: Text(
                  fullName.isNotEmpty ? fullName[0].toUpperCase() : 'U',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Welcome back!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      email,
                      style: const TextStyle(fontSize: 12, color: Colors.white60),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget _buildConnectionStatus() {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Color(0xFF6B8E3D),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Connected to MIA Tracker',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B8E3D),
                  ),
                ),
              ),
              const Icon(Icons.cloud_done, color: Color(0xFF6B8E3D), size: 20),
            ],
          ),
        ),
      );
    }

    Widget _buildQuickActions() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: const Color(0xFF2B5F8C),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildQuickActionCard(
                  'Inventory',
                  Icons.inventory_2_outlined,
                  const Color(0xFF2B5F8C),
                      () => Navigator.pushReplacementNamed(context, '/inventory'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Add Product',
                  Icons.add_circle_outline,
                  const Color(0xFF6B8E3D),
                      () => Navigator.pushReplacementNamed(context, '/inventory'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionCard(
                  'Scan Code',
                  Icons.qr_code_scanner_outlined,
                  Colors.blueAccent,
                  _showScanner,
                ),
              ),
            ],
          ),

          if (_isAdminOrSupervisor) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    'Restock',
                    Icons.add_box_outlined,
                    Colors.orange,
                        () => Navigator.pushReplacementNamed(
                        context, '/restock-management'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    'Complete Order',
                    Icons.qr_code_2,
                    const Color(0xFF10B981),
                        () => Navigator.pushNamed(context, '/qr-complete-order'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    'Reports',
                    Icons.analytics_outlined,
                    Colors.purple,
                        () =>
                        Navigator.pushReplacementNamed(context, '/reports'),
                  ),
                ),
              ],
            ),
          ],
        ],
      );
    }

    Widget _buildQuickActionCard(
        String label,
        IconData icon,
        Color color,
        VoidCallback onTap,
        ) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }

    Widget _buildStatsSection() {
      if (_stats == null) {
        return const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Inventory Overview',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: const Color(0xFF2B5F8C),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Products',
                  '${_stats!['total_productos'] ?? 0}',
                  Icons.inventory,
                  const Color(0xFF2B5F8C),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Active',
                  '${_stats!['productos_activos'] ?? 0}',
                  Icons.check_circle_outline,
                  const Color(0xFF6B8E3D),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Out of Stock',
                  '${_stats!['productos_sin_stock'] ?? 0}',
                  Icons.warning_amber_outlined,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Low Stock',
                  '${_stats!['productos_stock_bajo'] ?? 0}',
                  Icons.trending_down,
                  Colors.orange,
                ),
              ),
            ],
          ),
        ],
      );
    }

    Widget _buildStatCard(
        String label, String value, IconData icon, Color color) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // ========================================================================
    // SCANNER Y MANEJO DE CÓDIGOS
    // ========================================================================

    void _showScanner() {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: _ScannerDialog(
              onCodeDetected: (String code) {
                Navigator.pop(context);
                _handleScannedCode(code);
              },
            ),
          );
        },
      );
    }

    void _handleScannedCode(String code) async {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final item = await InventoryService.getItemByQRCode(code);

        if (!mounted) return;
        Navigator.pop(context);

        if (item != null) {
          _showScannedItemDialog(item);
        } else {
          final results =
          await InventoryService.searchByBarcode({'barcode_data': code});

          if (results.isNotEmpty) {
            _showScannedItemDialog(results.first);
          } else {
            _showCodeNotFoundDialog(code);
          }
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error processing code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    void _showScannedItemDialog(Map<String, dynamic> item) {
      showScannedProductDialogWithCart(
        context,
        item,
        onEdit: () {
          Navigator.pushReplacementNamed(context, '/inventory');
        },
        onCartUpdated: () {
          _loadLightData();
        },
      );
    }

    void _showCodeNotFoundDialog(String code) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.orange),
              SizedBox(width: 10),
              Text('Product Not Found'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No product found with this code:'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  code,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/inventory');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
              ),
              child: const Text('Go to Inventory'),
            ),
          ],
        ),
      );
    }
  }

  // ============================================================================
  // SCANNER DIALOG WIDGET
  // ============================================================================

  class _ScannerDialog extends StatefulWidget {
    final Function(String) onCodeDetected;

    const _ScannerDialog({required this.onCodeDetected});

    @override
    State<_ScannerDialog> createState() => _ScannerDialogState();
  }

  class _ScannerDialogState extends State<_ScannerDialog> {
    MobileScannerController? _controller;

    @override
    void initState() {
      super.initState();
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.noDuplicates,
      );
    }

    @override
    void dispose() {
      _controller?.dispose();
      super.dispose();
    }

    @override
    Widget build(BuildContext context) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scan Code',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2B5F8C),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2B5F8C), width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: MobileScanner(
                controller: _controller,
                onDetect: (BarcodeCapture capture) {
                  final List<Barcode> barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty) {
                    final String? code = barcodes.first.rawValue;
                    if (code != null && code.isNotEmpty) {
                      widget.onCodeDetected(code);
                    }
                  }
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Position the code within the frame',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }
  }