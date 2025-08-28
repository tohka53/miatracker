import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/auth_wrapper.dart';
import 'widgets/mia_logo.dart';
import 'widgets/drawer_scaffold.dart'; // Import the new drawer scaffold

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar Supabase
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
      theme: ThemeData(
        // Colores actualizados para coincidir con el logo
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B5F8C), // Azul principal del logo
          primary: const Color(0xFF2B5F8C), // Azul principal
          secondary: const Color(0xFF6B8E3D), // Verde del logo
          surface: const Color(0xFFF5F3E8), // Fondo beige claro
          onSurface: const Color(0xFF2B5F8C), // Texto sobre superficies beige
          outline: const Color(0xFFE8E5D6), // Beige medio como outline
        ),
        // Configuración adicional para usar los colores beige
        scaffoldBackgroundColor: const Color(0xFFF5F3E8), // Fondo beige por defecto
        cardColor: const Color(0xFFE8E5D6), // Tarjetas en beige medio
        useMaterial3: true,

        // Configuración de AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF2B5F8C),
          foregroundColor: Colors.white,
          elevation: 2,
          centerTitle: true,
        ),

        // Configuración de botones
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),

        // Configuración de campos de texto
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

        // Configuración de FloatingActionButton
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: Color(0xFF6B8E3D),
          foregroundColor: Colors.white,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/auth': (context) => const AuthWrapper(),
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/inventory': (context) => const ExampleInventoryScreen(),
        // Aquí puedes agregar más rutas para otras pantallas
      },
    );
  }
}

// Pantalla de bienvenida/splash mejorada
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

    // Configurar animaciones
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _logoScale = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_fadeController);

    // Iniciar animaciones
    _logoController.forward();
    _fadeController.forward();

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Mostrar mensaje de conexión
      setState(() {
        _loadingMessage = 'Connecting to database...';
      });

      // Esperar un momento para que el usuario vea las animaciones
      await Future.delayed(const Duration(seconds: 2));

      // Verificar conexión a Supabase
      final isConnected = await _testSupabaseConnection();

      setState(() {
        _isConnected = isConnected;
        _loadingMessage = isConnected
            ? 'Connected successfully!'
            : 'Connected in offline mode';
      });

      // Esperar un momento más
      await Future.delayed(const Duration(seconds: 1));

      if (mounted) {
        // Navegar al wrapper de autenticación que manejará el estado
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

      if (kDebugMode) {
        print('Error during initialization: $e');
      }

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

  Future<bool> _testSupabaseConnection() async {
    try {
      // Intentar una consulta simple para verificar la conexión
      await Supabase.instance.client
          .from('profiles')
          .select('id')
          .limit(1);
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('Connection test failed: $e');
      }
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
              Color(0xFFF5F3E8), // Beige claro similar al fondo del logo
              Color(0xFFE8E5D6), // Beige un poco más oscuro
              Color(0xFF2B5F8C), // Azul del logo en la parte inferior
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
                  // Logo animado
                  ScaleTransition(
                    scale: _logoScale,
                    child: const MIALogo(
                      width: 200,
                      height: 200,
                      showBackground: false,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Título principal
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
                          color: Colors.black.withOpacity(0.2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtítulo
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

                  // Contenedor de estado
                  Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        // Icono de estado
                        if (_hasError)
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 36,
                          )
                        else if (_isConnected)
                          const Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF6B8E3D),
                            size: 36,
                          )
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

                        // Mensaje de estado
                        Text(
                          _loadingMessage,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF2B5F8C),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // Estado de Supabase
                        if (_isConnected) ...[
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_done_rounded,
                                color: Color(0xFF6B8E3D),
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Database Ready',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF6B8E3D),
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ] else if (_hasError) ...[
                          const SizedBox(height: 8),
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                color: Colors.orange,
                                size: 16,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Offline Mode',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Información de versión
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.7),
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
}