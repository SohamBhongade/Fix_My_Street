import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary action button — solid olive on dark.
class PrimaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;
  final double height;
  final bool expand;

  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.busy = false,
    this.height = 52,
    this.expand = true,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.busy;
    final bg = disabled ? AppColors.oliveDim : AppColors.olive;
    final fg = disabled ? AppColors.textTertiary : const Color(0xFF111310);

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.busy) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(color: fg, strokeWidth: 2),
          ),
          const SizedBox(width: 10),
        ] else if (widget.icon != null) ...[
          Icon(widget.icon, color: fg, size: 18),
          const SizedBox(width: 8),
        ],
        Text(widget.label, style: AppText.button.copyWith(color: fg)),
      ],
    );

    return AnimatedScale(
      scale: _pressed && !disabled ? 0.985 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.easeOut,
          height: widget.height,
          width: widget.expand ? double.infinity : null,
          padding: widget.expand
              ? null
              : const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}

/// Secondary button — transparent dark surface with subtle border.
class SecondaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool expand;
  final Color? accent;

  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 52,
    this.expand = true,
    this.accent,
  });

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final accent = widget.accent ?? AppColors.textPrimary;
    final color = disabled ? AppColors.textDisabled : accent;

    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, color: color, size: 18),
          const SizedBox(width: 8),
        ],
        Text(widget.label, style: AppText.button.copyWith(color: color)),
      ],
    );

    return AnimatedScale(
      scale: _pressed && !disabled ? 0.985 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.base,
          curve: AppMotion.easeOut,
          height: widget.height,
          width: widget.expand ? double.infinity : null,
          padding: widget.expand
              ? null
              : const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: _pressed ? AppColors.surfaceHigh : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.divider, width: 1),
          ),
          child: Center(child: content),
        ),
      ),
    );
  }
}
