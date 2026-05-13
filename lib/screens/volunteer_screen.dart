import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/severity_indicator.dart';

class VolunteerScreen extends StatefulWidget {
  const VolunteerScreen({super.key});

  @override
  State<VolunteerScreen> createState() => _VolunteerScreenState();
}

class _VolunteerScreenState extends State<VolunteerScreen> {
  List<ReportModel> _reports = [];
  bool _loading = true;
  String? _error;
  final Set<String> _updating = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final reports = await DatabaseService.instance.fetchReports();
      reports.sort((a, b) {
        // Open reports first, then by severity desc, then newest first.
        final aOpen = a.status != ReportStatus.fixed ? 0 : 1;
        final bOpen = b.status != ReportStatus.fixed ? 0 : 1;
        if (aOpen != bOpen) return aOpen.compareTo(bOpen);
        if (a.severity != b.severity) return b.severity.compareTo(a.severity);
        return b.createdAt.compareTo(a.createdAt);
      });
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _markFixed(ReportModel report) async {
    final id = report.id;
    if (id == null) return;
    final key = id.oid;

    setState(() => _updating.add(key));
    try {
      final ok = await DatabaseService.instance
          .updateReportStatus(id, ReportStatus.fixed);
      if (!ok) throw Exception('Update did not match any document.');
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked as fixed. Thanks for helping!')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _updating.remove(key));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Volunteer Console'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
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
          child: RefreshIndicator(
            color: const Color(0xFF00E5FF),
            backgroundColor: const Color(0xFF1A1B3A),
            onRefresh: _load,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
      );
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            borderColor: const Color(0x66FF5252),
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not load reports',
                  style: TextStyle(
                    color: Color(0xFFFF5252),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (_reports.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Icon(
                  Icons.task_alt_rounded,
                  size: 56,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                const Text(
                  'No reports yet',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'When citizens submit reports, they will appear here sorted by severity.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        final key = report.id?.oid ?? '';
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _ReportCard(
            report: report,
            updating: _updating.contains(key),
            onMarkFixed: () => _markFixed(report),
          ),
        );
      },
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final bool updating;
  final VoidCallback onMarkFixed;

  const _ReportCard({
    required this.report,
    required this.updating,
    required this.onMarkFixed,
  });

  @override
  Widget build(BuildContext context) {
    final isFixed = report.status == ReportStatus.fixed;
    final accent = isFixed
        ? const Color(0xFF66BB6A)
        : SeverityIndicator.colorFor(report.severity);

    Uint8List? bytes;
    if (report.imageBase64 != null && report.imageBase64!.isNotEmpty) {
      try {
        bytes = base64Decode(report.imageBase64!);
      } catch (_) {
        bytes = null;
      }
    }

    return GlassCard(
      borderColor: accent.withValues(alpha: 0.9),
      padding: EdgeInsets.zero,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (bytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          bytes,
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                        ),
                      )
                    else
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Right padding reserves space for the corner StatusTag.
                          Padding(
                            padding: const EdgeInsets.only(right: 76),
                            child: Text(
                              report.category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(
                                Icons.place_outlined,
                                color: Colors.white.withValues(alpha: 0.6),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  report.address,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('d MMM yyyy · HH:mm')
                                .format(report.createdAt),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  report.description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _StatusPill(status: report.status),
                    const Spacer(),
                    if (!isFixed)
                      _FixButton(
                        updating: updating,
                        onTap: updating ? null : onMarkFixed,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Corner severity tag — overlaid at top-right of the card.
          Positioned(
            top: 0,
            right: 0,
            child: isFixed
                ? Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: const BoxDecoration(
                      color: Color(0x2266BB6A),
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(18),
                        bottomLeft: Radius.circular(12),
                      ),
                      border: Border(
                        left: BorderSide(color: Color(0x9966BB6A)),
                        bottom: BorderSide(color: Color(0x9966BB6A)),
                      ),
                    ),
                    child: const Text(
                      'FIXED',
                      style: TextStyle(
                        color: Color(0xFF66BB6A),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.8,
                      ),
                    ),
                  )
                : StatusTag(severity: report.severity),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final ReportStatus status;
  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case ReportStatus.fixed:
        color = const Color(0xFF66BB6A);
        break;
      case ReportStatus.inProgress:
        color = const Color(0xFFFFAB00);
        break;
      case ReportStatus.pending:
        color = const Color(0xFF00E5FF);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Text(
        status.label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _FixButton extends StatelessWidget {
  final bool updating;
  final VoidCallback? onTap;

  const _FixButton({required this.updating, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [Color(0xFF00E676), Color(0xFF00B0FF)],
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x6600E676), blurRadius: 18),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (updating)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  color: Colors.black,
                  strokeWidth: 2,
                ),
              )
            else
              const Icon(Icons.check_rounded, color: Colors.black, size: 16),
            const SizedBox(width: 6),
            Text(
              updating ? 'Updating…' : 'Mark as Fixed',
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
