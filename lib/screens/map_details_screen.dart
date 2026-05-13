import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';
import '../widgets/severity_indicator.dart';

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
  bool get _requiresProfessional => widget.report.severity >= 4;

  Future<void> _volunteer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F26),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Confirm Volunteering',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to volunteer to fix "${widget.report.category}"?',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Yes, Volunteer',
              style: TextStyle(
                color: Color(0xFF00E5FF),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

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
          content: Text("You've volunteered! The community thanks you."),
          backgroundColor: Color(0xFF00E5FF),
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

  Widget _buildProfessionalWarning() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEF4444), width: 1.5),
      ),
      child: const Row(
        children: [
          Icon(Icons.shield_outlined, color: Color(0xFFEF4444), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Professional Repair Required: This issue is too severe for public volunteers. Local authorities have been notified.',
              style: TextStyle(
                color: Color(0xFFB91C1C),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVolunteerButton() {
    return SizedBox(
      height: 48,
      child: GestureDetector(
        onTap: (_alreadyAssigned || _volunteering) ? null : _volunteer,
        child: AnimatedOpacity(
          opacity: (_alreadyAssigned || _volunteering) ? 0.5 : 1,
          duration: const Duration(milliseconds: 150),
          child: Container(
            decoration: BoxDecoration(
              color: _alreadyAssigned
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF0A1628),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                _volunteering
                    ? 'UPDATING…'
                    : _alreadyAssigned
                        ? 'ALREADY ASSIGNED'
                        : 'VOLUNTEER TO FIX',
                style: TextStyle(
                  color: _alreadyAssigned
                      ? const Color(0xFF6B7280)
                      : Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
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
    final color = SeverityIndicator.colorFor(r.severity);
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(
        children: [
          // ── Top 3/4: Light map ──────────────────────────────────────────
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
                      urlTemplate:
                          'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                    ),
                    MarkerLayer(markers: [_buildMarker()]),
                  ],
                ),
                // Floating back button
                Positioned(
                  top: topPadding + 8,
                  left: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.white.withValues(alpha: 0.92),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.black87,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // ── Bottom 1/4: Detail panel ────────────────────────────────────
          Expanded(
            flex: 1,
            child: Container(
              color: const Color(0xFFF5F7FA),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r.category,
                              style: const TextStyle(
                                color: Color(0xFF0A1628),
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              r.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Severity badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color: color.withValues(alpha: 0.6), width: 1.5),
                        ),
                        child: Text(
                          '${r.severity}/10',
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Action area: safety gate or volunteer button
                  _requiresProfessional
                      ? _buildProfessionalWarning()
                      : _buildVolunteerButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
