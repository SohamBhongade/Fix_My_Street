import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/app_user.dart';
import '../models/report_model.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

// ─── Local navy-green / olive / orange palette ──────────────────────────────
const Color _kBg = Color(0xFF06091A);
const Color _kSurface = Color(0xFF0E1426);
const Color _kSurfaceHigh = Color(0xFF161E33);
// Deep olive green — primary accent.
const Color _kOlive = Color(0xFFA8B870);
// Desaturated, muted olive — used for solid button backgrounds.
const Color _kOliveMuted = Color(0xFF7E8854);
const Color _kOrange = Color(0xFFFF9100);
// Amber tone for the "Pending Verification" state.
const Color _kAmber = Color(0xFFFFC857);
const Color _kTextPrimary = Color(0xFFEBEEF5);
const Color _kTextSecondary = Color(0xFF9AA5B8);
const Color _kTextTertiary = Color(0xFF606878);
const Color _kDivider = Color(0x1AFFFFFF);

const Color _kCritical = Color(0xFFE57373);
const Color _kModerate = _kOrange;
const Color _kMinor = Color(0xFF66BB6A);

const String _kLightTileUrl =
    'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

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
  // The screen owns a mutable copy of the report so the action panel
  // transitions through open → in_progress → pending_verification →
  // resolved without bouncing back to the previous screen.
  late ReportModel _report;

  bool _volunteering = false;
  bool _submittingProof = false;
  bool _verifying = false;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  AppUser? get _user => AuthService.instance.currentUser;
  bool get _isAdmin => _user?.isCityAdmin ?? false;
  bool get _isAssignedVolunteer =>
      _user != null &&
      _report.assignedVolunteerId != null &&
      _report.assignedVolunteerId == _user!.username;

  /// Rule A: admins cannot volunteer when severity > 3.
  bool get _adminSeverityLocked =>
      _isAdmin && _report.severity > kAdminVolunteerSeverityCap;

  // ─── Actions ──────────────────────────────────────────────────────────

  Future<void> _confirmVolunteer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Volunteer for this task?',
        body: 'You will be assigned as the volunteer for '
            '"${_report.category}". You\'ll need to submit a proof-of-work '
            'image once the work is done.',
        confirmLabel: 'Yes, Volunteer',
        confirmColor: _kOlive,
      ),
    );
    if (confirmed != true || !mounted) return;
    await _volunteer();
  }

  Future<void> _volunteer() async {
    final user = _user;
    if (user == null) return;

    setState(() => _volunteering = true);
    try {
      final updated = await DatabaseService.instance.volunteerForReport(
        id: _report.id!,
        user: user,
      );
      if (!mounted) return;
      setState(() {
        _report = updated;
        _volunteering = false;
      });
      _snack("You've volunteered. The community thanks you.");
    } on VerificationRuleException catch (e) {
      if (!mounted) return;
      setState(() => _volunteering = false);
      _snack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _volunteering = false);
      _snack('Failed to update: $e', isError: true);
    }
  }

  /// Rule B (first half): the assigned volunteer picks an image and the
  /// task is flipped to pending_verification.
  ///
  /// We always offer gallery + camera in a small bottom sheet so the user
  /// doesn't have to dig through OS permissions; image_picker handles
  /// either source. The picked image is base64-encoded and stored as a
  /// `data:` URL so the rest of the app can render it via Image.memory
  /// without needing an external blob host.
  Future<void> _submitCompletionProof() async {
    if (_submittingProof) return;
    final source = await _chooseImageSource();
    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final XFile? picked;
    try {
      picked = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 82,
      );
    } catch (e) {
      _snack('Could not access image: $e', isError: true);
      return;
    }
    if (picked == null || !mounted) return;

    setState(() => _submittingProof = true);
    try {
      final bytes = await File(picked.path).readAsBytes();
      final b64 = base64Encode(bytes);
      // Inline data URL so consumers can drop it straight into Image.memory
      // after stripping the mime prefix — see _ProofOfWorkSection below.
      final dataUrl = 'data:image/jpeg;base64,$b64';

      final user = _user;
      if (user == null) throw const VerificationRuleException('Not signed in.');

      final updated = await DatabaseService.instance.submitProofOfWork(
        id: _report.id!,
        submittingUser: user,
        proofImageUrl: dataUrl,
      );
      if (!mounted) return;
      setState(() {
        _report = updated;
        _submittingProof = false;
      });
      _snack('Proof submitted. Awaiting admin approval.');
    } on VerificationRuleException catch (e) {
      if (!mounted) return;
      setState(() => _submittingProof = false);
      _snack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submittingProof = false);
      _snack('Could not submit proof: $e', isError: true);
    }
  }

  Future<ImageSource?> _chooseImageSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _kSurfaceHigh,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(
                  'Submit proof of work',
                  style: TextStyle(
                    color: _kTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              _SheetOption(
                icon: Icons.photo_camera_outlined,
                label: 'Take a photo',
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              _SheetOption(
                icon: Icons.photo_library_outlined,
                label: 'Choose from gallery',
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  /// Rule B (second half): admin verifies the uploaded proof and resolves
  /// the ticket. Server-side guard in [DatabaseService.adminVerifyAndResolve]
  /// re-checks the role + proof URL — we re-check here too so the UI
  /// reflects bad state immediately without a server round-trip.
  Future<void> _verifyAndResolve() async {
    final user = _user;
    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ConfirmDialog(
        title: 'Verify & resolve issue?',
        body: 'You\'re confirming the volunteer\'s proof-of-work is valid '
            'and this issue is fully resolved.',
        confirmLabel: 'Verify & Resolve',
        confirmColor: _kMinor,
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _verifying = true);
    try {
      final updated = await DatabaseService.instance.adminVerifyAndResolve(
        id: _report.id!,
        admin: user,
      );
      // Edge case: an admin who somehow had been the assigned volunteer
      // (Rule A would have blocked the self-assign on high severity, but
      // it's still legal on severity ≤ 3) earned the +250 reward — pull
      // the fresh value so their chip updates without an app restart.
      // Awarding happens inside adminVerifyAndResolve.
      final assignee = updated.assignedVolunteerId;
      if (assignee != null && assignee == user.username) {
        final fresh = await DatabaseService.instance
            .fetchOrSeedUserExp(user.username, user.currentExp);
        // Optimistic floor: if the DB re-read happened to return a stale
        // value, prefer the locally-computed total so the user never sees
        // their balance appear to drop after a successful resolution.
        final optimistic = user.currentExp + 250;
        AuthService.instance.updateCurrentExp(
          fresh > optimistic ? fresh : optimistic,
        );
      }
      if (!mounted) return;
      setState(() {
        _report = updated;
        _verifying = false;
      });
      _snack('Issue resolved. Great work team.');
    } on VerificationRuleException catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _snack(e.message, isError: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _verifying = false);
      _snack('Could not resolve: $e', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _kCritical.withValues(alpha: 0.95) : _kSurfaceHigh,
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = _report;

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
              _StatusCard(status: r.status),
              const SizedBox(height: 24),
              ..._buildActionPanel(),
            ],
          ),
        ),
      ),
    );
  }

  // Action panel content varies by (role × status). Returned as a list of
  // widgets so the build method stays readable.
  List<Widget> _buildActionPanel() {
    final r = _report;

    // Resolved — terminal state, no further actions for anyone.
    if (r.status == ReportStatus.resolved) {
      return const [
        _TerminalBanner(
          icon: Icons.verified_rounded,
          color: _kMinor,
          headline: 'Issue Resolved',
          body: 'This task has been verified and closed by an admin.',
        ),
      ];
    }

    // Admin viewing a pending_verification task: proof-of-work review.
    if (_isAdmin && r.status == ReportStatus.pendingVerification) {
      return [
        _ProofOfWorkSection(proofUrl: r.proofOfWorkImageUrl),
        const SizedBox(height: 12),
        _PrimaryActionButton(
          label: 'Verify & Resolve Issue',
          icon: Icons.task_alt_rounded,
          color: _kMinor,
          busy: _verifying,
          onTap: _verifying ? null : _verifyAndResolve,
        ),
      ];
    }

    // Non-admin (or admin who isn't the verifier) staring at a
    // pending_verification task — show a status badge, no action.
    if (r.status == ReportStatus.pendingVerification) {
      return [
        _PendingApprovalBadge(),
      ];
    }

    // Assigned volunteer on an in_progress task — submit completion proof.
    if (r.status == ReportStatus.inProgress && _isAssignedVolunteer) {
      return [
        _AssignedNotice(volunteer: r.assignedVolunteerId),
        const SizedBox(height: 12),
        _PrimaryActionButton(
          label: 'Submit Completion Proof',
          icon: Icons.upload_file_outlined,
          color: _kOrange,
          busy: _submittingProof,
          onTap: _submittingProof ? null : _submitCompletionProof,
        ),
      ];
    }

    // Open / in_progress (viewed by someone other than the volunteer):
    // volunteer button, gated by Rule A for admins on high severity.
    return _buildVolunteerCta();
  }

  List<Widget> _buildVolunteerCta() {
    final r = _report;
    final alreadyAssigned = r.status == ReportStatus.inProgress;

    if (_adminSeverityLocked) {
      return const [
        _HighPriorityReservedBanner(),
      ];
    }

    return [
      if (alreadyAssigned)
        _AssignedNotice(volunteer: r.assignedVolunteerId)
      else
        const SizedBox.shrink(),
      if (alreadyAssigned) const SizedBox(height: 12),
      _PrimaryActionButton(
        label: alreadyAssigned
            ? 'Already Assigned'
            : 'Volunteer for this Task',
        icon: Icons.handshake_outlined,
        color: _kOliveMuted,
        busy: _volunteering,
        onTap: alreadyAssigned ? null : _confirmVolunteer,
      ),
    ];
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

// ─── Location card ────────────────────────────────────────────────────────────

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
      case ReportStatus.resolved:
        color = _kMinor;
        break;
      case ReportStatus.pendingVerification:
        color = _kAmber;
        break;
      case ReportStatus.inProgress:
        color = _kOrange;
        break;
      case ReportStatus.open:
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

// ─── High-priority reserved banner (Rule A — admin lock) ──────────────────────

class _HighPriorityReservedBanner extends StatelessWidget {
  const _HighPriorityReservedBanner();

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
        children: const [
          Icon(Icons.shield_outlined, color: _kOrange, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'High-priority task reserved for public works.',
              style: TextStyle(
                color: _kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Assigned notice ──────────────────────────────────────────────────────────

class _AssignedNotice extends StatelessWidget {
  final String? volunteer;
  const _AssignedNotice({required this.volunteer});

  @override
  Widget build(BuildContext context) {
    final who = (volunteer == null || volunteer!.isEmpty)
        ? 'a volunteer'
        : volunteer!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kOliveMuted.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kOliveMuted.withValues(alpha: 0.5), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.person_pin_circle_outlined,
              color: _kOlive, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Assigned to $who.',
              style: const TextStyle(
                color: _kTextPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Pending Admin Approval badge ─────────────────────────────────────────────

class _PendingApprovalBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kAmber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kAmber.withValues(alpha: 0.55), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.hourglass_top_rounded, color: _kAmber, size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pending Admin Approval',
              style: TextStyle(
                color: _kAmber,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Terminal banner (used for the resolved state) ────────────────────────────

class _TerminalBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String headline;
  final String body;

  const _TerminalBanner({
    required this.icon,
    required this.color,
    required this.headline,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  headline,
                  style: TextStyle(
                    color: color,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: const TextStyle(
                    color: _kTextSecondary,
                    fontSize: 12.5,
                    height: 1.4,
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

// ─── Proof-of-work section (admin view of pending_verification) ───────────────

class _ProofOfWorkSection extends StatelessWidget {
  final String? proofUrl;
  const _ProofOfWorkSection({required this.proofUrl});

  /// Strip the `data:image/jpeg;base64,` prefix (or any data URL prefix)
  /// before handing the payload to base64Decode. Returns null when the
  /// payload doesn't decode cleanly — the caller renders a placeholder
  /// instead of crashing the screen.
  static Uint8List? _decode(String? url) {
    if (url == null || url.isEmpty) return null;
    var payload = url;
    final comma = url.indexOf(',');
    if (url.startsWith('data:') && comma > 0) {
      payload = url.substring(comma + 1);
    }
    try {
      return base64Decode(payload);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = _decode(proofUrl);

    return _Card(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.fact_check_outlined, color: _kAmber, size: 18),
                SizedBox(width: 8),
                Text(
                  'VOLUNTEER PROOF OF WORK',
                  style: TextStyle(
                    color: _kAmber,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.4,
                  ),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(bottom: Radius.circular(16)),
            child: bytes != null
                ? Image.memory(
                    bytes,
                    width: double.infinity,
                    height: 240,
                    fit: BoxFit.cover,
                  )
                : Container(
                    height: 200,
                    color: _kSurfaceHigh,
                    width: double.infinity,
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.broken_image_outlined,
                              color: _kTextTertiary, size: 32),
                          SizedBox(height: 8),
                          Text(
                            'Proof image unavailable',
                            style: TextStyle(
                              color: _kTextSecondary,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Confirm dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final Color confirmColor;

  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.confirmColor,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: _kSurfaceHigh,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        title,
        style: const TextStyle(
          color: _kTextPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      content: Text(
        body,
        style: const TextStyle(
          color: _kTextSecondary,
          fontSize: 13.5,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(
            'Cancel',
            style: TextStyle(
              color: _kTextSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: TextStyle(
              color: confirmColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom-sheet option row ──────────────────────────────────────────────────

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _kOlive, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: const TextStyle(
                color: _kTextPrimary,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
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
    final bg = disabled ? _kSurfaceHigh : widget.color;
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
            border: disabled ? Border.all(color: _kDivider, width: 1) : null,
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
