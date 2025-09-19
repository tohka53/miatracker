import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // ← AGREGAR ESTA LÍNEA
import '../widgets/mia_logo.dart';
import '../services/auth_service.dart';
import '../utils/supabase_utils.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _passwordUpdated = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Criterios de seguridad de contraseña
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  bool _hasSpecialChar = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _passwordController.addListener(_checkPasswordCriteria);

    // Verificar si hay tokens de recuperación en el contexto
    _checkForRecoveryTokens();
  }

  void _checkForRecoveryTokens() {
    // Escuchar cambios de autenticación
    AuthService.authStateChanges.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        // Usuario está en modo de recuperación de contraseña
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Ready to reset your password!'),
              backgroundColor: Color(0xFF6B8E3D),
            ),
          );
        }
      }
    });
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _animationController.forward();
  }

  void _checkPasswordCriteria() {
    final password = _passwordController.text;
    setState(() {
      _hasMinLength = password.length >= 8;
      _hasUppercase = password.contains(RegExp(r'[A-Z]'));
      _hasLowercase = password.contains(RegExp(r'[a-z]'));
      _hasDigits = password.contains(RegExp(r'[0-9]'));
      _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool get _isPasswordStrong {
    return _hasMinLength &&
        _hasUppercase &&
        _hasLowercase &&
        _hasDigits;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3E8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF2B5F8C)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Reset Password',
          style: TextStyle(
            color: Color(0xFF2B5F8C),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Header
                  _buildHeader(),
                  const SizedBox(height: 40),

                  // Contenido principal
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 500),
                    child: _passwordUpdated ? _buildSuccessView() : _buildFormView(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Center(
          child: MIALogo(
            width: 100,
            height: 100,
            showBackground: true,
            backgroundColor: Colors.white,
            borderRadius: 20,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _passwordUpdated ? 'Password Updated!' : 'Create New Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _passwordUpdated
              ? 'Your password has been successfully updated'
              : 'Choose a strong password to secure your M.I.A Tracker account',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Campo de nueva contraseña
          _buildPasswordField(
            controller: _passwordController,
            labelText: 'New Password',
            obscureText: _obscurePassword,
            onToggleVisibility: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a new password';
              }
              if (!_isPasswordStrong) {
                return 'Password does not meet security requirements';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),

          // Indicadores de seguridad de contraseña
          _buildPasswordStrengthIndicator(),
          const SizedBox(height: 20),

          // Campo de confirmar contraseña
          _buildPasswordField(
            controller: _confirmPasswordController,
            labelText: 'Confirm New Password',
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),

          // Botón de actualizar contraseña
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _isLoading || !_isPasswordStrong ? null : _handlePasswordUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B8E3D),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey[300],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              child: _isLoading
                  ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Updating...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              )
                  : const Text(
                'Update Password',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Consejos de seguridad
          _buildSecurityTips(),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String labelText,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: const Icon(Icons.lock_outlined, color: Color(0xFF2B5F8C)),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility : Icons.visibility_off,
              color: const Color(0xFF2B5F8C),
            ),
            onPressed: onToggleVisibility,
          ),
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(15)),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
        ),
        validator: validator,
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isPasswordStrong
              ? const Color(0xFF6B8E3D).withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isPasswordStrong ? Icons.check_circle : Icons.info_outline,
                color: _isPasswordStrong ? const Color(0xFF6B8E3D) : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Password Requirements',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _isPasswordStrong ? const Color(0xFF6B8E3D) : Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCriteriaItem('At least 8 characters', _hasMinLength),
          _buildCriteriaItem('One uppercase letter (A-Z)', _hasUppercase),
          _buildCriteriaItem('One lowercase letter (a-z)', _hasLowercase),
          _buildCriteriaItem('One number (0-9)', _hasDigits),
          _buildCriteriaItem('One special character (!@#\$%)', _hasSpecialChar, isOptional: true),
        ],
      ),
    );
  }

  Widget _buildCriteriaItem(String text, bool isMet, {bool isOptional = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check : Icons.circle_outlined,
            color: isMet
                ? const Color(0xFF6B8E3D)
                : isOptional
                ? Colors.grey
                : Colors.orange,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isOptional ? '$text (recommended)' : text,
              style: TextStyle(
                fontSize: 13,
                color: isMet
                    ? const Color(0xFF2B5F8C)
                    : isOptional
                    ? Colors.grey
                    : Colors.grey[700],
                fontWeight: isMet ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2B5F8C).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2B5F8C).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.security,
                color: const Color(0xFF2B5F8C).withValues(alpha: 0.7),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Security Tips',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '• Use a unique password you haven\'t used before\n'
                '• Avoid using personal information\n'
                '• Consider using a password manager\n'
                '• Keep your password private and secure',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        // Icono de éxito
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E3D).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_outline,
            size: 60,
            color: Color(0xFF6B8E3D),
          ),
        ),
        const SizedBox(height: 30),

        // Mensaje de éxito
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 10,
              ),
            ],
          ),
          child: const Column(
            children: [
              Icon(
                Icons.security,
                color: Color(0xFF6B8E3D),
                size: 40,
              ),
              SizedBox(height: 16),
              Text(
                'Password Successfully Updated',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2B5F8C),
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 12),
              Text(
                'Your account is now secured with your new password. You can now sign in using your updated credentials.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Botón para ir al login
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: () => _navigateToLogin(),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2B5F8C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              elevation: 5,
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login),
                SizedBox(width: 12),
                Text(
                  'Continue to Sign In',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Información adicional
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF6B8E3D).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: const Color(0xFF6B8E3D).withValues(alpha: 0.7),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Remember to:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF6B8E3D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '• Store your password in a safe place\n'
                    '• Update any saved passwords in your browser\n'
                    '• Sign out from other devices if needed',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _handlePasswordUpdate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await AuthService.updatePassword(_passwordController.text);

      setState(() {
        _passwordUpdated = true;
        _isLoading = false;
      });

      // Mostrar snackbar de confirmación
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Password updated successfully!'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF6B8E3D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        final errorMessage = SupabaseUtils.handleSupabaseError(e);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _navigateToLogin() {
    // Navegar al login y limpiar el stack de navegación
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
          (Route<dynamic> route) => false,
    );
  }

  @override
  void dispose() {
    _passwordController.removeListener(_checkPasswordCriteria);
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.dispose();
    super.dispose();
  }
}