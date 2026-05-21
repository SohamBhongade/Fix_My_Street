import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/severity_indicator.dart';

const String _darkTileUrl =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

class MapDetailsScreen extends StatefulWidget {
  final ReportModel report;

  const MapDetailsScreen({super.key, required this.report});

  @override
  State<MapDetailsScreen> createState() => _MapDetailsScreenState();
}

class _MapDetailsScreenState extends State<MapDetailsScreen> {
  bool _volunteering = false;
  late ReportStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.report.status;
  }

  bool get _alreadyAssigned => _currentStatus == ReportStatus.inProgress;
  // Severity > 3 is the universal volunteer guardrail — no role (resident
  // or admin) can self-assign these. The action panel hides the button
  // entirely and shows the municipal-only banner instead.
  bool get _requiresProfessional => widget.report.severity > 3;

  Future<void> _volunteer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text('Confirm volunteering', style: AppText.heading),
        content: Text(
          'Volunteer to fix "${widget.report.category}"?',
          style: AppText.bodySecondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppText.button.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'Yes, volunteer',
              style: AppText.button.copyWith(color: AppColors.olive),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final user = AuthService.instance.currentUser;
    if (user == null) return;

    setState(() => _volunteering = true);
    try {
      final updated = await DatabaseService.instance.volunteerForReport(
        id: widget.report.id!,
        user: user,
      );
      if (!mounted) return;
      setState(() {
        _currentStatus = updated.status;
        _volunteering = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You've volunteered. The community thanks you."),
        ),
      );
    } on VerificationRuleException catch (e) {
      if (!mounted) return;
      setState(() => _volunteering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _volunteering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  Marker _buildMarker() {
    final r = widget.report;
    final dotSize = SeverityDot.sizeFor(r.severity);
    return Marker(
      point: LatLng(r.latitude, r.longitude),
      width: dotSize,
      height: dotSize,
      child: SeverityDot(severity: r.severity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(r.latitude, r.longitude),
                    initialZoom: 15,
                    minZoom: 7,
                    cameraConstraint: CameraConstraint.containCenter(
                      bounds: LatLngBounds(
                        const LatLng(22.6, 51.5),
                        const LatLng(26.4, 56.6),
                      ),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _darkTileUrl,
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(markers: [_buildMarker()]),
                  ],
                ),
                Positioned(
                  top: topPadding + 8,
                  left: AppSpacing.sm,
                  child: _BackButton(
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 24,
                  offset: Offset(0, -8),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.md,
              AppSpacing.sm + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.category, style: AppText.title),
                          const SizedBox(height: 6),
                          Text(
                            r.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.caption,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    SeverityChip(severity: r.severity),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                _requiresProfessional
                    ? _buildProfessionalWarning()
                    : PrimaryButton(
                        label: _volunteering
                            ? 'Updating'
                            : _alreadyAssigned
                                ? 'Already assigned'
                                : 'Volunteer to fix',
                        busy: _volunteering,
                        height: 48,
                        onTap: (_alreadyAssigned || _volunteering)
                            ? null
                            : _volunteer,
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfessionalWarning() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.critical.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              color: AppColors.critical, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This is a high-severity critical issue. Please leave it to '
              'the municipal team.',
              style: AppText.caption.copyWith(
                color: AppColors.critical,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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
      scale: _pressed ? 0.92 : 1,
      duration: AppMotion.fast,
      curve: AppMotion.easeOut,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.mapSheetBg,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.hairline, width: 1),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
