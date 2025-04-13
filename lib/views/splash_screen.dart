import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:client/views/main_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(
                opacity: animation,
                child: child,
              );
            },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF050505), Color(0xFF121212)],
            ),
          ),
          child: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF151515),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Image.asset(
                            'assets/logo.png',
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.bar_chart,
                                size: 60,
                                color: Color(0xFF3A79FF),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Trading Monster App',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Smart trading with analytics',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF3A79FF).withOpacity(0.8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class MinimalistBackgroundPainter extends CustomPainter {
  final Color lineColor;
  final Color accentColor;
  final double progress;

  MinimalistBackgroundPainter({
    required this.lineColor,
    required this.accentColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final accentPaint = Paint()
      ..color = accentColor
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Рисуем тонкие горизонтальные линии
    final lineCount = 25;
    final lineSpace = size.height / lineCount;

    for (int i = 0; i <= lineCount; i++) {
      final y = i * lineSpace;
      final path = Path();

      // Ограничиваем прогресс линий
      final endX = size.width * progress;
      path.moveTo(0, y);
      path.lineTo(endX, y);

      canvas.drawPath(path, paint);
    }

    // Вертикальные линии справа
    final vertLineCount = 10;
    final vertLineSpace = size.width / vertLineCount;

    for (int i = 0; i <= vertLineCount; i++) {
      final x = i * vertLineSpace;
      final vertPath = Path();

      // Ограничиваем прогресс вертикальных линий
      final endY = size.height * progress;
      vertPath.moveTo(x, 0);
      vertPath.lineTo(x, endY);

      canvas.drawPath(vertPath, paint);
    }

    // Рисуем акцентную линию (трейдинговую)
    if (progress > 0.3) {
      final chartPath = Path();
      final chartProgress = math.min(1.0, (progress - 0.3) / 0.7);

      final List<Offset> points = [
        Offset(size.width * 0.1, size.height * 0.6),
        Offset(size.width * 0.3, size.height * 0.4),
        Offset(size.width * 0.5, size.height * 0.7),
        Offset(size.width * 0.7, size.height * 0.3),
        Offset(size.width * 0.9, size.height * 0.5),
      ];

      chartPath.moveTo(points[0].dx, points[0].dy);

      for (int i = 1; i < points.length; i++) {
        if (i / points.length <= chartProgress) {
          chartPath.lineTo(points[i].dx, points[i].dy);
        } else {
          final lastIndex = i - 1;
          final t = (chartProgress * points.length - lastIndex);
          final x = points[lastIndex].dx * (1 - t) + points[i].dx * t;
          final y = points[lastIndex].dy * (1 - t) + points[i].dy * t;
          chartPath.lineTo(x, y);
          break;
        }
      }

      canvas.drawPath(chartPath, accentPaint);
    }
  }

  @override
  bool shouldRepaint(MinimalistBackgroundPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class MinimalistChartPainter extends CustomPainter {
  final Color mainColor;
  final Color accentColor;

  MinimalistChartPainter({
    required this.mainColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.3;

    // Рисуем тонкую окружность
    final circlePaint = Paint()
      ..color = mainColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    canvas.drawCircle(center, radius, circlePaint);

    // Рисуем минималистичный график внутри круга
    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final linePath = Path();

    // Точки для графика
    final points = [
      Offset(center.dx - radius * 0.8, center.dy + radius * 0.2),
      Offset(center.dx - radius * 0.5, center.dy - radius * 0.3),
      Offset(center.dx - radius * 0.2, center.dy + radius * 0.1),
      Offset(center.dx + radius * 0.1, center.dy - radius * 0.5),
      Offset(center.dx + radius * 0.4, center.dy - radius * 0.2),
      Offset(center.dx + radius * 0.7, center.dy + radius * 0.4),
    ];

    linePath.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      linePath.lineTo(points[i].dx, points[i].dy);
    }

    canvas.drawPath(linePath, linePaint);

    // Рисуем вертикальные линии (свечи)
    final candlePaint = Paint()
      ..color = mainColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i < 5; i++) {
      final x = center.dx - radius * 0.6 + i * radius * 0.3;
      final topY = center.dy - radius * 0.2 - (i % 3) * radius * 0.1;
      final bottomY = center.dy + radius * 0.2 + (i % 2) * radius * 0.15;

      canvas.drawLine(Offset(x, topY), Offset(x, bottomY), candlePaint);
    }
  }

  @override
  bool shouldRepaint(MinimalistChartPainter oldDelegate) {
    return oldDelegate.mainColor != mainColor ||
        oldDelegate.accentColor != accentColor;
  }
}
