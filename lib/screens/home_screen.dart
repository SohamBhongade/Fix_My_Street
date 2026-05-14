import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/severity_indicator.dart';
import '../widgets/surface_card.dart';
import 'camera_screen.dart';
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
  late Stream<List<ReportModel>> _reportStream;

  @override
  void initState() {
    super.initState();
    _reportStream =
        DatabaseService.instance.watchReports().asBroadcastStream();
  }

  void _navigate(Widget page) {
    Navigator.of(context)
        .push(_fadeRoute(page))
        .then((_) {
      if (!mounted) return;
      setState(() {
        _reportStream =
            DatabaseService.instance.watchReports().asBroadcastStream();
      });
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
              const _BrandHeader(),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: StreamBuilder<List<ReportModel>>(
                  stream: _reportStream,
                  builder: (context, snapshot) {
                    final reports = snapshot.data ?? const [];
                    final loading = !snapshot.hasData;
                    return _MapHeroCard(
                      reports: reports,
                      loading: loading,
                      onExplore: () => _navigate(const MapExploreScreen()),
                      onMarkerTap: (r) =>
                          _navigate(IssueDetailScreen(report: r)),
                    );
                  },
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
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.place_outlined,
              color: AppColors.olive,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Column(
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
        ],
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
