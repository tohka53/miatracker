import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:miatracker/screens/general_orders_screen.dart';
import 'package:miatracker/screens/qr_complete_order_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Config
import 'config/supabase_config.dart';

// Services
import 'services/auth_service.dart';

// Screens - Auth
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';

// Screens - Main
import 'screens/home_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/shopping_cart_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/orders_screen.dart';

// Screens - Suppliers
import 'screens/suppliers/supply_company_screen.dart';
import 'screens/suppliers/supplier_dashboard.dart';
import 'screens/suppliers/products_without_supplier_screen.dart';
import 'screens/restock_management_screen.dart';

// Screens - Reports
import 'screens/reports/inventory_reports_screen.dart';

// Screens - Marketplace (NUEVAS - necesitas crearlas)
import 'screens/marketplace/supply_marketplace_screen.dart';
import 'screens/marketplace/marketplace_cart_screen.dart';
import 'screens/marketplace/supplier_management_screen.dart';

// Screens - Settings
import 'screens/settings/company_settings_screen.dart';

// Widgets
import 'widgets/auth_wrapper.dart';
import 'widgets/mia_logo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: SupabaseConfig.enableLogging && kDebugMode,
    );

    if (kDebugMode) {
      print('✅ Supabase initialized successfully');
    }
  } catch (e) {
    if (kDebugMode) {
      print('❌ Error initializing Supabase: $e');
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M.I.A Tracker',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(),
      home: const SplashScreen(),
      routes: _buildRoutes(),
      onGenerateRoute: _handleDeepLinks,
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF2B5F8C),
        primary: const Color(0xFF2B5F8C),
        secondary: const Color(0xFF6B8E3D),
        surface: const Color(0xFFF5F3E8),
        onSurface: const Color(0xFF2B5F8C),
        outline: const Color(0xFFE8E5D6),
      ),
      scaffoldBackgroundColor: const Color(0xFFF5F3E8),
      cardColor: const Color(0xFFE8E5D6),
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF2B5F8C),
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Color(0xFF6B8E3D),
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 1,
          ),
        ),
      ),
    );
  }

  Map<String, WidgetBuilder> _buildRoutes() {
    return {
      // Auth Routes
      '/auth': (context) => const AuthWrapper(),
      '/login': (context) => const LoginScreen(),
      '/register': (context) => const RegisterScreen(),
      '/forgot-password': (context) => const ForgotPasswordScreen(),
      '/reset-password': (context) => const ResetPasswordScreen(),

      // Main Routes
      '/home': (context) => const HomeScreen(),
      '/inventory': (context) => const InventoryScreen(),
      '/cart': (context) => const ShoppingCartScreen(),
      '/transfers': (context) => const TransferScreen(),
      '/orders': (context) => const OrdersScreen(),
      '/general-orders': (context) => const GeneralOrdersScreen(),


      // Supplier Routes
      '/suppliers': (context) => const SupplyCompanyScreen(),
      '/suppliers/dashboard': (context) => const SupplierDashboard(),
      '/suppliers/products-without': (context) => const ProductsWithoutSupplierScreen(),

      // Report Routes
      '/reports': (context) => const InventoryReportsScreen(),

      // Marketplace Routes (NUEVAS)
      '/marketplace': (context) => const SupplyMarketplaceScreen(),
      '/marketplace-cart': (context) => const MarketplaceCartScreen(),
      '/supplier-management': (context) => const SupplierManagementScreen(),

      // Settings Routes
      '/company-settings': (context) => const CompanySettingsScreen(),
      '/restock-management': (context) => const RestockManagementScreen(),
      '/qr-complete-order': (context) => const QRCompleteOrderScreen(), // 🔥 NUEVO
    };
  }

  Route? _handleDeepLinks(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '');

    // Handle Supabase reset password deep links
    if (uri.scheme == 'io.supabase.miatracker' && uri.host == 'reset-password') {
      return MaterialPageRoute(
        builder: (context) => const ResetPasswordScreen(),
        settings: settings,
      );
    }

    // Handle recovery type in fragment
    if (uri.fragment.contains('access_token') &&
        uri.fragment.contains('type=recovery')) {
      return MaterialPageRoute(
        builder: (context) => const ResetPasswordScreen(),
        settings: settings,
      );
    }

    return null;
  }
}

// ==================== SPLASH SCREEN ====================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  String _loadingMessage = 'Initializing...';
  bool _isConnected = false;
  bool _hasError = false;
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late Animation<double> _logoScale;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeApp();
  }

  void _initAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(_fadeController);

    _logoController.forward();
    _fadeController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _loadingMessage = 'Connecting to database...');
      await Future.delayed(const Duration(seconds: 2));

      await _checkForDeepLinks();

      final isConnected = await _testSupabaseConnection();

      setState(() {
        _isConnected = isConnected;
        _loadingMessage = isConnected
            ? 'Connected successfully!'
            : 'Connected in offline mode';
      });

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _hasError = true;
        _loadingMessage = 'Starting in offline mode...';
      });

      if (kDebugMode) print('Error during initialization: $e');

      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => const AuthWrapper(),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    }
  }

  Future<void> _checkForDeepLinks() async {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ResetPasswordScreen()),
          );
        });
      }
    });
  }

  Future<bool> _testSupabaseConnection() async {
    try {
      await Supabase.instance.client.from('profiles').select('id').limit(1);
      return true;
    } catch (e) {
      if (kDebugMode) print('Connection test failed: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F3E8),
              Color(0xFFE8E5D6),
              Color(0xFF2B5F8C),
            ],
            stops: [0.0, 0.7, 1.0],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ScaleTransition(
                    scale: _logoScale,
                    child: const MIALogo(
                      width: 200,
                      height: 200,
                      showBackground: false,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'M.I.A TRACKER',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2B5F8C),
                      letterSpacing: 3.0,
                      shadows: [
                        Shadow(
                          offset: const Offset(0, 2),
                          blurRadius: 4,
                          color: Colors.black.withValues(alpha: 0.2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Maintenance • Inventory • Asset Tracker',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF6B8E3D),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 60),
                  _buildStatusCard(),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_hasError)
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 36)
          else if (_isConnected)
            const Icon(Icons.check_circle_rounded, color: Color(0xFF6B8E3D), size: 36)
          else
            const SizedBox(
              width: 36,
              height: 36,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8E3D)),
                strokeWidth: 3,
              ),
            ),
          const SizedBox(height: 16),
          Text(
            _loadingMessage,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2B5F8C),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isConnected) _buildStatusIndicator(true)
          else if (_hasError) _buildStatusIndicator(false),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(bool isConnected) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
            color: isConnected ? const Color(0xFF6B8E3D) : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Database Ready' : 'Offline Mode',
            style: TextStyle(
              fontSize: 14,
              color: isConnected ? const Color(0xFF6B8E3D) : Colors.orange,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}