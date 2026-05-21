import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/severity_indicator.dart';
import '../widgets/surface_card.dart';
import 'camera_screen.dart';
import 'exp_info_screen.dart';
import 'issue_console_screen.dart';
import 'issue_detail_screen.dart';
import 'map_explore_screen.dart';

const LatLng _kRakCenter = LatLng(25.7911, 55.9432);
const double _kRakZoom = 11.0;

const String _kDarkTileUrl =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  StreamSubscription<List<ReportModel>>? _reportSub;
  List<ReportModel> _reports = const [];
  // `true` only until the first emission lands — after that, the map shell
  // is always populated, even if a later poll fails. Prevents the "stuck
  // spinner" state when the very first fetch hangs or errors.
  bool _initialLoad = true;

  @override
  void initState() {
    super.initState();
    _subscribeReports();
    _refreshUserExp();
  }

  void _subscribeReports() {
    _reportSub?.cancel();
    _reportSub = DatabaseService.instance.watchReports().listen(
      (data) {
        if (!mounted) return;
        setState(() {
          _reports = data;
          _initialLoad = false;
        });
      },
      onError: (_) {
        // watchReports already swallows + yields the cached list, so an
        // error here is unexpected — flip out of the loading state so the
        // map renders regardless.
        if (!mounted) return;
        setState(() => _initialLoad = false);
      },
    );
  }

  @override
  void dispose() {
    _reportSub?.cancel();
    super.dispose();
  }

  /// Pulls the latest currentExp from the MongoDB users document so the
  /// header chip always reflects the live value. Cheap no-op if the user
  /// is logged out or the DB is unreachable.
  ///
  /// Always calls setState when the user is signed in — even if the DB
  /// value matches the local cache. The reason: when an upstream flow
  /// (ai_preview_screen, issue_detail_screen) optimistically updates
  /// AuthService before this method runs, the values will match here,
  /// and we still need to force a rebuild so the header chip picks up
  /// the just-changed `AuthService.currentUser.currentExp`.
  Future<void> _refreshUserExp() async {
    final user = AuthService.instance.currentUser;
    if (user == null) return;
    try {
      final exp = await DatabaseService.instance
          .fetchOrSeedUserExp(user.username, user.currentExp);
      if (!mounted) return;
      if (exp > user.currentExp) {
        AuthService.instance.updateCurrentExp(exp);
      }
      setState(() {});
    } catch (_) {
      // Stay on the cached value — login-time fetch already populated it.
      // Still rebuild so any optimistic AuthService update lands on screen.
      if (mounted) setState(() {});
    }
  }

  void _navigate(Widget page) {
    Navigator.of(context).push(_fadeRoute(page)).then((_) async {
      if (!mounted) return;
      // One-shot refresh so a report submitted on the camera flow lands on
      // the map immediately, without waiting for the next 3s poll tick.
      // The active subscription stays attached — it'll receive the fresh
      // list on its next yield too.
      try {
        final fresh = await DatabaseService.instance.fetchReports();
        if (!mounted) return;
        setState(() {
          _reports = fresh;
          _initialLoad = false;
        });
      } catch (_) {
        // Polling will catch up.
      }
      // Also pull the current user's EXP — the camera flow awards +50 on
      // submit and an admin verifying a task may credit the volunteer
      // +250. Re-reading here means the header chip reflects the new
      // total the moment the user lands back on home, no restart needed.
      await _refreshUserExp();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BrandHeader(),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: _MapHeroCard(
                  reports: _reports,
                  loading: _initialLoad && _reports.isEmpty,
                  onExplore: () => _navigate(const MapExploreScreen()),
                  onMarkerTap: (r) => _navigate(IssueDetailScreen(report: r)),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _ActionRow(
                icon: Icons.camera_alt_outlined,
                title: 'Report an issue',
                subtitle: 'Capture a photo · AI analyzes severity instantly',
                onTap: () => _navigate(const CameraScreen()),
              ),
              const SizedBox(height: AppSpacing.xs),
              _ActionRow(
                icon: Icons.dashboard_outlined,
                title: 'Issue console',
                subtitle: 'Track, prioritize and resolve reported issues',
                onTap: () => _navigate(const IssueConsoleScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

PageRoute<T> _fadeRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: AppMotion.base,
    reverseTransitionDuration: AppMotion.fast,
    pageBuilder: (_, animation, _) => FadeTransition(
      opacity: animation,
      child: page,
    ),
  );
}

// ─── Brand Header ────────────────────────────────────────────────────────────

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: const Color(0xFFB4C281),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFB4C281).withValues(alpha: 0.22),
                  blurRadius: 14,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm - 1.5),
              child: Image.asset(
                'assets/images/logo.png',
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'FixMyStreet',
                  style: AppText.title.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Ras Al Khaimah · Civic Intelligence',
                  // Muted olive-gray to tie the header into the olive identity.
                  style: AppText.metadata.copyWith(
                    color: const Color(0xFF8E9474),
                  ),
                ),
              ],
            ),
          ),
          if (user != null) ...[
            const SizedBox(width: AppSpacing.xs),
            _UserChip(
              icon: user.pfpIcon,
              label: user.isCityAdmin ? 'Admin' : user.headerStatus,
              progress: user.expProgress,
              showProgress: !user.isCityAdmin,
              onTap: () => _openExpInfo(context),
            ),
          ],
        ],
      ),
    );
  }

  void _openExpInfo(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: AppMotion.base,
        reverseTransitionDuration: AppMotion.fast,
        pageBuilder: (_, animation, _) => FadeTransition(
          opacity: animation,
          child: const ExpInfoScreen(),
        ),
      ),
    );
  }
}

/// PFP icon + EXP value + progress bar in the header.
///
/// Glassmorphism: a translucent dark surface (`BackdropFilter` blur) ringed
/// with a thin olive border. The bar to the right uses dual-tone olive — a
/// dark base with a glowing sage fill — to track progress toward the next
/// EXP milestone.
///
/// Tap to log out.
class _UserChip extends StatefulWidget {
  final IconData icon;
  final String label;
  final double progress;
  // Admins read as a static role label ("Admin") so the chip drops the EXP
  // bar — only residents accumulate progress toward a milestone.
  final bool showProgress;
  final VoidCallback onTap;

  const _UserChip({
    required this.icon,
    required this.label,
    required this.progress,
    required this.showProgress,
    required this.onTap,
  });

  @override
  State<_UserChip> createState() => _UserChipState();
}

class _UserChipState extends State<_UserChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: AppColors.olive.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.bgBase,
                      shape: BoxShape.circle,
                    ),
                    child:
                        Icon(widget.icon, color: AppColors.olive, size: 14),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    widget.label,
                    // Residents get tabular figures so the EXP count stays
                    // aligned as it grows; admins get a slightly tighter
                    // weight for the static "Admin" label.
                    style: AppText.caption.copyWith(
                      color: AppColors.olive,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: widget.showProgress ? 0.2 : 0.4,
                      fontFeatures: widget.showProgress
                          ? const [FontFeature.tabularFigures()]
                          : const [],
                    ),
                  ),
                  if (widget.showProgress) ...[
                    const SizedBox(width: 8),
                    _ExpBar(progress: widget.progress),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dual-tone olive EXP bar — dark base with a glowing sage fill.
class _ExpBar extends StatelessWidget {
  final double progress;
  const _ExpBar({required this.progress});

  @override
  Widget build(BuildContext context) {
    final fillFraction = progress.clamp(0.0, 1.0);
    return Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        // Dark olive bed — bottom layer of the dual-tone bar.
        color: AppColors.oliveDim,
        borderRadius: BorderRadius.circular(2.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(2.5),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fillFraction,
            child: Container(
              decoration: BoxDecoration(
                // Lighter sage fill, gradient from soft → bright olive.
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppColors.oliveSoft, AppColors.olive],
                ),
                // Soft halo so the bar feels emissive without being neon.
                boxShadow: [
                  BoxShadow(
                    color: AppColors.olive.withValues(alpha: 0.50),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Map Hero Card ────────────────────────────────────────────────────────────

class _MapHeroCard extends StatelessWidget {
  final List<ReportModel> reports;
  final bool loading;
  final VoidCallback onExplore;
  final ValueChanged<ReportModel> onMarkerTap;

  const _MapHeroCard({
    required this.reports,
    required this.loading,
    required this.onExplore,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    // Outer container paints a 1.5px olive gradient as a "border" by drawing
    // a gradient-filled rounded rect; the inner ClipRRect insets by that
    // amount so the gradient stays visible around the map.
    return Container(
      padding: const EdgeInsets.all(1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.olive,
            AppColors.oliveSoft,
            AppColors.oliveDim,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg - 1.5),
        child: Container(
          decoration: const BoxDecoration(color: AppColors.surface),
          child: Stack(
            fit: StackFit.expand,
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: _kRakCenter,
                initialZoom: _kRakZoom,
                interactionOptions:
                    InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate: _kDarkTileUrl,
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                if (!loading && reports.isNotEmpty)
                  MarkerLayer(
                    markers: reports.map((r) {
                      final dotSize = SeverityDot.sizeFor(r.severity);
                      return Marker(
                        point: LatLng(r.latitude, r.longitude),
                        width: dotSize,
                        height: dotSize,
                        // HitTestBehavior.opaque — every pin gets the full
                        // marker box as a tap target, regardless of
                        // severity. The inner SeverityDot only paints
                        // ~45% of the marker for Minor/Moderate; without
                        // opaque hit-testing, taps on the surrounding
                        // empty space would fall through and the report
                        // detail sheet would never open.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onMarkerTap(r),
                          child: SeverityDot(severity: r.severity),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            if (loading)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.olive,
                    strokeWidth: 2,
                  ),
                ),
              ),
            // Floating blurred header chip — live count.
            Positioned(
              top: AppSpacing.sm,
              left: AppSpacing.sm,
              child: _FloatingChip(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: AppColors.olive,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      loading
                          ? 'Loading'
                          : '${reports.length} live ${reports.length == 1 ? 'report' : 'reports'}',
                      style: AppText.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Floating CTA at bottom.
            Positioned(
              left: AppSpacing.sm,
              right: AppSpacing.sm,
              bottom: AppSpacing.sm,
              child: _FloatingPanel(
                onTap: onExplore,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore live map',
                            style: AppText.heading.copyWith(fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            loading
                                ? 'Loading reports across Ras Al Khaimah'
                                : reports.isEmpty
                                    ? 'No reports yet — be the first to submit'
                                    : 'Tap a marker for details',
                            style: AppText.caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.olive,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Color(0xFF111310),
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  final Widget child;
  const _FloatingChip({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColors.mapSheetBg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.hairline, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FloatingPanel extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _FloatingPanel({required this.child, required this.onTap});

  @override
  State<_FloatingPanel> createState() => _FloatingPanelState();
}

class _FloatingPanelState extends State<_FloatingPanel> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.mapSheetBg,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.hairline, width: 1),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Action Row ──────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(icon, color: AppColors.olive, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.heading.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: AppColors.textTertiary,
            size: 14,
          ),
        ],
      ),
    );
  }
}
