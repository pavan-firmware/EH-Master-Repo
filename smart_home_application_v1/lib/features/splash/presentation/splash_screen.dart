// ignore_for_file: deprecated_member_use

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/home_controller.dart';
import '../../../app/home_shell.dart';

// ---------------------------------------------------------------------------
// TIMING CONSTANTS (Total duration: 3.10 seconds)
// ---------------------------------------------------------------------------
class _SplashTimeline {
  static const int totalDurationMs = 3100;

  // Circular ring start
  static const double ringStart = 0.060; // ~0.20s
  static const double ringEnd = 0.950; // ~2.95s

  // Sequential device icons (Strictly one-by-one inside the same center)
  static const double bulbStart = 0.220; // ~0.68s
  static const double bulbEnd = 0.360; // ~1.12s (1. Bulb)

  static const double fanStart = 0.340; // ~1.05s
  static const double fanEnd = 0.480; // ~1.49s (2. Fan)

  static const double socketStart = 0.460; // ~1.42s
  static const double socketEnd = 0.600; // ~1.86s (3. Socket)

  static const double thermoStart = 0.580; // ~1.80s
  static const double thermoEnd = 0.710; // ~2.20s (4. Temperature)

  static const double lockStart = 0.690; // ~2.14s
  static const double lockEnd = 0.810; // ~2.51s (5. Lock / Security)

  // Final Home + Wi-Fi (LAST)
  static const double homeWifiStart = 0.780; // ~2.42s
  static const double homeWifiEnd = 0.960; // ~2.98s (6. Home + Wi-Fi)

  static const double wifiWaveStart = 0.820;
  static const double wifiWaveEnd = 1.000;

  // Crossfade to HomeShell
  static const double fadeOutStart = 0.960;
  static const double fadeOutEnd = 1.000;
}

// ---------------------------------------------------------------------------
// COLOR PALETTE (Gold colors calibrated to startup_animation_image.png)
// ---------------------------------------------------------------------------
class _SplashColors {
  static const Color background = Color(0xFF090D14);
  static const Color goldBright = Color(0xFFF7C852);
  static const Color goldMain = Color(0xFFDCAE45);
  static const Color goldTick = Color(0x66DCAE45);
}

// ---------------------------------------------------------------------------
// SPLASH SCREEN WIDGET (Hybrid Architecture)
// ---------------------------------------------------------------------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.homeController});
  final HomeController? homeController;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  // Circular ring loop
  late final Animation<double> _ringLoopAnim;
  late final Animation<double> _ringFadeInAnim;

  // Device icons animations
  late final Animation<double> _bulbAnim;
  late final Animation<double> _fanAnim;
  late final Animation<double> _fanRotationAnim;
  late final Animation<double> _socketAnim;
  late final Animation<double> _thermoAnim;
  late final Animation<double> _lockAnim;

  // Final Home + Wi-Fi
  late final Animation<double> _homeWifiAnim;
  late final Animation<double> _wifiWaveAnim;

  // Fade out
  late final Animation<double> _fadeOutAnim;

  Animation<double> _curved(
    double start,
    double end, [
    Curve curve = Curves.easeInOut,
  ]) {
    return CurvedAnimation(
      parent: _ctrl,
      curve: Interval(start, end, curve: curve),
    );
  }

  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _SplashColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: _SplashTimeline.totalDurationMs,
      ),
    );

    _ringFadeInAnim = _curved(_SplashTimeline.ringStart, _SplashTimeline.ringStart + 0.08);

    // Continuous ring loop progress (repeating multiple revolutions during the sequence)
    _ringLoopAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(_SplashTimeline.ringStart, _SplashTimeline.ringEnd, curve: Curves.linear),
    );

    _bulbAnim = _curved(_SplashTimeline.bulbStart, _SplashTimeline.bulbEnd);
    _fanAnim = _curved(_SplashTimeline.fanStart, _SplashTimeline.fanEnd);
    _fanRotationAnim = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(_SplashTimeline.fanStart, _SplashTimeline.fanEnd, curve: Curves.linear),
    );
    _socketAnim = _curved(_SplashTimeline.socketStart, _SplashTimeline.socketEnd);
    _thermoAnim = _curved(_SplashTimeline.thermoStart, _SplashTimeline.thermoEnd);
    _lockAnim = _curved(_SplashTimeline.lockStart, _SplashTimeline.lockEnd);

    _homeWifiAnim = _curved(_SplashTimeline.homeWifiStart, _SplashTimeline.homeWifiEnd, Curves.easeOut);
    _wifiWaveAnim = _curved(_SplashTimeline.wifiWaveStart, _SplashTimeline.wifiWaveEnd, Curves.easeInOut);

    _fadeOutAnim = _curved(_SplashTimeline.fadeOutStart, _SplashTimeline.fadeOutEnd, Curves.easeIn);

    _ctrl.forward().then((_) {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        _SplashFadePageRoute(
          builder: (_) => HomeShell(homeController: widget.homeController),
        ),
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/branding/app_startup_without_loading.png'), context);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _calcBell(Animation<double> anim) {
    final t = anim.value;
    if (t <= 0.0 || t >= 1.0) return 0.0;
    if (t < 0.28) return (t / 0.28).clamp(0.0, 1.0);
    if (t > 0.72) return ((1.0 - t) / 0.28).clamp(0.0, 1.0);
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: _SplashColors.background,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: _SplashColors.background,
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            final fadeOut = (1.0 - _fadeOutAnim.value).clamp(0.0, 1.0);
            return Opacity(
              opacity: fadeOut,
              child: _buildBody(context),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // The reference image aspect ratio: 853 x 1844 (~0.4626)
    // Circle in reference: Center is at X: 432/853 (50.64%), Y: 1248.5/1844 (67.70%)
    // Diameter is 310/853 = 36.34% of reference width.
    const double refW = 853.0;
    const double refH = 1844.0;
    const double refCenterX = 432.0;
    const double refCenterY = 1248.5;
    const double refDiameter = 310.0;

    // Compute scaled dimensions for BoxFit.contain / cover alignment
    final double scale = math.max(size.width / refW, size.height / refH);
    final double renderedW = refW * scale;
    final double renderedH = refH * scale;
    final double renderedLeft = (size.width - renderedW) / 2.0;
    final double renderedTop = (size.height - renderedH) / 2.0;

    final double circleX = renderedLeft + (refCenterX * scale);
    final double circleY = renderedTop + (refCenterY * scale);
    final double circleDiameter = refDiameter * scale;

    // Total revolutions during the timeline
    final double loopVal = _ringLoopAnim.value * 3.5;

    return Stack(
      children: [
        // -------------------------------------------------------------------
        // LAYER 1: Static Startup Base Image (app_startup_without_loading.png)
        // -------------------------------------------------------------------
        Positioned.fill(
          child: Image.asset(
            'assets/branding/app_startup_without_loading.png',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),

        // -------------------------------------------------------------------
        // LAYER 2 & 3: Animated Circular Ring & Sequential Center Device Icons
        // -------------------------------------------------------------------
        Positioned(
          left: circleX - circleDiameter / 2.0,
          top: circleY - circleDiameter / 2.0,
          width: circleDiameter,
          height: circleDiameter,
          child: Opacity(
            opacity: _ringFadeInAnim.value,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Precision Gold Ring (Arc on Left + Stepping Ticks on Right + Orbiting Dot)
                CustomPaint(
                  size: Size(circleDiameter, circleDiameter),
                  painter: _DualModeRingPainter(
                    loopProgress: loopVal,
                    finalHold: _homeWifiAnim.value,
                  ),
                ),

                // Center Device Icons (Strictly in the exact same center position)
                _CenterDeviceIconsLayer(
                  diameter: circleDiameter * 0.48,
                  bulbOpacity: _calcBell(_bulbAnim),
                  fanOpacity: _calcBell(_fanAnim),
                  fanRotation: _fanRotationAnim.value * 2 * math.pi * 2.5,
                  socketOpacity: _calcBell(_socketAnim),
                  thermoOpacity: _calcBell(_thermoAnim),
                  lockOpacity: _calcBell(_lockAnim),
                  homeWifiOpacity: _homeWifiAnim.value,
                  wifiWaveProgress: _wifiWaveAnim.value,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// DUAL-MODE RING PAINTER
// Left side: Solid Glowing Gold Arc (Continuous high speed)
// Right side: Fine Dashed Gold Ticks (Rapid discrete stepping from tick to tick)
// ---------------------------------------------------------------------------
class _DualModeRingPainter extends CustomPainter {
  _DualModeRingPainter({
    required this.loopProgress,
    required this.finalHold,
  });

  final double loopProgress;
  final double finalHold; // 0..1 when settling into final home Wi-Fi connected state

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2.0, size.height / 2.0);
    final radius = size.width / 2.0 - 4.0;

    // -----------------------------------------------------------------------
    // 1. LEFT SIDE SOLID GOLD ARC (from 6 o'clock through 9 to 12 o'clock)
    // Range in radians: pi/2 down to -pi/2 (i.e. theta from pi/2 to 3*pi/2)
    // -----------------------------------------------------------------------
    final arcRect = Rect.fromCircle(center: center, radius: radius);

    // Soft glow for left arc
    final glowPaint = Paint()
      ..color = _SplashColors.goldBright.withOpacity(0.24)
      ..strokeWidth = 6.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.5);

    canvas.drawArc(arcRect, math.pi / 2.0, math.pi, false, glowPaint);

    // Core crisp solid left gold arc
    final solidArcPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: math.pi / 2.0,
        endAngle: 3.0 * math.pi / 2.0,
        colors: [
          _SplashColors.goldMain,
          _SplashColors.goldBright,
          _SplashColors.goldMain,
        ],
      ).createShader(arcRect)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(arcRect, math.pi / 2.0, math.pi, false, solidArcPaint);

    // -----------------------------------------------------------------------
    // 2. RIGHT SIDE DASHED GOLD TICKS (from 12 o'clock through 3 to 6 o'clock)
    // Range in radians: -pi/2 to pi/2 (28 fine ticks)
    // -----------------------------------------------------------------------
    const int numTicks = 28;
    const double tickLen = 4.8;

    final tickPaint = Paint()
      ..color = _SplashColors.goldTick
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (int i = 0; i <= numTicks; i++) {
      final double fraction = i / numTicks;
      final double angle = -math.pi / 2.0 + fraction * math.pi;

      final double outerX = center.dx + radius * math.cos(angle);
      final double outerY = center.dy + radius * math.sin(angle);
      final double innerX = center.dx + (radius - tickLen) * math.cos(angle);
      final double innerY = center.dy + (radius - tickLen) * math.sin(angle);

      canvas.drawLine(Offset(innerX, innerY), Offset(outerX, outerY), tickPaint);
    }

    // -----------------------------------------------------------------------
    // 3. MOVING PROGRESS HEAD DOT (Dual-speed: smooth on arc, rapid step on ticks)
    // -----------------------------------------------------------------------
    final double cycleFraction = loopProgress % 1.0; // 0.0 to 1.0
    double dotAngle;

    if (cycleFraction < 0.50) {
      // RIGHT SIDE (0.0 to 0.50) -> Travels 12 o'clock (-pi/2) to 6 o'clock (pi/2)
      // Rapid stepped progression across ticks:
      final double subT = cycleFraction / 0.50; // 0..1 across right half
      final double tickIndexFloat = subT * numTicks;
      final int currentTick = tickIndexFloat.floor().clamp(0, numTicks);
      final double stepRemainder = tickIndexFloat - currentTick;

      // Fast snap-to-next tick with quick ease (steps from dash to dash speedly)
      final double stepEased = math.pow(stepRemainder, 2.5).toDouble();
      final double steppedFraction = (currentTick + stepEased) / numTicks;
      dotAngle = -math.pi / 2.0 + steppedFraction * math.pi;
    } else {
      // LEFT SIDE (0.50 to 1.00) -> Travels 6 o'clock (pi/2) through 9 to 12 o'clock (3*pi/2)
      // Continuous smooth high speed motion along solid arc:
      final double subT = (cycleFraction - 0.50) / 0.50; // 0..1 across left half
      dotAngle = math.pi / 2.0 + subT * math.pi;
    }

    // If finalHold is active (>0.7), lock dot near the 2 o'clock position (approx matching reference)
    if (finalHold > 0.01) {
      final double targetAngle = -math.pi / 2.0 + (0.32 * math.pi); // ~2 o'clock
      dotAngle = dotAngle * (1.0 - finalHold) + targetAngle * finalHold;
    }

    final Offset dotPos = Offset(
      center.dx + radius * math.cos(dotAngle),
      center.dy + radius * math.sin(dotAngle),
    );

    // Glowing Dot Halo
    canvas.drawCircle(
      dotPos,
      6.0,
      Paint()
        ..color = _SplashColors.goldBright.withOpacity(0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0),
    );

    // Bright Golden Dot Core
    canvas.drawCircle(
      dotPos,
      3.2,
      Paint()
        ..color = _SplashColors.goldBright
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_DualModeRingPainter oldDelegate) => true;
}

// ---------------------------------------------------------------------------
// CENTER DEVICE ICONS LAYER (Strictly one-by-one inside the exact same center)
// ---------------------------------------------------------------------------
class _CenterDeviceIconsLayer extends StatelessWidget {
  const _CenterDeviceIconsLayer({
    required this.diameter,
    required this.bulbOpacity,
    required this.fanOpacity,
    required this.fanRotation,
    required this.socketOpacity,
    required this.thermoOpacity,
    required this.lockOpacity,
    required this.homeWifiOpacity,
    required this.wifiWaveProgress,
  });

  final double diameter;
  final double bulbOpacity;
  final double fanOpacity;
  final double fanRotation;
  final double socketOpacity;
  final double thermoOpacity;
  final double lockOpacity;
  final double homeWifiOpacity;
  final double wifiWaveProgress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: diameter,
      height: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Bulb
          if (bulbOpacity > 0.005)
            Opacity(
              opacity: bulbOpacity,
              child: CustomPaint(
                size: Size(diameter, diameter),
                painter: _BulbIconPainter(glow: bulbOpacity),
              ),
            ),

          // 2. Fan
          if (fanOpacity > 0.005)
            Opacity(
              opacity: fanOpacity,
              child: Transform.rotate(
                angle: fanRotation,
                child: CustomPaint(
                  size: Size(diameter, diameter),
                  painter: _FanIconPainter(glow: fanOpacity),
                ),
              ),
            ),

          // 3. Socket / Plug
          if (socketOpacity > 0.005)
            Opacity(
              opacity: socketOpacity,
              child: CustomPaint(
                size: Size(diameter, diameter),
                painter: _SocketIconPainter(glow: socketOpacity),
              ),
            ),

          // 4. Temperature / Thermometer
          if (thermoOpacity > 0.005)
            Opacity(
              opacity: thermoOpacity,
              child: CustomPaint(
                size: Size(diameter, diameter),
                painter: _ThermoIconPainter(glow: thermoOpacity),
              ),
            ),

          // 5. Lock / Security
          if (lockOpacity > 0.005)
            Opacity(
              opacity: lockOpacity,
              child: CustomPaint(
                size: Size(diameter, diameter),
                painter: _LockIconPainter(glow: lockOpacity),
              ),
            ),

          // 6. Home + Wi-Fi (LAST - Final state)
          if (homeWifiOpacity > 0.005)
            Opacity(
              opacity: homeWifiOpacity,
              child: CustomPaint(
                size: Size(diameter, diameter),
                painter: _HomeWifiIconPainter(
                  glow: homeWifiOpacity,
                  waveProgress: wifiWaveProgress,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// DEVICE LINE-ART PAINTERS
// ---------------------------------------------------------------------------
Paint _linePaint(double width, {double opacity = 1.0}) => Paint()
  ..color = _SplashColors.goldMain.withOpacity(opacity)
  ..strokeWidth = width
  ..style = PaintingStyle.stroke
  ..strokeCap = StrokeCap.round
  ..strokeJoin = StrokeJoin.round;

Paint _glowPaint(double blurRadius, double glow) => Paint()
  ..color = _SplashColors.goldBright.withOpacity(0.35 * glow)
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, blurRadius);

// 1. Bulb
class _BulbIconPainter extends CustomPainter {
  const _BulbIconPainter({required this.glow});
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final r = size.width * 0.28;

    if (glow > 0.1) {
      canvas.drawCircle(Offset(cx, cy - r * 0.1), r * 0.70, _glowPaint(10, glow));
    }

    final bulbRect = Rect.fromCenter(
      center: Offset(cx, cy - r * 0.15),
      width: r * 1.6,
      height: r * 1.6,
    );
    canvas.drawArc(bulbRect, math.pi * 0.15, math.pi * 0.70, false, _linePaint(1.8));
    canvas.drawArc(bulbRect, math.pi * 0.85, math.pi * 1.30, false, _linePaint(1.8));

    final baseY = cy + r * 0.60;
    canvas.drawLine(Offset(cx - r * 0.36, baseY - r * 0.20), Offset(cx - r * 0.36, baseY), _linePaint(1.8));
    canvas.drawLine(Offset(cx + r * 0.36, baseY - r * 0.20), Offset(cx + r * 0.36, baseY), _linePaint(1.8));
    canvas.drawLine(Offset(cx - r * 0.36, baseY), Offset(cx + r * 0.36, baseY), _linePaint(1.8));
    canvas.drawLine(Offset(cx - r * 0.24, baseY + r * 0.20), Offset(cx + r * 0.24, baseY + r * 0.20), _linePaint(1.8));

    final filament = Path()
      ..moveTo(cx - r * 0.15, baseY - r * 0.20)
      ..lineTo(cx - r * 0.05, cy + r * 0.05)
      ..lineTo(cx + r * 0.05, cy + r * 0.05)
      ..lineTo(cx + r * 0.15, baseY - r * 0.20);
    canvas.drawPath(filament, _linePaint(1.2, opacity: 0.75));
  }

  @override
  bool shouldRepaint(_BulbIconPainter oldDelegate) => oldDelegate.glow != glow;
}

// 2. Fan
class _FanIconPainter extends CustomPainter {
  const _FanIconPainter({required this.glow});
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final r = size.width * 0.28;

    if (glow > 0.1) {
      canvas.drawCircle(Offset(cx, cy), r * 0.40, _glowPaint(8, glow));
    }

    canvas.drawCircle(Offset(cx, cy), r * 0.14, _linePaint(1.8));

    for (int i = 0; i < 3; i++) {
      final baseAngle = i * (2 * math.pi / 3);
      final path = Path()
        ..moveTo(
          cx + r * 0.14 * math.cos(baseAngle + math.pi * 0.4),
          cy + r * 0.14 * math.sin(baseAngle + math.pi * 0.4),
        )
        ..cubicTo(
          cx + r * 0.55 * math.cos(baseAngle - math.pi * 0.22),
          cy + r * 0.55 * math.sin(baseAngle - math.pi * 0.22),
          cx + r * 0.72 * math.cos(baseAngle + math.pi * 0.18),
          cy + r * 0.72 * math.sin(baseAngle + math.pi * 0.18),
          cx + r * 0.82 * math.cos(baseAngle),
          cy + r * 0.82 * math.sin(baseAngle),
        )
        ..cubicTo(
          cx + r * 0.65 * math.cos(baseAngle + math.pi * 0.12),
          cy + r * 0.65 * math.sin(baseAngle + math.pi * 0.12),
          cx + r * 0.40 * math.cos(baseAngle + math.pi * 0.35),
          cy + r * 0.40 * math.sin(baseAngle + math.pi * 0.35),
          cx + r * 0.14 * math.cos(baseAngle + math.pi * 0.60),
          cy + r * 0.14 * math.sin(baseAngle + math.pi * 0.60),
        );
      canvas.drawPath(path, _linePaint(1.8));
    }
  }

  @override
  bool shouldRepaint(_FanIconPainter oldDelegate) => oldDelegate.glow != glow;
}

// 3. Socket
class _SocketIconPainter extends CustomPainter {
  const _SocketIconPainter({required this.glow});
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final r = size.width * 0.26;

    if (glow > 0.1) {
      canvas.drawCircle(Offset(cx, cy), r * 0.85, _glowPaint(8, glow));
    }

    canvas.drawCircle(Offset(cx, cy), r, _linePaint(1.8));

    final sw = r * 0.16;
    final sh = r * 0.38;
    final sg = r * 0.30;

    for (final dx in <double>[-sg, sg]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx + dx, cy - r * 0.08),
            width: sw,
            height: sh,
          ),
          Radius.circular(sw / 2),
        ),
        _linePaint(1.8),
      );
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + r * 0.48),
          width: sw,
          height: sh * 0.70,
        ),
        Radius.circular(sw / 2),
      ),
      _linePaint(1.8),
    );
  }

  @override
  bool shouldRepaint(_SocketIconPainter oldDelegate) => oldDelegate.glow != glow;
}

// 4. Temperature / Thermometer
class _ThermoIconPainter extends CustomPainter {
  const _ThermoIconPainter({required this.glow});
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final r = size.width * 0.28;

    if (glow > 0.1) {
      canvas.drawCircle(Offset(cx, cy + r * 0.50), r * 0.35, _glowPaint(8, glow));
    }

    final tw = r * 0.32;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy - r * 0.18),
          width: tw,
          height: r * 1.20,
        ),
        Radius.circular(tw / 2),
      ),
      _linePaint(1.8),
    );

    canvas.drawCircle(Offset(cx, cy + r * 0.65), r * 0.26, _linePaint(1.8));
    canvas.drawLine(
      Offset(cx, cy + r * 0.38),
      Offset(cx, cy - r * 0.20),
      _linePaint(2.4, opacity: 0.85),
    );

    for (int i = 0; i < 4; i++) {
      final ty = cy - r * 0.15 + i * r * 0.28;
      canvas.drawLine(
        Offset(cx + tw / 2, ty),
        Offset(cx + tw / 2 + r * 0.16, ty),
        _linePaint(1.2, opacity: 0.60),
      );
    }
  }

  @override
  bool shouldRepaint(_ThermoIconPainter oldDelegate) => oldDelegate.glow != glow;
}

// 5. Lock / Security
class _LockIconPainter extends CustomPainter {
  const _LockIconPainter({required this.glow});
  final double glow;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final r = size.width * 0.26;

    if (glow > 0.1) {
      canvas.drawCircle(Offset(cx, cy), r * 0.75, _glowPaint(8, glow));
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + r * 0.22),
          width: r * 1.30,
          height: r * 1.00,
        ),
        const Radius.circular(7),
      ),
      _linePaint(1.8),
    );

    final shackleRect = Rect.fromCenter(
      center: Offset(cx, cy - r * 0.26),
      width: r * 0.82,
      height: r * 0.70,
    );
    canvas.drawArc(shackleRect, math.pi, math.pi, false, _linePaint(1.8));
    canvas.drawLine(Offset(cx - r * 0.41, cy - r * 0.26), Offset(cx - r * 0.41, cy - r * 0.02), _linePaint(1.8));
    canvas.drawLine(Offset(cx + r * 0.41, cy - r * 0.26), Offset(cx + r * 0.41, cy - r * 0.02), _linePaint(1.8));

    canvas.drawCircle(Offset(cx, cy + r * 0.16), r * 0.15, _linePaint(1.8));
    canvas.drawLine(Offset(cx, cy + r * 0.31), Offset(cx, cy + r * 0.50), _linePaint(1.8));
  }

  @override
  bool shouldRepaint(_LockIconPainter oldDelegate) => oldDelegate.glow != glow;
}

// 6. Home + Wi-Fi (LAST - Final connection state exactly matching reference)
class _HomeWifiIconPainter extends CustomPainter {
  const _HomeWifiIconPainter({
    required this.glow,
    required this.waveProgress,
  });

  final double glow;
  final double waveProgress;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2.0;
    final cy = size.height / 2.0;
    final r = size.width * 0.38;

    if (glow > 0.1) {
      canvas.drawCircle(
        Offset(cx, cy),
        r * 0.55,
        _glowPaint(12, glow),
      );
    }

    // House walls
    final hW = r * 1.50;
    final hH = r * 0.88;
    final hT = cy - r * 0.02;
    final hB = hT + hH;
    final hL = cx - hW / 2;
    final hR = cx + hW / 2;

    canvas.drawPath(
      Path()
        ..moveTo(hL, hT)
        ..lineTo(hL, hB)
        ..lineTo(hR, hB)
        ..lineTo(hR, hT),
      _linePaint(1.8),
    );

    // Roof peak
    canvas.drawPath(
      Path()
        ..moveTo(hL - r * 0.08, hT)
        ..lineTo(cx, cy - r * 0.68)
        ..lineTo(hR + r * 0.08, hT),
      _linePaint(1.8),
    );

    // Wi-Fi concentric arcs inside the house
    final wcy = cy + r * 0.30;
    final wRadii = [r * 0.22, r * 0.38, r * 0.54];

    for (int i = 0; i < wRadii.length; i++) {
      final wr = wRadii[i];
      final phase = i * 0.15;
      final v = ((waveProgress - phase) / 0.50).clamp(0.0, 1.0);

      canvas.drawArc(
        Rect.fromCenter(center: Offset(cx, wcy), width: wr * 2, height: wr * 2),
        math.pi * 1.25,
        math.pi * 0.50,
        false,
        _linePaint(1.8, opacity: 0.35 + 0.65 * v),
      );
    }

    // Wi-Fi Center Dot
    canvas.drawCircle(
      Offset(cx, wcy + r * 0.08),
      2.5,
      Paint()..color = _SplashColors.goldMain,
    );
  }

  @override
  bool shouldRepaint(_HomeWifiIconPainter oldDelegate) =>
      oldDelegate.glow != glow || oldDelegate.waveProgress != waveProgress;
}

// ---------------------------------------------------------------------------
// SPLASH FADE PAGE ROUTE
// ---------------------------------------------------------------------------
class _SplashFadePageRoute<T> extends PageRouteBuilder<T> {
  _SplashFadePageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, anim1, anim2) => builder(context),
          transitionsBuilder: (context, anim1, anim2, child) =>
              FadeTransition(opacity: anim1, child: child),
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 200),
        );
}
