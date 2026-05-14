import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';
import 'issue_detail_screen.dart';

// ─── Local navy-green / olive palette ───────────────────────────────────────
const Color _kBg = Color(0xFF06091A);
const Color _kSurface = Color(0xFF0E1426);
const Color _kSurfaceHigh = Color(0xFF161E33);
// Deep forest olive — solid button background.
const Color _kOliveDeep = Color(0xFF2E3D2F);
// Primary olive accent — icons, values, glow border.
const Color _kOlive = Color(0xFFA8B870);
// Sage / desaturated olive — secondary muted tint.
const Color _kOliveSoft = Color(0xFF8E9474);
const Color _kOrange = Color(0xFFFF9100);
const Color _kTextPrimary = Color(0xFFEBEEF5);
const Color _kTextSecondary = Color(0xFF9AA5B8);
const Color _kTextTertiary = Color(0xFF606878);
const Color _kDivider = Color(0x1AFFFFFF);

// Muted, navy-friendly severity palette.
const Color _kCritical = Color(0xFFE57373);
const Color _kModerate = _kOrange;
const Color _kMinor = Color(0xFF66BB6A);

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

class IssueConsoleScreen extends StatefulWidget {
  const IssueConsoleScreen({super.key});

  @override
  State<IssueConsoleScreen> createState() => _IssueConsoleScreenState();
}

class _IssueConsoleScreenState extends State<IssueConsoleScreen> {
  List<ReportModel> _reports = [];
  bool _loading = true;
  String? _error;

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

  Future<void> _openDetails(ReportModel report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => IssueDetailScreen(report: report)),
    );
    // Refresh on return so any status change made on the detail screen
    // (volunteer / mark fixed) is reflected here.
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final openCount =
        _reports.where((r) => r.status != ReportStatus.fixed).length;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Back arrow tinted sage olive to match the new identity.
        iconTheme: const IconThemeData(color: _kOliveSoft),
        title: const Text(
          'Issue Console',
          style: TextStyle(
            color: _kTextPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            color: _kOliveSoft,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: _kOlive,
          backgroundColor: _kSurfaceHigh,
          onRefresh: _load,
          child: _buildBody(openCount),
        ),
      ),
    );
  }

  Widget _buildBody(int openCount) {
    if (_loading) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(color: _kOlive, strokeWidth: 2),
        ),
      );
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Could not load reports',
                  style: TextStyle(
                    color: _kCritical,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 13.5,
                    height: 1.5,
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
        padding: const EdgeInsets.all(24),
        children: [
          _Card(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
            child: Column(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _kSurfaceHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    size: 26,
                    color: _kOlive,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'No reports yet',
                  style: TextStyle(
                    color: _kTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'When citizens submit reports they will appear here, sorted by severity.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _kTextSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      itemCount: _reports.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _SummaryStrip(
              total: _reports.length,
              open: openCount,
            ),
          );
        }
        final report = _reports[index - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ReportCard(
            report: report,
            onViewDetails: () => _openDetails(report),
          ),
        );
      },
    );
  }
}

// ─── Summary strip ────────────────────────────────────────────────────────────

class _SummaryStrip extends StatelessWidget {
  final int total;
  final int open;
  const _SummaryStrip({required this.total, required this.open});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SummaryTile(label: 'TOTAL', value: '$total', accent: _kOlive),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryTile(label: 'OPEN', value: '$open', accent: _kOlive),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _SummaryTile(
            label: 'FIXED',
            value: '${total - open}',
            accent: _kOliveSoft,
          ),
        ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? accent;

  const _SummaryTile({required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      // Thin olive border on every stat tile.
      borderColor: _kOlive.withValues(alpha: 0.35),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            // Olive-tinted label so the box reads as part of the olive family.
            style: const TextStyle(
              color: _kOliveSoft,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent ?? _kOlive,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Report card ──────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final ReportModel report;
  final VoidCallback onViewDetails;

  const _ReportCard({required this.report, required this.onViewDetails});

  @override
  Widget build(BuildContext context) {
    Uint8List? bytes;
    if (report.imageBase64 != null && report.imageBase64!.isNotEmpty) {
      try {
        bytes = base64Decode(report.imageBase64!);
      } catch (_) {
        bytes = null;
      }
    }

    return _Card(
      // Subtle olive-green gradient ring around each report card.
      gradientBorder: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(bytes: bytes),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.category,
                      style: const TextStyle(
                        color: _kTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: _kTextTertiary,
                          size: 13,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            report.address,
                            style: const TextStyle(
                              color: _kTextSecondary,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('d MMM · HH:mm').format(report.createdAt),
                      style: const TextStyle(
                        color: _kTextTertiary,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _SeverityChip(severity: report.severity),
              const SizedBox(width: 8),
              _StatusPill(status: report.status),
            ],
          ),
          const SizedBox(height: 16),
          _ViewDetailsButton(onTap: onViewDetails),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  final Uint8List? bytes;
  const _Thumbnail({this.bytes});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: bytes != null
          ? Image.memory(bytes!, width: 64, height: 64, fit: BoxFit.cover)
          : Container(
              width: 64,
              height: 64,
              color: _kSurfaceHigh,
              child: const Icon(
                Icons.image_outlined,
                color: _kTextTertiary,
                size: 22,
              ),
            ),
    );
  }
}

class _SeverityChip extends StatelessWidget {
  final int severity;
  const _SeverityChip({required this.severity});

  @override
  Widget build(BuildContext context) {
    final s = severity.clamp(1, 10);
    final color = _severityColor(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '${_severityLabel(s)} · $s/10',
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
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
        color = _kMinor;
        break;
      case ReportStatus.inProgress:
        color = _kOrange;
        break;
      case ReportStatus.pending:
        color = _kOlive;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: color,
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _ViewDetailsButton extends StatefulWidget {
  final VoidCallback onTap;
  const _ViewDetailsButton({required this.onTap});

  @override
  State<_ViewDetailsButton> createState() => _ViewDetailsButtonState();
}

class _ViewDetailsButtonState extends State<_ViewDetailsButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1.0,
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            // Solid deep forest olive bg replaces the old cyan ghost button.
            color: _kOliveDeep,
            borderRadius: BorderRadius.circular(12),
            // Olive glow border instead of the blue one.
            border: Border.all(
              color: _kOlive.withValues(alpha: 0.55),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: _kOlive.withValues(alpha: 0.18),
                blurRadius: 12,
                spreadRadius: 0,
              ),
            ],
          ),
          child: const Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'View Details',
                  style: TextStyle(
                    color: _kOlive,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward_rounded, color: _kOlive, size: 16),
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
  // Optional solid border color override (e.g. olive for stat tiles).
  final Color? borderColor;
  // When true, paints a subtle olive gradient as the card's outer border via
  // a wrapper container — used by report cards.
  final bool gradientBorder;

  const _Card({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.gradientBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    if (gradientBorder) {
      // 1px olive gradient ring around a surface-filled inner container.
      return Container(
        padding: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _kOlive,
              _kOliveSoft,
              _kOliveDeep,
            ],
            stops: [0.0, 0.55, 1.0],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Container(
            color: _kSurface,
            padding: padding,
            child: child,
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: borderColor ?? _kDivider,
          width: 1,
        ),
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
