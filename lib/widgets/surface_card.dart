import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A clean, premium card surface — soft elevation, no borders by default,
/// gentle press feedback. The foundation primitive for all panels.
class SurfaceCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double radius;
  final Color? color;
  final VoidCallback? onTap;
  final bool elevated;
  final Color? borderColor;

  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.sm),
    this.margin = EdgeInsets.zero,
    this.radius = AppRadius.md,
    this.color,
    this.onTap,
    this.elevated = true,
    this.borderColor,
  });

  @override
  State<SurfaceCard> createState() => _SurfaceCardState();
}

class _SurfaceCardState extends State<SurfaceCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.radius);
    final isInteractive = widget.onTap != null;

    final card = AnimatedScale(
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      scale: _pressed ? 0.985 : 1.0,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.easeOut,
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color ?? AppColors.surface,
          borderRadius: radius,
          border: widget.borderColor != null
              ? Border.all(color: widget.borderColor!, width: 1)
              : null,
          boxShadow: widget.elevated
              ? const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 24,
                    offset: Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 4,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: widget.child,
      ),
    );

    if (!isInteractive) {
      return Padding(padding: widget.margin, child: card);
    }

    return Padding(
      padding: widget.margin,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: card,
      ),
    );
  }
}
