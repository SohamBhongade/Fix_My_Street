import 'dart:ui';

import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'login_screen.dart';

/// Civic Rewards screen — explains how Residents earn EXP and hosts the
/// log-out action.
///
/// Layout: a back-button header, two glassmorphism reward cards (Volunteer +
/// Report) with photo headers, and a deep-red glassmorphism log-out button
/// pinned to the bottom of the scroll. The whole body is scrollable so the
/// log-out button stays reachable on smaller phones.
class ExpInfoScreen extends StatelessWidget {
  const ExpInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Stack(
          children: [
            // Soft olive radial wash — ties the screen to the LoginScreen
            // and brand identity without adding visual noise.
            Positioned(
              top: -120,
              right: -140,
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
              bottom: -140,
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
            Column(
              children: [
                const _RewardsHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.xs,
                      AppSpacing.md,
                      AppSpacing.md,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const _RewardsIntro(),
                            const SizedBox(height: AppSpacing.md),
                            _RewardCard(
                              imageUrl: '',
                              assetPath: 'assets/images/image_v.jpg',
                              fallbackIcon: Icons.volunteer_activism_rounded,
                              badge: 'VOLUNTEER',
                              title: 'Volunteer & Fix',
                              body:
                                  'Help resolve minor issues to earn 250 EXP per task.',
                              accentExp: '+250 EXP',
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _RewardCard(
                              imageUrl: '',
                              assetPath: 'assets/images/image.png',
                              fallbackIcon: Icons.photo_camera_outlined,
                              badge: 'REPORT',
                              title: 'Report Issues',
                              body:
                                  'Document infrastructure problems to earn 50 EXP per verified report.',
                              accentExp: '+50 EXP',
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            _LogoutButton(onTap: () => _handleLogout(context)),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Clears the in-memory session and returns the user to the login screen
  /// while wiping the navigation stack — so the back gesture from the login
  /// screen can't re-enter the authenticated area.
  void _handleLogout(BuildContext context) {
    AuthService.instance.logout();
    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        transitionDuration: AppMotion.base,
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: const LoginScreen(),
        ),
      ),
      (route) => false,
    );
  }
}

// ─── Header ─────────────────────────────────────────────────────────────────

class _RewardsHeader extends StatelessWidget {
  const _RewardsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          _BackButton(onTap: () => Navigator.of(context).maybePop()),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Civic Rewards',
                  style: AppText.title.copyWith(
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Earn EXP for keeping Ras Al Khaimah running',
                  style: AppText.metadata.copyWith(
                    color: const Color(0xFF8E9474),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: AppColors.olive.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: AppColors.olive,
            size: 18,
          ),
        ),
      ),
    );
  }
}

// ─── Intro line above the reward cards ──────────────────────────────────────

class _RewardsIntro extends StatelessWidget {
  const _RewardsIntro();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final exp = user?.currentExp ?? 0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: AppColors.olive.withValues(alpha: 0.20),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.oliveGhost,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.olive,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Your civic balance',
                      style: AppText.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$exp EXP',
                      style: AppText.title.copyWith(
                        color: AppColors.olive,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reward card ────────────────────────────────────────────────────────────

class _RewardCard extends StatelessWidget {
  final String imageUrl;
  // When set, renders a local asset instead of the network URL.
  final String? assetPath;
  final IconData fallbackIcon;
  final String badge;
  final String title;
  final String body;
  final String accentExp;

  const _RewardCard({
    required this.imageUrl,
    this.assetPath,
    required this.fallbackIcon,
    required this.badge,
    required this.title,
    required this.body,
    required this.accentExp,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.70),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: AppColors.olive.withValues(alpha: 0.22),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RewardImage(
                imageUrl: imageUrl,
                assetPath: assetPath,
                fallbackIcon: fallbackIcon,
                badge: badge,
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AppText.heading.copyWith(fontSize: 17),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.oliveGhost,
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            border: Border.all(
                              color: AppColors.olive.withValues(alpha: 0.45),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            accentExp,
                            style: AppText.caption.copyWith(
                              color: AppColors.olive,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      body,
                      style: AppText.bodySecondary.copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RewardImage extends StatelessWidget {
  final String imageUrl;
  final String? assetPath;
  final IconData fallbackIcon;
  final String badge;

  const _RewardImage({
    required this.imageUrl,
    this.assetPath,
    required this.fallbackIcon,
    required this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (assetPath != null)
            Image.asset(
              assetPath!,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              errorBuilder: (_, _, _) =>
                  _ImageFallback(icon: fallbackIcon, loading: false),
            )
          else
            Image.network(
              imageUrl,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return _ImageFallback(icon: fallbackIcon, loading: true);
              },
              errorBuilder: (_, _, _) =>
                  _ImageFallback(icon: fallbackIcon, loading: false),
            ),
          // Dark overlay — heavier than the network-card default so the
          // white 'Volunteer & Fix' text stays legible over the real photo.
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x55000000),
                  Color(0xCC0E100D),
                ],
              ),
            ),
          ),
          // Olive accent line at the bottom — visually separates the image
          // from the card text and reinforces the olive identity.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 1.5,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0x00A8B870),
                    AppColors.olive,
                    Color(0x00A8B870),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: AppSpacing.sm,
            left: AppSpacing.sm,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.bgBase.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.olive.withValues(alpha: 0.55),
                  width: 1,
                ),
              ),
              child: Text(
                badge,
                style: AppText.label.copyWith(
                  color: AppColors.olive,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final IconData icon;
  final bool loading;
  const _ImageFallback({required this.icon, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surfaceHigh,
            AppColors.surfaceOverlay,
            AppColors.bgElevated,
          ],
        ),
      ),
      child: Center(
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.olive,
                  strokeWidth: 2,
                ),
              )
            : Icon(
                icon,
                color: AppColors.olive.withValues(alpha: 0.85),
                size: 44,
              ),
      ),
    );
  }
}

// ─── Logout button ──────────────────────────────────────────────────────────

/// Glassmorphism log-out button — deep-red border and glow distinguish it
/// from the olive primary actions used elsewhere, while the translucent
/// blurred surface keeps it on-theme with the rest of the screen.
class _LogoutButton extends StatefulWidget {
  final VoidCallback onTap;
  const _LogoutButton({required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _pressed = false;

  // A slightly deeper, more saturated red than AppColors.danger — gives the
  // border + glow a real "warning" presence without going neon.
  static const Color _deepRed = Color(0xFF9E4A3A);

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: _deepRed.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: _deepRed.withValues(alpha: 0.65),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _deepRed.withValues(alpha: 0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.logout_rounded,
                      color: AppColors.danger,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Log out',
                      style: AppText.button.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
