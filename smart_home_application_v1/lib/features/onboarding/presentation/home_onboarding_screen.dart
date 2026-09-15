import 'package:flutter/material.dart';
import '../../../core/repositories/account_home_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../app/home_controller.dart';

class HomeOnboardingScreen extends StatefulWidget {
  const HomeOnboardingScreen({
    super.key,
    required this.accountHomeRepository,
    required this.homeController,
    required this.onHomeCreated,
  });

  final AccountHomeRepository accountHomeRepository;
  final HomeController homeController;
  final ValueChanged<String> onHomeCreated;

  @override
  State<HomeOnboardingScreen> createState() => _HomeOnboardingScreenState();
}

class _HomeOnboardingScreenState extends State<HomeOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  final _timezoneController = TextEditingController(text: 'UTC');

  bool _isCreating = false;
  bool _isSuccess = false;
  String? _errorMessage;
  String? _createdHomeId;
  String? _createdHomeName;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateHome() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });

    try {
      final homeName = _nameController.text.trim();
      final location = _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null;
      final timezone = _timezoneController.text.trim().isNotEmpty
          ? _timezoneController.text.trim()
          : 'UTC';

      final created = await widget.accountHomeRepository.createHome(
        name: homeName,
        timezone: timezone,
        address: location,
      );

      widget.homeController.setActiveHomeId(created.id);

      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _isSuccess = true;
        _createdHomeId = created.id;
        _createdHomeName = created.name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isCreating = false;
        _errorMessage = e.toString().replaceFirst('ApiException: ', '');
      });
    }
  }

  void _handleContinue() {
    if (_createdHomeId != null) {
      widget.onHomeCreated(_createdHomeId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.ehColors;

    return Scaffold(
      backgroundColor: tokens.bgApp,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: _isSuccess ? _buildSuccessView(tokens) : _buildFormView(tokens),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView(EHThemeTokens tokens) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: tokens.surfaceCard,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: tokens.isDark ? 0.35 : 0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(12),
              child: Icon(
                Icons.home_work_rounded,
                size: 44,
                color: tokens.bluePrimary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Welcome to EH Home',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: tokens.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Let's create your first EH Home to start connecting and controlling your devices.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: tokens.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 24),
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
                      _errorMessage!,
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

          // Home Name Input
          Text(
            'Home Name',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _nameController,
            style: TextStyle(color: tokens.textPrimary),
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              hintText: 'e.g. Pavan Home or Villa',
              hintStyle: TextStyle(color: tokens.textTertiary),
              filled: true,
              fillColor: tokens.surfaceCard,
              prefixIcon: Icon(Icons.home_outlined, color: tokens.textSecondary),
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
                borderSide: BorderSide(color: tokens.bluePrimary, width: 2),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a name for your home';
              }
              if (value.trim().length < 2) {
                return 'Home name must be at least 2 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Location (Optional)
          Text(
            'Location (Optional)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _locationController,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Hyderabad, India',
              hintStyle: TextStyle(color: tokens.textTertiary),
              filled: true,
              fillColor: tokens.surfaceCard,
              prefixIcon: Icon(Icons.location_on_outlined, color: tokens.textSecondary),
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
                borderSide: BorderSide(color: tokens.bluePrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Timezone (Optional)
          Text(
            'Timezone',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _timezoneController,
            style: TextStyle(color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'e.g. Asia/Kolkata or UTC',
              hintStyle: TextStyle(color: tokens.textTertiary),
              filled: true,
              fillColor: tokens.surfaceCard,
              prefixIcon: Icon(Icons.schedule_rounded, color: tokens.textSecondary),
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
                borderSide: BorderSide(color: tokens.bluePrimary, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Submit button
          ElevatedButton(
            onPressed: _isCreating ? null : _handleCreateHome,
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.bluePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: _isCreating
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text(
                    'Create Home',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessView(EHThemeTokens tokens) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: tokens.isDark ? const Color(0xFF133E2B) : const Color(0xFFE8F5E9),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 56,
            color: Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Home Created!',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: tokens.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'You are now the Owner of "${_createdHomeName ?? 'your home'}". You have full administrative authority to add rooms, configure devices, and invite household members.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: tokens.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 36),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _handleContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: tokens.bluePrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text(
              'Continue to Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}
