import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/services/device_storage_service.dart';
import '../../core/theme/app_theme.dart';
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
  bool _rememberMe = true;

  @override
  void initState() {
    super.initState();
    _rememberMe = DeviceStorageService.rememberMe;
    final savedEmail = DeviceStorageService.savedLoginEmail;
    final savedPassword = DeviceStorageService.savedLoginPassword;
    if (savedEmail != null && savedEmail.isNotEmpty) {
      _emailController.text = savedEmail;
    }
    if (savedPassword != null && savedPassword.isNotEmpty && _rememberMe) {
      _passwordController.text = savedPassword;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  void _showServerSettings() {
    final tokens = context.ehColors;
    final serverController = TextEditingController(text: AppConfig.backendBaseUrl);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: tokens.bluePrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.dns_rounded, color: tokens.bluePrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Backend Server',
              style: TextStyle(color: tokens.textPrimary, fontWeight: FontWeight.w800, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the host URL of your local PC backend (e.g. for local Wi-Fi or LAN mode):',
              style: TextStyle(color: tokens.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: serverController,
              style: TextStyle(color: tokens.textPrimary, fontSize: 14),
              decoration: InputDecoration(
                filled: true,
                fillColor: tokens.surfaceElevated,
                hintText: 'http://192.168.0.227:3000',
                hintStyle: TextStyle(color: tokens.textTertiary),
                prefixIcon: Icon(Icons.link_rounded, color: tokens.bluePrimary, size: 20),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.borderControl),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: tokens.bluePrimary, width: 1.5),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: tokens.textSecondary, fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: tokens.bluePrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final newUrl = serverController.text.trim();
              if (newUrl.isNotEmpty) {
                await DeviceStorageService.setBackendUrl(newUrl);
                AppConfig.setBaseUrl(newUrl);
                widget.controller.updateBaseUrl(newUrl);
                if (!mounted) return;
                nav.pop();
                messenger.showSnackBar(
                  SnackBar(
                    content: Text('Server URL set to: $newUrl'),
                    backgroundColor: tokens.bluePrimary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                setState(() {});
              }
            },
            child: const Text('Save URL', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final success = await widget.controller.login(email, password);
    if (success) {
      await DeviceStorageService.saveLoginCredentials(
        email: email,
        password: password,
        rememberMe: _rememberMe,
      );
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
            centerTitle: false,
            title: InkWell(
              onTap: _showServerSettings,
              borderRadius: BorderRadius.circular(20),
              child: Container(
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
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_drop_down_rounded, size: 16, color: tokens.textSecondary),
                  ],
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.settings_ethernet_rounded, color: tokens.textSecondary, size: 20),
                tooltip: 'Server Connection',
                onPressed: _showServerSettings,
              ),
              const SizedBox(width: 8),
            ],
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
                            const Spacer(flex: 1),

                            // Hero Brand Emblem
                            Center(
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(24),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      tokens.bluePrimary.withValues(alpha: 0.25),
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
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: Image.asset(
                                  'assets/branding/logo.png',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Icon(
                                    Icons.home_work_rounded,
                                    size: 42,
                                    color: tokens.bluePrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Header Text
                            Text(
                              'Welcome to EH Home',
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
                              'Sign in to orchestrate your connected devices',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: tokens.textSecondary,
                                height: 1.35,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Error Banner
                            if (error != null) ...[
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 20),
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

                            // Form Fields Container Card
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
                                  // Email input
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
                                    autofillHints: const [AutofillHints.email, AutofillHints.username],
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
                                  const SizedBox(height: 18),

                                  // Password input
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
                                    autofillHints: const [AutofillHints.password],
                                    decoration: InputDecoration(
                                      hintText: 'Enter your account password',
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
                                    validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
                                    enabled: !isLoading,
                                  ),
                                  const SizedBox(height: 14),

                                  // Remember me toggle row
                                  InkWell(
                                    onTap: isLoading ? null : () => setState(() => _rememberMe = !_rememberMe),
                                    borderRadius: BorderRadius.circular(8),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 4),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: Checkbox(
                                              value: _rememberMe,
                                              onChanged: isLoading ? null : (v) => setState(() => _rememberMe = v ?? true),
                                              activeColor: tokens.bluePrimary,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Remember login details on this device',
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: tokens.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],

                              ),
                            ),

                            const SizedBox(height: 24),

                            // Submit Button with Gradient Styling
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
                                onPressed: isLoading ? null : _login,
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
                                            'Sign In',
                                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 0.2),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(Icons.arrow_forward_rounded, size: 18),
                                        ],
                                      ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Sign Up Row Link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Don\'t have an account?',
                                  style: TextStyle(fontSize: 13, color: tokens.textSecondary),
                                ),
                                TextButton(
                                  onPressed: isLoading
                                      ? null
                                      : () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => RegisterScreen(controller: widget.controller),
                                            ),
                                          );
                                        },
                                  child: Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: tokens.bluePrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const Spacer(flex: 2),

                            // Bottom Security & Fleet Tag
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_clock_rounded, size: 13, color: tokens.textTertiary),
                                    const SizedBox(width: 6),
                                    Text(
                                      'EH Home Autonomous Mesh • Verified Local & Cloud',
                                      style: TextStyle(fontSize: 11, color: tokens.textTertiary, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              ),
                            ),
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
