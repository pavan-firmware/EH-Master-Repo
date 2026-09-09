import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/config/app_config.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/api/api_client.dart';
import '../core/api/sse_client.dart';
import '../core/repositories/account_home_repository.dart';
import '../core/repositories/auth_repository.dart';
import '../core/repositories/cloud_account_home_repository.dart';
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
    this.accountHomeRepository,
    this.backendBaseUrl,
    this.apiClient,
    this.realtimeEventService,
  });

  final HomeController? homeController;
  final ThemeController? themeController;
  final AuthController? authController;
  final AccountHomeRepository? accountHomeRepository;
  final String? backendBaseUrl;
  final ApiClient? apiClient;
  final RealtimeEventService? realtimeEventService;

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
  AccountHomeRepository? _accountHomeRepository;
  SseClient? _sseClient;
  RealtimeEventService? _realtimeService;
  String? _activeHomeId;
  bool _isResolvingHome = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _themeController = widget.themeController ?? ThemeController();

    if (widget.homeController != null && widget.authController == null) {
      // Test / preview injection path: only HomeController supplied
      _homeController = widget.homeController!;
    } else if (widget.authController != null && widget.homeController != null) {
      // Test injection path with explicit authController and homeController
      _authController = widget.authController!;
      _homeController = widget.homeController!;
      _apiClient = widget.apiClient;
      _accountHomeRepository = widget.accountHomeRepository;
      _realtimeService = widget.realtimeEventService;
      _authController!.addListener(_onAuthStateChanged);
      if (_authController!.state == AuthState.authenticated) {
        _onAuthenticated();
      }
    } else {
      // Production path: wire up the full cloud stack
      _apiClient = widget.apiClient ??
          ApiClient(
            baseUrl: widget.backendBaseUrl ?? AppConfig.backendBaseUrl,
          );
      _authRepository = AuthRepository(_apiClient!);
      _accountHomeRepository = widget.accountHomeRepository ??
          CloudAccountHomeRepository(_apiClient!);
      _sseClient = SseClient(_apiClient!);
      _realtimeService =
          widget.realtimeEventService ?? RealtimeEventService(_sseClient!);

      _authController =
          widget.authController ?? AuthController(_authRepository!);
      _authController!.addListener(_onAuthStateChanged);

      _homeController =
          widget.homeController ??
          HomeController(
            repository: CloudHomeRepository(_apiClient!),
            realtimeEventService: _realtimeService,
            cloudEnabled: false, // Will be dynamically enabled upon authentication
          );

      if (_authController!.state == AuthState.authenticated) {
        _onAuthenticated();
      }
    }
  }

  void _onAuthStateChanged() {
    final state = _authController?.state;
    if (state == AuthState.authenticated) {
      _onAuthenticated();
    } else if (state == AuthState.unauthenticated ||
        state == AuthState.failure) {
      _onUnauthenticated();
    }
  }

  Future<void> _onAuthenticated() async {
    _homeController.setCloudEnabled(true);
    await _resolveHomeAndConnect();
  }

  Future<void> _resolveHomeAndConnect() async {
    if (_isResolvingHome) return;
    _isResolvingHome = true;

    try {
      if (_accountHomeRepository != null) {
        final homes = await _accountHomeRepository!
            .listHomes()
            .timeout(const Duration(seconds: 10));
        if (homes.isNotEmpty) {
          final resolvedHome = homes.first;
          _activeHomeId = resolvedHome.id;
          _homeController.setActiveHomeId(resolvedHome.id);
          await _homeController.loadHomeData(homeId: resolvedHome.id);
          _realtimeService?.connect(resolvedHome.id);
        } else {
          _activeHomeId = null;
          _homeController.setActiveHomeId(null);
          await _homeController.loadHomeData(homeId: null);
        }
      } else if (_homeController.activeHomeId != null) {
        _activeHomeId = _homeController.activeHomeId;
        await _homeController.loadHomeData(homeId: _activeHomeId);
        _realtimeService?.connect(_activeHomeId!);
      }
    } catch (_) {
      // Graceful error recovery: avoid crashing and avoid fake fallback
    } finally {
      _isResolvingHome = false;
    }
  }

  void _onUnauthenticated() {
    _realtimeService?.disconnect();
    _homeController.resetSession();
    _activeHomeId = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_authController?.state == AuthState.authenticated &&
          _activeHomeId != null) {
        _realtimeService?.connect(_activeHomeId!);
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
            home: _authController != null
                ? ListenableBuilder(
                    listenable: _authController!,
                    builder: (context, _) {
                      final authState = _authController!.state;

                      // Still restoring persisted session
                      if (authState == AuthState.unknown) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      // Not authenticated → show real login
                      if (authState == AuthState.unauthenticated ||
                          authState == AuthState.failure) {
                        return LoginScreen(controller: _authController!);
                      }

                      // Authenticated → show splash → home shell
                      return SplashScreen(
                        homeController: _homeController,
                        authController: _authController,
                        apiClient: _apiClient,
                        homeId: _activeHomeId,
                      );
                    },
                  )
                : SplashScreen(
                    homeController: _homeController,
                    authController: _authController,
                    apiClient: _apiClient,
                    homeId: _activeHomeId,
                  ),
          ),
        );
      },
    );
  }
}
