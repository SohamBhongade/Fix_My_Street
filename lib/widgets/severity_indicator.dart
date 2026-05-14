import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Muted, earthy severity palette aligned with the dark olive design system.
class SeverityIndicator {
  SeverityIndicator._();

  /// Severity → muted, desaturated color (no neon).
  static Color colorFor(int severity) {
    if (severity >= 7) return AppColors.critical;
    if (severity >= 4) return AppColors.moderate;
    return AppColors.minor;
  }

  static String labelFor(int severity) {
    if (severity >= 7) return 'Critical';
    if (severity >= 4) return 'Moderate';
    return 'Minor';
  }
}

/// Compact severity chip: a small dot + label. Restrained, no glow.
class SeverityChip extends StatelessWidget {
  final int severity;
  final bool showScore;

  const SeverityChip({
    super.key,
    required this.severity,
    this.showScore = true,
  });

  @override
  Widget build(BuildContext context) {
    final s = severity.clamp(1, 10);
    final color = SeverityIndicator.colorFor(s);
    final label = SeverityIndicator.labelFor(s);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            showScore ? '$label · $s/10' : label,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Map marker: subtle filled dot with a soft halo. Critical severity pulses
/// gently in olive halo (slow, restrained — not flashy).
class SeverityDot extends StatefulWidget {
  final int severity;

  const SeverityDot({super.key, required this.severity});

  /// Tile-space size — also use this for the enclosing Marker width/height.
  static double sizeFor(int severity) {
    if (severity >= 7) return 28;
    if (severity >= 4) return 22;
    return 18;
  }

  @override
  State<SeverityDot> createState() => _SeverityDotState();
}

class _SeverityDotState extends State<SeverityDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulse = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
    );
    if (widget.severity >= 7) _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.severity.clamp(1, 10);
    final color = SeverityIndicator.colorFor(s);
    final size = SeverityDot.sizeFor(s);
    final innerSize = size * 0.45;

    final dot = Container(
      width: innerSize,
      height: innerSize,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFEBEAE3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 8,
            spreadRadius: 0,
          ),
        ],
      ),
    );

    if (s < 7) {
      return Center(
        child: SizedBox(width: size, height: size, child: Center(child: dot)),
      );
    }

    // Critical: olive-tinted ring slowly pulses outward.
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, _) {
              final t = _pulse.value;
              return Opacity(
                opacity: (1 - t) * 0.55,
                child: Container(
                  width: size * (0.5 + t * 0.5),
                  height: size * (0.5 + t * 0.5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.7),
                      width: 1.2,
                    ),
                  ),
                ),
              );
            },
          ),
          dot,
        ],
      ),
    );
  }
}
