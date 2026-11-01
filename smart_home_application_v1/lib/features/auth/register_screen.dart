import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import 'auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.controller});
  final AuthController controller;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _register() async {
    if (!_formKey.currentState!.validate()) return;
    final success = await widget.controller.register(
      _emailController.text.trim(),
      _passwordController.text,
      fullName: _nameController.text.trim(),
    );
    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;
    final serverUrl = AppConfig.backendBaseUrl;
    final cleanHost = serverUrl.replaceAll('http://', '').replaceAll('https://', '');

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final isLoading = widget.controller.state == AuthState.authenticating;
        final error = widget.controller.errorMessage;

        return Scaffold(
          backgroundColor: tokens.bgApp,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tokens.surfaceCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: tokens.borderSubtle),
                ),
                child: Icon(Icons.arrow_back_rounded, color: tokens.textPrimary, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: tokens.borderSubtle),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    cleanHost,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 12),

                            // Hero Emblem
                            Center(
                              child: Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(22),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      tokens.bluePrimary.withValues(alpha: 0.22),
                                      tokens.surfaceCard,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: tokens.bluePrimary.withValues(alpha: 0.35),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: tokens.bluePrimary.withValues(alpha: 0.12),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(14),
                                child: Image.asset(
                                  'assets/branding/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.person_add_alt_1_rounded,
                                    size: 36,
                                    color: tokens.bluePrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),

                            // Header Text
                            Text(
                              'Create Account',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: tokens.textPrimary,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Join the EH Home connected ecosystem',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 13, color: tokens.textSecondary, height: 1.35),
                            ),

                            const SizedBox(height: 26),

                            // Error Banner
                            if (error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 18),
                                decoration: BoxDecoration(
                                  color: tokens.isDark ? tokens.errorContainer : const Color(0xFFFFEAEA),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: tokens.errorText.withValues(alpha: 0.6)),
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
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Card Container
                            Container(
                              decoration: BoxDecoration(
                                color: tokens.surfaceCard,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: tokens.borderSubtle),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: tokens.isDark ? 0.25 : 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  // Full Name
                                  Text(
                                    'FULL NAME',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.textTertiary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _nameController,
                                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                                    textCapitalization: TextCapitalization.words,
                                    decoration: InputDecoration(
                                      hintText: 'John Doe',
                                      hintStyle: TextStyle(color: tokens.textTertiary, fontSize: 14),
                                      prefixIcon: Icon(Icons.person_outline_rounded, color: tokens.textSecondary, size: 19),
                                      filled: true,
                                      fillColor: tokens.surfaceElevated,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Full Name is required' : null,
                                    enabled: !isLoading,
                                  ),
                                  const SizedBox(height: 16),

                                  // Email
                                  Text(
                                    'EMAIL ADDRESS',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.textTertiary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _emailController,
                                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'name@example.com',
                                      hintStyle: TextStyle(color: tokens.textTertiary, fontSize: 14),
                                      prefixIcon: Icon(Icons.alternate_email_rounded, color: tokens.textSecondary, size: 19),
                                      filled: true,
                                      fillColor: tokens.surfaceElevated,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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

                                  // Password
                                  Text(
                                    'PASSWORD',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.textTertiary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _passwordController,
                                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'At least 6 characters',
                                      hintStyle: TextStyle(color: tokens.textTertiary, fontSize: 14),
                                      prefixIcon: Icon(Icons.lock_outline_rounded, color: tokens.textSecondary, size: 19),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: tokens.textSecondary,
                                          size: 19,
                                        ),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      filled: true,
                                      fillColor: tokens.surfaceElevated,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                    validator: (v) {
                                      if (v == null || v.isEmpty) return 'Password is required';
                                      if (v.length < 6) return 'Password must be at least 6 characters';
                                      return null;
                                    },
                                    enabled: !isLoading,
                                  ),
                                  const SizedBox(height: 16),

                                  // Confirm Password
                                  Text(
                                    'CONFIRM PASSWORD',
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.textTertiary,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    style: TextStyle(color: tokens.textPrimary, fontSize: 14),
                                    decoration: InputDecoration(
                                      hintText: 'Re-enter your password',
                                      hintStyle: TextStyle(color: tokens.textTertiary, fontSize: 14),
                                      prefixIcon: Icon(Icons.shield_outlined, color: tokens.textSecondary, size: 19),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                          color: tokens.textSecondary,
                                          size: 19,
                                        ),
                                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                      ),
                                      filled: true,
                                      fillColor: tokens.surfaceElevated,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                    obscureText: _obscureConfirmPassword,
                                    validator: (v) {
                                      if (v != _passwordController.text) return 'Passwords do not match';
                                      return null;
                                    },
                                    enabled: !isLoading,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button
                            Container(
                              height: 52,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                gradient: LinearGradient(
                                  colors: [
                                    tokens.bluePrimary,
                                    const Color(0xFF2563EB),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: tokens.bluePrimary.withValues(alpha: 0.35),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: isLoading ? null : _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                                    : const Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'Create Account',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.check_rounded, size: 18),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Bottom Link to Login
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Already have an account?',
                                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                                ),
                                TextButton(
                                  onPressed: isLoading ? null : () => Navigator.pop(context),
                                  child: Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.bluePrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
