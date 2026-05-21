import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/severity_indicator.dart';
import 'map_details_screen.dart';

const String _darkTileUrl =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

const LatLng _rakCenter = LatLng(25.7911, 55.9432);
const double _rakZoom = 12.0;

final LatLngBounds _uaeBounds = LatLngBounds(
  const LatLng(22.5, 51.5),
  const LatLng(26.5, 56.5),
);

class MapExploreScreen extends StatefulWidget {
  const MapExploreScreen({super.key});

  @override
  State<MapExploreScreen> createState() => _MapExploreScreenState();
}

class _MapExploreScreenState extends State<MapExploreScreen> {
  final MapController _mapController = MapController();
  List<ReportModel> _reports = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    try {
      final reports = await DatabaseService.instance.fetchReports();
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _showSheet(ReportModel report) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReportSheet(
        report: report,
        onViewDetails: () {
          Navigator.of(context).pop();
          Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) => MapDetailsScreen(report: report),
                ),
              )
              .then((_) {
            if (mounted) _mapController.move(_rakCenter, _rakZoom);
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    final openCount =
        _reports.where((r) => r.status != ReportStatus.resolved).length;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _rakCenter,
              initialZoom: _rakZoom,
              minZoom: 7,
              cameraConstraint:
                  CameraConstraint.containCenter(bounds: _uaeBounds),
            ),
            children: [
              TileLayer(
                urlTemplate: _darkTileUrl,
                subdomains: const ['a', 'b', 'c', 'd'],
              ),
              if (!_loading)
                MarkerLayer(
                  markers: _reports.map((r) {
                    final dotSize = SeverityDot.sizeFor(r.severity);
                    return Marker(
                      point: LatLng(r.latitude, r.longitude),
                      width: dotSize,
                      height: dotSize,
                      // HitTestBehavior.opaque so the FULL marker box is
                      // tappable — not just the inner visible dot. Without
                      // this, Moderate/Minor pins (whose visible dot is
                      // ~45% of the marker size, with empty space around
                      // it) only fired onTap when the user landed
                      // directly on the tiny inner circle. Critical pins
                      // worked by accident because their pulse ring fills
                      // the marker bounds. Opaque hit-testing makes the
                      // tap target consistent across every severity.
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _showSheet(r),
                        child: SeverityDot(severity: r.severity),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
          if (_loading)
            const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.olive,
                  strokeWidth: 2,
                ),
              ),
            ),
          // Floating top bar (back + title + counter)
          Positioned(
            top: topPad + 8,
            left: AppSpacing.sm,
            right: AppSpacing.sm,
            child: _FloatingTopBar(
              title: 'Community map',
              subtitle: _loading
                  ? 'Loading'
                  : '$openCount open · ${_reports.length} total',
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
          // Floating legend bottom-left
          Positioned(
            left: AppSpacing.sm,
            bottom: AppSpacing.md,
            child: _Legend(),
          ),
        ],
      ),
    );
  }
}

class _FloatingTopBar extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _FloatingTopBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 10,
          ),
          decoration: BoxDecoration(
            color: AppColors.mapSheetBg,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.hairline, width: 1),
          ),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back_rounded,
                onTap: onBack,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: AppText.heading.copyWith(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppText.metadata),
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

class _CircleIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  State<_CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<_CircleIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.92 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.surfaceHigh,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(widget.icon, color: AppColors.textPrimary, size: 18),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.mapSheetBg,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.hairline, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('LEGEND', style: AppText.label),
              const SizedBox(height: 8),
              _legendRow(AppColors.critical, 'Critical'),
              const SizedBox(height: 4),
              _legendRow(AppColors.moderate, 'Moderate'),
              const SizedBox(height: 4),
              _legendRow(AppColors.minor, 'Minor'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppText.caption),
      ],
    );
  }
}

class _ReportSheet extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onViewDetails;

  const _ReportSheet({required this.report, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(
        AppSpacing.sm,
        0,
        AppSpacing.sm,
        AppSpacing.md + MediaQuery.of(context).padding.bottom,
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 32,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(child: Text(report.category, style: AppText.title)),
              const SizedBox(width: 8),
              SeverityChip(severity: report.severity),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.place_outlined,
                color: AppColors.textTertiary,
                size: 14,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  report.address,
                  style: AppText.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          PrimaryButton(
            label: 'View full details',
            icon: Icons.arrow_forward_rounded,
            onTap: onViewDetails,
            height: 48,
          ),
        ],
      ),
    );
  }
}
