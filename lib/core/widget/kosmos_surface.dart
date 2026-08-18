import 'package:flutter/material.dart';

/// Opaque, lightweight Kosmos Material surface.
/// It deliberately has no blur or transparency so text stays readable on
/// older Samsung devices.
class KosmosSurface extends StatelessWidget {
  const KosmosSurface({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.border,
    this.highlight = true,
    this.shadow = true,
    this.gradientTint,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Border? border;
  final bool highlight;
  final bool shadow;
  final Gradient? gradientTint;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    final tint =
        gradientTint ??
        const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF5F2FF)],
        );
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: border ?? Border.all(color: const Color(0xFFE1DBF5)),
        gradient: tint,
        boxShadow: shadow ? const [BoxShadow(color: Color(0x1A4B4B8C), blurRadius: 22, offset: Offset(0, 10))] : null,
      ),
      child: Stack(
        children: [
          if (highlight)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.center,
                      colors: [Color(0x12FFFFFF), Color(0x00FFFFFF)],
                    ),
                  ),
                ),
              ),
            ),
          Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ],
      ),
    );
    return Container(
      margin: margin,
      child: ClipRRect(borderRadius: radius, child: surface),
    );
  }
}
