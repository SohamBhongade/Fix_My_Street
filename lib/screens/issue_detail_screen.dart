import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';

// ─── Local navy-green / olive / orange palette ──────────────────────────────
const Color _kBg = Color(0xFF06091A);
const Color _kSurface = Color(0xFF0E1426);
const Color _kSurfaceHigh = Color(0xFF161E33);
// Deep olive green — replaces the old electric cyan as the primary accent.
const Color _kOlive = Color(0xFFA8B870);
// Desaturated, muted olive — used for solid button backgrounds.
const Color _kOliveMuted = Color(0xFF7E8854);
const Color _kOrange = Color(0xFFFF9100);
const Color _kTextPrimary = Color(0xFFEBEEF5);
const Color _kTextSecondary = Color(0xFF9AA5B8);
const Color _kTextTertiary = Color(0xFF606878);
const Color _kDivider = Color(0x1AFFFFFF);

const Color _kCritical = Color(0xFFE57373);
const Color _kModerate = _kOrange;
const Color _kMinor = Color(0xFF66BB6A);

const String _kLightTileUrl =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

/// Severity threshold at and above which a citizen cannot volunteer —
/// these high-severity tasks must be handled by RAK municipal teams.
const int _kVolunteerLockSeverity = 6;

Color _severityColor(int severity) {
  if (severity >= 7) return _kCritical;
  if (severity >= 4) return _kModerate;
  return _kMinor;
}

String _severityLabel(int severity) {
  if (severity >= 7) return 'Critical';
  if (severity >= 4) return 'Moderate';
  return 'Minor';
}

class IssueDetailScreen extends StatefulWidget {
  final ReportModel report;

  const IssueDetailScreen({super.key, required this.report});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  late ReportStatus _currentStatus;
  bool _volunteering = false;
  bool _markingFixed = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.report.status;
  }

  bool get _isFixed => _currentStatus == ReportStatus.fixed;
  bool get _alreadyAssigned => _currentStatus == ReportStatus.inProgress;
  bool get _volunteerLocked =>
      widget.report.severity >= _kVolunteerLockSeverity;

  Future<void> _confirmVolunteer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm volunteering',
          style: TextStyle(
            color: _kTextPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Volunteer to fix "${widget.report.category}"?',
          style: const TextStyle(
            color: _kTextSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _kTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Volunteer',
              style: TextStyle(
                color: _kOlive,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _volunteer();
  }

  Future<void> _volunteer() async {
    setState(() => _volunteering = true);
    try {
      await DatabaseService.instance.updateReportStatus(
        widget.report.id!,
        ReportStatus.inProgress,
      );
      if (!mounted) return;
      setState(() {
        _currentStatus = ReportStatus.inProgress;
        _volunteering = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text("You've volunteered. The community thanks you."),
          backgroundColor: _kSurfaceHigh,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _volunteering = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update: $e')),
      );
    }
  }

  Future<void> _confirmMarkFixed() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurfaceHigh,
        surfaceTintColor: Colors.transparent,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Mark as fixed?',
          style: TextStyle(
            color: _kTextPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Confirm that this issue has been resolved.',
          style: TextStyle(
            color: _kTextSecondary,
            fontSize: 13.5,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: _kTextSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Mark Fixed',
              style: TextStyle(
                color: _kOrange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _markFixed();
  }

  Future<void> _markFixed() async {
    setState(() => _markingFixed = true);
    try {
      final ok = await DatabaseService.instance
          .updateReportStatus(widget.report.id!, ReportStatus.fixed);
      if (!ok) throw Exception('Update did not match any document.');
      if (!mounted) return;
      setState(() {
        _currentStatus = ReportStatus.fixed;
        _markingFixed = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Marked as fixed. Thank you.'),
          backgroundColor: _kSurfaceHigh,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _markingFixed = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.report;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: const Text(
          'Issue Detail',
          style: TextStyle(
            color: _kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ImagePanel(report: r),
              const SizedBox(height: 16),
              _ClassificationCard(report: r),
              const SizedBox(height: 16),
              _LocationCard(report: r),
              const SizedBox(height: 16),
              _StatusCard(status: _currentStatus),
              const SizedBox(height: 24),
              if (_volunteerLocked) ...[
                const _OfficialMaintenanceBanner(),
                const SizedBox(height: 16),
              ],
              _PrimaryActionButton(
                label: _alreadyAssigned
                    ? 'Already Assigned'
                    : 'Check Volunteer Availability',
                icon: Icons.handshake_outlined,
                color: _kOliveMuted,
                busy: _volunteering,
                onTap: (_volunteerLocked || _alreadyAssigned || _isFixed)
                    ? null
                    : _confirmVolunteer,
              ),
              const SizedBox(height: 12),
              _PrimaryActionButton(
                label: _isFixed ? 'Already Fixed' : 'Mark as Fixed',
                icon: Icons.check_circle_outline_rounded,
                color: _kOrange,
                busy: _markingFixed,
                onTap: _isFixed ? null : _confirmMarkFixed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Image panel ──────────────────────────────────────────────────────────────

class _ImagePanel extends StatelessWidget {
  final ReportModel report;
  const _ImagePanel({required this.report});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        report.imageBase64 != null && report.imageBase64!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: hasImage
          ? Image.memory(
              base64Decode(report.imageBase64!),
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
            )
          : Container(
              height: 240,
              color: _kSurfaceHigh,
              child: const Center(
                child: Icon(
                  Icons.image_outlined,
                  color: _kTextTertiary,
                  size: 40,
                ),
              ),
            ),
    );
  }
}

// ─── Classification card ──────────────────────────────────────────────────────

class _ClassificationCard extends StatelessWidget {
  final ReportModel report;
  const _ClassificationCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(report.severity);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'AI CLASSIFICATION',
                style: TextStyle(
                  color: _kTextTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.4,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_severityLabel(report.severity)} · ${report.severity}/10',
                      style: TextStyle(
                        color: color,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            report.category,
            style: const TextStyle(
              color: _kTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text(
                'SEVERITY',
                style: TextStyle(
                  color: _kTextTertiary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${report.severity} / 10',
                style: TextStyle(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            report.description,
            style: const TextStyle(
              color: _kTextSecondary,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Location card (white map + street name) ─────────────────────────────────

class _LocationCard extends StatelessWidget {
  final ReportModel report;
  const _LocationCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final point = LatLng(report.latitude, report.longitude);
    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: SizedBox(
              height: 160,
              width: double.infinity,
              child: AbsorbPointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: point,
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: _kLightTileUrl,
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: point,
                          width: 28,
                          height: 28,
                          child: _LocationPin(
                            color: _severityColor(report.severity),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STREET NAME',
                  style: TextStyle(
                    color: _kTextTertiary,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.place_rounded,
                      color: _kOrange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.address,
                        style: const TextStyle(
                          color: _kTextPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.gps_fixed_rounded,
                      color: _kOlive,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(
                          color: _kTextSecondary,
                          fontSize: 12.5,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationPin extends StatelessWidget {
  final Color color;
  const _LocationPin({required this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.45),
              blurRadius: 10,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status card ──────────────────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final ReportStatus status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ReportStatus.fixed:
        color = _kMinor;
        break;
      case ReportStatus.inProgress:
        color = _kOrange;
        break;
      case ReportStatus.pending:
        color = _kOlive;
        break;
    }
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          const Text(
            'Status',
            style: TextStyle(
              color: _kTextSecondary,
              fontSize: 13.5,
            ),
          ),
          const Spacer(),
          Text(
            status.label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Official maintenance banner (severity guard) ─────────────────────────────

class _OfficialMaintenanceBanner extends StatelessWidget {
  const _OfficialMaintenanceBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kOrange.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOrange.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: _kOrange, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: const TextSpan(
                style: TextStyle(
                  color: _kTextPrimary,
                  fontSize: 12.5,
                  height: 1.4,
                ),
                children: [
                  TextSpan(
                    text: 'Official Maintenance Only: ',
                    style: TextStyle(
                      color: _kOrange,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                  TextSpan(
                    text:
                        'High-severity tasks are restricted to RAK municipal teams.',
                    style: TextStyle(color: _kTextSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Primary action button ────────────────────────────────────────────────────

class _PrimaryActionButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.busy,
    required this.onTap,
  });

  @override
  State<_PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<_PrimaryActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null || widget.busy;
    final bg = disabled
        ? _kSurfaceHigh
        : widget.color;
    final fg = disabled ? _kTextTertiary : const Color(0xFF0B0F1E);

    return AnimatedScale(
      scale: _pressed && !disabled ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: disabled ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: disabled
                ? Border.all(color: _kDivider, width: 1)
                : null,
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.busy) ...[
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: fg,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                ] else ...[
                  Icon(widget.icon, color: fg, size: 18),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    color: fg,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Generic card primitive ───────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kDivider, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}
