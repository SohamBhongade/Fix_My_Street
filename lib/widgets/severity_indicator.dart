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

  static Color colorFor(int severity) {
    if (severity >= 8) return const Color(0xFFFF1744); // red — critical
    if (severity >= 5) return const Color(0xFFFFAB00); // amber — moderate
    return const Color(0xFF00E676); // green — minor
  }

  static String labelFor(int severity) {
    if (severity >= 8) return 'CRITICAL';
    if (severity >= 5) return 'MODERATE';
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
            Text(
              'SEVERITY',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 12,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
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
