import 'package:flutter/material.dart';

/// Visualizes a 1–10 severity score with a glowing pill and color ramp.
class SeverityIndicator extends StatelessWidget {
  final int severity;
  final bool compact;

  const SeverityIndicator({
    super.key,
    required this.severity,
    this.compact = false,
  });

  /// Severity → vibrant neon color.
  /// 7-10 critical (neon red), 4-6 moderate (neon amber), 1-3 minor (neon green).
  static Color colorFor(int severity) {
    if (severity >= 7) return const Color(0xFFFF1744); // neon red — critical
    if (severity >= 4) return const Color(0xFFFFAB00); // neon amber — moderate
    return const Color(0xFF00E676); // neon green — minor
  }

  static String labelFor(int severity) {
    if (severity >= 7) return 'CRITICAL';
    if (severity >= 4) return 'MODERATE';
    return 'MINOR';
  }

  @override
  Widget build(BuildContext context) {
    final s = severity.clamp(1, 10);
    final color = colorFor(s);
    final label = labelFor(s);

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.8), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.55),
              blurRadius: 12,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Text(
          '$s · $label',
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            // Label itself is color-coded so urgency reads at a glance.
            Text(
              'SEVERITY',
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
            ),
            const Spacer(),
            Text(
              '$s / 10',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
                shadows: [
                  Shadow(color: color.withValues(alpha: 0.7), blurRadius: 10),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(
                height: 8,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              FractionallySizedBox(
                widthFactor: s / 10,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.4),
                        color,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.7),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Corner ribbon badge for report cards. Shows CRITICAL / MODERATE / MINOR
/// in the severity color — designed to be Positioned at top: 0, right: 0.
class StatusTag extends StatelessWidget {
  final int severity;

  const StatusTag({super.key, required this.severity});

  @override
  Widget build(BuildContext context) {
    final s = severity.clamp(1, 10);
    final color = SeverityIndicator.colorFor(s);
    final label = SeverityIndicator.labelFor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(18),
          bottomLeft: Radius.circular(12),
        ),
        border: Border.all(color: color.withValues(alpha: 0.85), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.45),
            blurRadius: 14,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.8,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.7), blurRadius: 6),
          ],
        ),
      ),
    );
  }
}

/// Glowing dot marker whose size and glow intensity scale with severity.
/// Critical markers (7+) pulse continuously to draw attention on the map.
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
      duration: const Duration(milliseconds: 800),
    );
    _pulse = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.severity >= 7) _ctrl.repeat(reverse: true);
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

    final double baseBlur;
    final double baseGlowAlpha;
    final double spread;
    if (s >= 7) {
      baseBlur = 20;
      baseGlowAlpha = 0.9;
      spread = 2.5;
    } else if (s >= 4) {
      baseBlur = 12;
      baseGlowAlpha = 0.6;
      spread = 1;
    } else {
      baseBlur = 8;
      baseGlowAlpha = 0.45;
      spread = 0.5;
    }

    if (s >= 7) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: baseGlowAlpha * _pulse.value),
                blurRadius: baseBlur * _pulse.value,
                spreadRadius: spread * _pulse.value,
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: baseGlowAlpha),
            blurRadius: baseBlur,
            spreadRadius: spread,
          ),
        ],
      ),
    );
  }
}
