import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../screens/login_screen.dart';
import '../screens/home_screen.dart';
import 'mia_logo.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  late final Stream<AuthState> _authStream;

  @override
  void initState() {
    super.initState();
    _authStream = AuthService.authStateChanges;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authStream,
      builder: (context, snapshot) {
        // Mientras se carga el estado de autenticación
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const AuthLoadingScreen();
        }

        // Si hay un usuario autenticado
        if (snapshot.hasData && snapshot.data!.session?.user != null) {
          final user = snapshot.data!.session!.user;

          // Verificar si el email está confirmado
          if (user.emailConfirmedAt != null) {
            return const HomeScreen();
          } else {
            return const EmailVerificationScreen();
          }
        }

        // Si no hay usuario autenticado
        return const LoginScreen();
      },
    );
  }
}

class AuthLoadingScreen extends StatelessWidget {
  const AuthLoadingScreen({super.key});

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
            ],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MIALogo(
                width: 120,
                height: 120,
                showBackground: true,
                backgroundColor: Colors.white,
                borderRadius: 20,
              ),
              SizedBox(height: 30),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF6B8E3D)),
                strokeWidth: 3,
              ),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF2B5F8C),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await AuthService.signOut();
                // No necesitamos navegar manualmente porque el StreamBuilder se encargará
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error signing out: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Sign Out',
              style: TextStyle(color: Color(0xFF2B5F8C)),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const MIALogo(
              width: 100,
              height: 100,
              showBackground: true,
              backgroundColor: Colors.white,
              borderRadius: 20,
            ),
            const SizedBox(height: 30),
            const Icon(
              Icons.mark_email_unread,
              size: 80,
              color: Color(0xFF6B8E3D),
            ),
            const SizedBox(height: 20),
            const Text(
              'Verify Your Email',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 15),
            Text(
              'We sent a verification link to:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              user?.email ?? '',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2B5F8C),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Please check your email and click the verification link to continue.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  try {
                    await AuthService.resetPassword(user?.email ?? '');
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Verification email sent again!'),
                          backgroundColor: Color(0xFF6B8E3D),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B8E3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  'Resend Verification Email',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Refresh para verificar si ya se confirmó el email
                final currentUser = AuthService.currentUser;
                if (currentUser?.emailConfirmedAt != null && context.mounted) {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              child: const Text(
                'I\'ve verified my email',
                style: TextStyle(
                  color: Color(0xFF2B5F8C),
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}