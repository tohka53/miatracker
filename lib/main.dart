import 'package:flutter/material.dart';
import 'login_screen.dart'; // Importar la pantalla de login separada

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'M.I.A Tracker',
      theme: ThemeData(
        // Colores actualizados para coincidir completamente con el logo
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2B5F8C), // Azul principal del logo
          primary: const Color(0xFF2B5F8C), // Azul principal
          secondary: const Color(0xFF6B8E3D), // Verde del logo
          surface: const Color(0xFFF5F3E8), // Fondo beige claro
          onSurface: const Color(0xFF2B5F8C), // Texto sobre superficies beige
          surfaceVariant: const Color(0xFFE8E5D6), // Beige medio
          onSurfaceVariant: const Color(0xFF6B8E3D), // Texto sobre beige medio
        ),
        // Configuración adicional para usar los colores beige
        scaffoldBackgroundColor: const Color(0xFFF5F3E8), // Fondo beige por defecto
        cardColor: const Color(0xFFE8E5D6), // Tarjetas en beige medio
        useMaterial3: true,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
      },
    );
  }
}

// Widget reutilizable para el logo
class MIALogo extends StatelessWidget {
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showBackground;
  final Color? backgroundColor;
  final double borderRadius;
  final Widget? fallbackIcon;

  const MIALogo({
    super.key,
    this.width = 80,
    this.height = 80,
    this.fit = BoxFit.contain,
    this.showBackground = false,
    this.backgroundColor,
    this.borderRadius = 10,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    Widget logoImage = Image.asset(
      'assets/images/logomiatrackersf.png', // Tu logo actualizado
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return fallbackIcon ??
            Icon(
              Icons.assignment_turned_in_outlined,
              size: width! * 1,
              color: const Color(0xFF2B5F8C),
            );
      },
    );

    if (showBackground) {
      return Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.1),
              spreadRadius: 1,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: logoImage,
      );
    }

    return logoImage;
  }
}

// Pantalla de bienvenida/splash
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navegar al login después de 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Gradiente actualizado para combinar con el logo
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
            stops: [0.0, 0.7, 1.0], // Control de donde cambian los colores
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo más grande y sin fondo para que se integre mejor
              const MIALogo(
                width: 200, // Más grande
                height: 200, // Más grande
                showBackground: false, // Sin fondo para integrarse mejor
              ),
              const SizedBox(height: 40),
              Text(
                'M.I.A TRACKER',
                style: TextStyle(
                  fontSize: 36, // Texto también más grande
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2B5F8C), // Azul del logo
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
                'Maintenance Inventory Asset Tracker',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B8E3D), // Verde del logo
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 50),
              // Indicador de carga con los colores del logo
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      spreadRadius: 1,
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Column(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8E3D)), // Verde del logo
                      strokeWidth: 3,
                    ),
                    SizedBox(height: 15),
                    Text(
                      'Loading...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF2B5F8C), // Azul del logo
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// PANTALLA PRINCIPAL DESPUÉS DEL LOGIN
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            // Logo pequeño en el AppBar
            MIALogo(
              width: 36,
              height: 36,
            ),
            SizedBox(width: 12),
            Text(
              'M.I.A Tracker',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2B5F8C), // Azul del logo
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF5F3E8), // Fondo beige claro
              Color(0xFFE8E5D6), // Beige medio
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo principal en el home
              const MIALogo(
                width: 100,
                height: 100,
                showBackground: true,
              ),
              const SizedBox(height: 30),
              const Text(
                'Welcome to M.I.A Tracker!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C), // Azul del logo
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Inventory and maintenance management system',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF6B8E3D), // Verde del logo
                ),
              ),
              const SizedBox(height: 40),
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Inventory module coming soon'),
                          backgroundColor: Color(0xFF6B8E3D),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B5F8C), // Azul principal
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.inventory),
                    label: const Text('Inventory'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Maintenance module coming soon'),
                          backgroundColor: Color(0xFF6B8E3D),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6B8E3D), // Verde del logo
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    icon: const Icon(Icons.build),
                    label: const Text('Maintenance'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}