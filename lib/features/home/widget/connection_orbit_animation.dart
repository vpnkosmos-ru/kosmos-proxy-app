import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';

/// Lightweight connection animation. The five displayed countries are a
/// deliberate, stable visual language and are never populated from technical
/// outbound tags.
class ConnectionOrbitAnimation extends StatefulWidget {
  const ConnectionOrbitAnimation({
    super.key,
    required this.child,
    required this.connecting,
    required this.connected,
    this.countryCode,
  });

  final Widget child;
  final bool connecting;
  final bool connected;
  final String? countryCode;

  @override
  State<ConnectionOrbitAnimation> createState() => _ConnectionOrbitAnimationState();
}

class _ConnectionOrbitAnimationState extends State<ConnectionOrbitAnimation>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(seconds: 10));
  bool _backgrounded = false;
  bool _reducedMotion = false;

  bool get _shouldAnimate => !_backgrounded && !_reducedMotion && (widget.connecting || widget.connected);

  void _syncAnimation() {
    if (_shouldAnimate) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
      if (!widget.connecting && !widget.connected) _controller.value = 0;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncAnimation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (reduced != _reducedMotion) {
      _reducedMotion = reduced;
      _syncAnimation();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _backgrounded =
        state == AppLifecycleState.inactive || state == AppLifecycleState.paused || state == AppLifecycleState.detached;
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant ConnectionOrbitAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.connecting || widget.connected;
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final radius = _orbitRadius(size);
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) => CustomPaint(
              painter: _OrbitPainter(
                progress: _controller.value,
                active: active,
                connecting: widget.connecting,
                reducedMotion: _reducedMotion,
                radius: radius,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (active)
                    for (var index = 0; index < _countries.length; index++)
                      _Planet(
                        progress: _controller.value,
                        index: index,
                        radius: radius,
                        selected: widget.connected && _selectedIndex(widget.countryCode) == index,
                        reducedMotion: _reducedMotion,
                      ),
                  child!,
                ],
              ),
            ),
            child: widget.child,
          );
        },
      ),
    );
  }
}

const _countries = <String>['de', 'nl', 'fi', 'us', 'pl'];

int? _selectedIndex(String? code) {
  if (code == null) return null;
  final normalized = code.toLowerCase().split('-').first;
  final index = _countries.indexOf(normalized);
  return index < 0 ? null : index;
}

double _orbitRadius(Size size) {
  final minDimension = math.min(size.width, size.height);
  // 30dp is the requested additional gap; clamp keeps all planets on small
  // screens while leaving the central 188dp button unobstructed.
  final safe = minDimension / 2 - 36;
  return math.max(112, math.min(154, safe));
}

class _Planet extends StatelessWidget {
  const _Planet({
    required this.progress,
    required this.index,
    required this.radius,
    required this.selected,
    required this.reducedMotion,
  });

  final double progress;
  final int index;
  final double radius;
  final bool selected;
  final bool reducedMotion;

  @override
  Widget build(BuildContext context) {
    final angle = (reducedMotion ? 0 : progress * math.pi * 2 * .12) + index * (math.pi * 2 / _countries.length);
    final size = selected ? 64.0 : 56.0;
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius * .56),
      child: AnimatedScale(
        scale: selected ? 1.04 : 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: size,
          height: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF8F7FF),
              border: Border.all(color: selected ? const Color(0xFF5B68D9) : const Color(0xFFE3DDF7), width: 2),
              boxShadow: [
                BoxShadow(color: const Color(0x36526AD7), blurRadius: selected ? 16 : 10, offset: const Offset(0, 5)),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: IPCountryFlag(countryCode: _countries[index], size: size - 8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  const _OrbitPainter({
    required this.progress,
    required this.active,
    required this.connecting,
    required this.reducedMotion,
    required this.radius,
  });

  final double progress;
  final bool active;
  final bool connecting;
  final bool reducedMotion;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final starPaint = Paint();
    for (var i = 0; i < 14; i++) {
      final x = ((i * 47 + 13) % 100) / 100 * size.width;
      final y = ((i * 67 + 29) % 100) / 100 * size.height;
      final pulse = reducedMotion ? .32 : .22 + .28 * (math.sin(progress * math.pi * 2 + i * .8).abs());
      starPaint.color = const Color(0xFF7774D8).withValues(alpha: pulse);
      canvas.drawCircle(Offset(x, y), 1.0 + i % 3 * .35, starPaint);
    }
    if (!active) return;

    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = connecting ? 1.35 : 1.1
      ..color = const Color(0x664E68D8);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = const Color(0x226A80F0);
    for (var i = 0; i < _countries.length; i++) {
      final angle = (reducedMotion ? 0 : progress * math.pi * 2 * .12) + i * (math.pi * 2 / _countries.length);
      final point = Offset(center.dx + math.cos(angle) * radius, center.dy + math.sin(angle) * radius * .56);
      final path = Path()
        ..moveTo(point.dx, point.dy)
        ..quadraticBezierTo(
          center.dx + (point.dx - center.dx) * .32,
          center.dy + (point.dy - center.dy) * .32 - 7,
          center.dx,
          center.dy,
        );
      canvas.drawPath(path, glow);
      canvas.drawPath(path, line);
      if (!reducedMotion) {
        final pulse = (progress + i / _countries.length) % 1;
        final metrics = path.computeMetrics().first;
        final tangent = metrics.getTangentForOffset(metrics.length * pulse);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, connecting ? 2.5 : 1.8, Paint()..color = const Color(0xC98CA5FF));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.connecting != connecting ||
      oldDelegate.reducedMotion != reducedMotion ||
      oldDelegate.radius != radius;
}
