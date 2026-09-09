import 'package:flutter/material.dart';

import '../../app/home_controller.dart';
import '../../core/theme/app_theme.dart';
import '../splash/presentation/splash_screen.dart';
import 'auth_controller.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.controller.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isLoading = widget.controller.state == AuthState.authenticating;
        final error = widget.controller.errorMessage;

        return Scaffold(
          backgroundColor: tokens.bgApp,
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // EH Home Brand Logo
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: tokens.surfaceCard,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: tokens.isDark ? 0.4 : 0.08),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Image.asset(
                            'assets/branding/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) => Icon(
                              Icons.home_rounded,
                              size: 48,
                              color: tokens.bluePrimary,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Welcome to EH Home',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: tokens.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sign in to manage your connected smart home',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 28),

                      if (error != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: tokens.isDark ? tokens.errorContainer : const Color(0xFFFFE8E8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: tokens.isDark ? tokens.errorText : const Color(0xFFD92D20),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.error_outline_rounded, color: tokens.errorText, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  error,
                                  style: TextStyle(
                                    color: tokens.errorText,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Email input
                      TextFormField(
                        controller: _emailController,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Email Address',
                          labelStyle: TextStyle(color: tokens.textSecondary),
                          prefixIcon: Icon(Icons.email_outlined, color: tokens.textSecondary),
                          filled: true,
                          fillColor: tokens.surfaceCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.borderControl),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.borderControl),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                          ),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Email is required' : null,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: 16),

                      // Password input
                      TextFormField(
                        controller: _passwordController,
                        style: TextStyle(color: tokens.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: TextStyle(color: tokens.textSecondary),
                          prefixIcon: Icon(Icons.lock_outline_rounded, color: tokens.textSecondary),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: tokens.textSecondary,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                          filled: true,
                          fillColor: tokens.surfaceCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.borderControl),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.borderControl),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                          ),
                        ),
                        obscureText: _obscurePassword,
                        validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: 24),

                      // Submit button
                      FilledButton(
                        onPressed: isLoading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: tokens.bluePrimary,
                          foregroundColor: tokens.buttonText,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                      ),
                      const SizedBox(height: 16),

                      // Create account link
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => RegisterScreen(
                                      controller: widget.controller,
                                    ),
                                  ),
                                );
                              },
                        child: Text(
                          'Don\'t have an account? Create one',
                          style: TextStyle(
                            color: tokens.bluePrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Continue offline
                      OutlinedButton.icon(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) => SplashScreen(homeController: HomeController()),
                                  ),
                                );
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: tokens.textSecondary,
                          side: BorderSide(color: tokens.borderControl),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.home_outlined),
                        label: const Text('Continue to Local Home'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
