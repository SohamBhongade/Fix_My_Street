import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/severity_indicator.dart';

class IssueDetailScreen extends StatefulWidget {
  final ReportModel report;

  const IssueDetailScreen({super.key, required this.report});

  @override
  State<IssueDetailScreen> createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  bool _volunteering = false;
  late ReportStatus _currentStatus;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.report.status;
  }

  bool get _alreadyAssigned => _currentStatus == ReportStatus.inProgress;

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

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final severityColor = SeverityIndicator.colorFor(r.severity);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'ISSUE DETAIL',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            letterSpacing: 2.5,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0A0A1F), Color(0xFF050510)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image
                GlassCard(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: r.imageBase64 != null && r.imageBase64!.isNotEmpty
                        ? Image.memory(
                            base64Decode(r.imageBase64!),
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            height: 220,
                            color: const Color(0xFF14262C),
                            child: const Center(
                              child: Icon(
                                Icons.image_not_supported_rounded,
                                color: Colors.white38,
                                size: 48,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                // Classification card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14060A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: const Color(0xFFFF5252), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ISSUE CLASSIFICATION',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 11,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        r.category,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${r.severity}/10 severity',
                        style: TextStyle(
                          color: severityColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          shadows: [
                            Shadow(
                              color: severityColor.withValues(alpha: 0.5),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        r.description,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 13,
                          height: 1.45,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Location card
                GlassCard(
                  borderColor: const Color(0x66B388FF),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _LocationRow(
                        icon: Icons.gps_fixed_rounded,
                        label: 'GPS COORDINATES',
                        value:
                            '${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}',
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Container(
                          height: 1,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      _LocationRow(
                        icon: Icons.place_rounded,
                        label: 'STREET NAME',
                        value: r.address,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Status chip
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _currentStatus == ReportStatus.fixed
                            ? const Color(0xFF00E676)
                            : _currentStatus == ReportStatus.inProgress
                                ? const Color(0xFFFF9100)
                                : const Color(0xFFFF5252),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'STATUS: ${_currentStatus.label.toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                // Volunteer button
                AnimatedOpacity(
                  opacity: (_alreadyAssigned || _volunteering) ? 0.5 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: GestureDetector(
                    onTap:
                        (_alreadyAssigned || _volunteering) ? null : _volunteer,
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _alreadyAssigned
                            ? const Color(0xFF2A3A40)
                            : const Color(0xFF00E5FF),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: _alreadyAssigned
                            ? []
                            : const [
                                BoxShadow(
                                  color: Color(0x6600E5FF),
                                  blurRadius: 22,
                                ),
                              ],
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
                                ? Colors.white54
                                : Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
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

class _LocationRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _LocationRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFB388FF), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
