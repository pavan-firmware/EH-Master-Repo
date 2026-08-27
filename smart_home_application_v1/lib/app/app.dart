import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/api/sse_client.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/cloud_home_repository.dart';
import '../core/services/realtime_event_service.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import 'home_controller.dart';
import 'theme_controller.dart';
import '../features/splash/presentation/splash_screen.dart';

class SmartHomeApp extends StatefulWidget {
  const SmartHomeApp({
    super.key,
    this.homeController,
    this.themeController,
    this.authController,
    this.backendBaseUrl,
  });

  final HomeController? homeController;
  final ThemeController? themeController;
  final AuthController? authController;
  final String? backendBaseUrl;

  @override
  State<SmartHomeApp> createState() => _SmartHomeAppState();
}

class _SmartHomeAppState extends State<SmartHomeApp>
    with WidgetsBindingObserver {
  late final ThemeController _themeController;
  AuthController? _authController;
  late final HomeController _homeController;
  ApiClient? _apiClient;
  AuthRepository? _authRepository;
  SseClient? _sseClient;
  RealtimeEventService? _realtimeService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _themeController = widget.themeController ?? ThemeController();

    if (widget.homeController != null && widget.authController == null) {
      // Test / preview injection path: only HomeController supplied
      _homeController = widget.homeController!;
    } else if (widget.authController != null && widget.homeController != null) {
      // Test injection path with explicit authController
      _authController = widget.authController!;
      _homeController = widget.homeController!;
      _authController!.addListener(_onAuthStateChanged);
    } else {
      // Production path: wire up the full cloud stack
      _apiClient = ApiClient(
        baseUrl: widget.backendBaseUrl ?? AppConfig.backendBaseUrl,
      );
      _authRepository = AuthRepository(_apiClient!);
      _sseClient = SseClient(_apiClient!);
      _realtimeService = RealtimeEventService(_sseClient!);

      _authController =
          widget.authController ?? AuthController(_authRepository!);
      _authController!.addListener(_onAuthStateChanged);

      _homeController =
          widget.homeController ??
          HomeController(
            repository: CloudHomeRepository(_apiClient!),
            realtimeEventService: _realtimeService,
            cloudEnabled: false, // Will be set true after auth completes
          );
    }
  }

  void _onAuthStateChanged() {
    if (_authController?.state == AuthState.authenticated) {
      _realtimeService?.connect('default');
    } else if (_authController?.state == AuthState.unauthenticated) {
      _realtimeService?.disconnect();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_authController?.state == AuthState.authenticated) {
        _realtimeService?.connect('default');
      }
    } else if (state == AppLifecycleState.paused) {
      _sseClient?.disconnect();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authController?.removeListener(_onAuthStateChanged);
    if (widget.themeController == null) {
      _themeController.dispose();
    }
    if (widget.authController == null) {
      _authController?.dispose();
      _realtimeService?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _themeController,
      builder: (context, _) {
        return ThemeScope(
          controller: _themeController,
          child: MaterialApp(
            title: 'EH Home',
            debugShowCheckedModeBanner: false,
            theme: EHAppTheme.lightTheme,
            darkTheme: EHAppTheme.darkTheme,
            themeMode: _themeController.themeMode,
            builder: (context, child) {
              final isDark = Theme.of(context).brightness == Brightness.dark;
              final systemUiStyle = isDark
                  ? const SystemUiOverlayStyle(
                      statusBarColor: EHColors.darkBgApp,
                      statusBarIconBrightness: Brightness.light,
                      statusBarBrightness: Brightness.dark,
                      systemNavigationBarColor: EHColors.darkSurfaceNav,
                      systemNavigationBarIconBrightness: Brightness.light,
                    )
                  : const SystemUiOverlayStyle(
                      statusBarColor: EHColors.lightBgApp,
                      statusBarIconBrightness: Brightness.dark,
                      statusBarBrightness: Brightness.light,
                      systemNavigationBarColor: Colors.black,
                      systemNavigationBarIconBrightness: Brightness.light,
                    );

              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: systemUiStyle,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home:
                (widget.homeController != null && widget.authController == null)
                ? SplashScreen(homeController: widget.homeController)
                : ListenableBuilder(
                    listenable: _authController!,
                    builder: (context, _) {
                      final authState = _authController!.state;

                      // Still restoring persisted session
                      if (authState == AuthState.unknown) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      // Not authenticated → show login
                      if (authState == AuthState.unauthenticated ||
                          authState == AuthState.failure) {
                        return LoginScreen(controller: _authController!);
                      }

                      // Authenticated → show splash → home shell
                      return SplashScreen(homeController: _homeController);
                    },
                  ),
          ),
        );
      },
    );
  }
}
