import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userCtrl = TextEditingController();
  final TextEditingController _passCtrl = TextEditingController();
  final FocusNode _userFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();

  bool _obscurePassword = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _userCtrl.dispose();
    _passCtrl.dispose();
    _userFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });

    // Tiny delay so the press feedback feels intentional, not instant flicker.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    final user =
        await AuthService.instance.login(_userCtrl.text, _passCtrl.text);
    if (!mounted) return;

    if (user == null) {
      setState(() {
        _busy = false;
        _error = 'Invalid credentials. Check your username and password.';
      });
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: AppMotion.base,
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: const HomeScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle olive radial wash behind the card.
            Positioned(
              top: -100,
              right: -120,
              child: Container(
                width: 360,
                height: 360,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x22A8B870), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [Color(0x1A8E9474), Colors.transparent],
                  ),
                ),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.lg,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Logo(),
                      const SizedBox(height: AppSpacing.lg),
                      _GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Welcome back', style: AppText.title),
                            const SizedBox(height: 6),
                            Text(
                              'Sign in to continue to the civic dashboard.',
                              style: AppText.caption,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _GlassField(
                              controller: _userCtrl,
                              focusNode: _userFocus,
                              label: 'USERNAME',
                              hint: 'Enter username',
                              icon: Icons.person_outline_rounded,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _passFocus.requestFocus(),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _GlassField(
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              label: 'PASSWORD',
                              hint: 'Enter your password',
                              icon: Icons.lock_outline_rounded,
                              obscure: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _attemptLogin(),
                              trailing: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                splashRadius: 18,
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  color: AppColors.textSecondary,
                                  size: 18,
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: AppSpacing.sm),
                              _ErrorChip(message: _error!),
                            ],
                            const SizedBox(height: AppSpacing.md),
                            _SignInButton(
                              busy: _busy,
                              onTap: _busy ? null : _attemptLogin,
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            const _DemoHint(),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        '© FixMyStreet AI · Ras Al Khaimah',
                        textAlign: TextAlign.center,
                        style: AppText.metadata,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo ────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: const Color(0xFFB4C281),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFB4C281).withValues(alpha: 0.28),
                blurRadius: 36,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFFB4C281).withValues(alpha: 0.10),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg - 2),
            child: Image.asset(
              'assets/images/logo.png',
              width: 120,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'FixMyStreet AI',
          textAlign: TextAlign.center,
          style: AppText.display.copyWith(
            fontSize: 26,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Civic intelligence for Ras Al Khaimah',
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: AppColors.olive),
        ),
      ],
    );
  }
}

// ─── Glass panel container ──────────────────────────────────────────────────

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.olive.withValues(alpha: 0.20),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 32,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Glass input field ──────────────────────────────────────────────────────

class _GlassField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String label;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  const _GlassField({
    required this.controller,
    required this.focusNode,
    required this.label,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  @override
  State<_GlassField> createState() => _GlassFieldState();
}

class _GlassFieldState extends State<_GlassField> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_onFocusChange);
    super.dispose();
  }

  void _onFocusChange() {
    if (!mounted) return;
    setState(() => _focused = widget.focusNode.hasFocus);
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = _focused
        ? AppColors.olive
        : AppColors.olive.withValues(alpha: 0.18);
    final iconColor = _focused ? AppColors.olive : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: AppText.label),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: AnimatedContainer(
              duration: AppMotion.base,
              curve: AppMotion.easeOut,
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: borderColor, width: 1.2),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(widget.icon, color: iconColor, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      obscureText: widget.obscure,
                      textInputAction: widget.textInputAction,
                      onSubmitted: widget.onSubmitted,
                      cursorColor: AppColors.olive,
                      style: AppText.body.copyWith(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 14),
                        border: InputBorder.none,
                        hintText: widget.hint,
                        hintStyle: AppText.caption.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  if (widget.trailing != null) widget.trailing!,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Sign-in button ─────────────────────────────────────────────────────────

class _SignInButton extends StatefulWidget {
  final bool busy;
  final VoidCallback? onTap;

  const _SignInButton({required this.busy, required this.onTap});

  @override
  State<_SignInButton> createState() => _SignInButtonState();
}

class _SignInButtonState extends State<_SignInButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    final bg = disabled ? AppColors.oliveDim : AppColors.olive;
    const fg = Color(0xFF111310);

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
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.olive.withValues(alpha: 0.30),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.busy) ...[
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: fg,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  const Icon(Icons.login_rounded, color: fg, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.busy ? 'Signing in' : 'Sign in',
                  style: AppText.button.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Error + demo hint ──────────────────────────────────────────────────────

class _ErrorChip extends StatelessWidget {
  final String message;
  const _ErrorChip({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.danger.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppText.caption.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DemoHint extends StatelessWidget {
  const _DemoHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.oliveGhost,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.olive,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppText.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 11.5,
                ),
                children: const [
                  TextSpan(
                    text: 'Demo accounts · ',
                    style: TextStyle(
                      color: AppColors.olive,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: 'Resident1 / 123  ·  CityAdmin / 12345'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
