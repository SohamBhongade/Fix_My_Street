import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/issue_categories.dart';
import '../models/ai_analysis_result.dart';
import '../models/report_model.dart';
import '../services/ai_service.dart' show AIService, GroqException;
import '../services/auth_service.dart';
import '../services/database_service.dart'
    show DatabaseService, kExpRewardReportSubmitted;
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_buttons.dart';
import '../widgets/severity_indicator.dart';
import '../widgets/surface_card.dart';

// Severity for the manual-classification dropdown comes from the canonical
// category → severity map in lib/core/issue_categories.dart. Keeping a
// single source of truth across the AI prompt, the manual dropdown, and
// the persistence layer is what guarantees Litter Accumulation /
// Overgrown Vegetation / Graffiti always land at 1 / 2 / 3.
const Map<String, int> _categorySeverity = kCanonicalCategorySeverity;

String _priorityLabelFor(int severity) {
  if (severity >= 8) return 'Critical';
  if (severity >= 4) return 'Moderate';
  return 'Minor';
}

class AIPreviewScreen extends StatefulWidget {
  final Uint8List imageBytes;
  final String imagePath;

  const AIPreviewScreen({
    super.key,
    required this.imageBytes,
    required this.imagePath,
  });

  @override
  State<AIPreviewScreen> createState() => _AIPreviewScreenState();
}

class _AIPreviewScreenState extends State<AIPreviewScreen> {
  AIAnalysisResult? _result;
  ResolvedLocation? _location;
  String? _error;
  bool _busy = true;
  bool _submitting = false;
  String? _manualCategoryOverride;

  int get _effectiveSeverity => _manualCategoryOverride != null
      ? (_categorySeverity[_manualCategoryOverride] ?? 0)
      : (_result?.severity ?? 0);

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        AIService.instance.analyzeImage(File(widget.imagePath)),
        LocationService.instance.getCurrentLocation(),
      ]);
      if (!mounted) return;
      setState(() {
        _result = results[0] as AIAnalysisResult;
        _location = results[1] as ResolvedLocation;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is GroqException ? e.userMessage : e.toString();
        _busy = false;
      });
    }
  }

  ReportModel _buildReport() {
    final result = _result!;
    final loc = _location!;
    final category = _manualCategoryOverride ?? result.category;
    final severity = _effectiveSeverity;
    return ReportModel(
      category: category,
      severity: severity,
      priority: ReportPriority.fromSeverity(severity),
      description: result.description,
      latitude: loc.latitude,
      longitude: loc.longitude,
      address: loc.address,
      imageBase64: base64Encode(widget.imageBytes),
      createdAt: DateTime.now(),
    );
  }

  Future<void> _submit({bool isRetry = false}) async {
    final result = _result;
    final loc = _location;
    if (result == null || loc == null) return;

    setState(() => _submitting = true);

    final ok = await DatabaseService.instance.saveReport(_buildReport());
    if (!mounted) return;

    if (ok) {
      // EXP reward: +50 to the user who just filed the report.
      //
      // We push the new balance into AuthService synchronously (before
      // popping) so the home screen's _BrandHeader picks it up on the
      // next rebuild — no app restart, no log-out / log-in cycle.
      //
      // awardExp returns the authoritative post-increment value when the
      // Mongo $inc + re-read both succeed. If the re-read fails (network
      // hiccup, but the $inc itself almost certainly applied), we fall
      // back to an OPTIMISTIC local increment so the chip still moves —
      // the next home-screen refresh will converge on the real value.
      final user = AuthService.instance.currentUser;
      if (user != null) {
        final newTotal = await DatabaseService.instance.awardExp(
          username: user.username,
          delta: kExpRewardReportSubmitted,
        );
        final resolved = newTotal ?? (user.currentExp + kExpRewardReportSubmitted);
        AuthService.instance.updateCurrentExp(resolved);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. +50 EXP awarded.')),
      );
      Navigator.of(context)..pop()..pop();
      return;
    }

    if (!isRetry) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection lost. Reconnecting and retrying.'),
        ),
      );
      try {
        await DatabaseService.instance.reopen();
      } catch (_) {}
      if (!mounted) return;
      await _submit(isRetry: true);
      return;
    }

    setState(() => _submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Submission failed. Please check your connection and try again.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(title: const Text('Report preview')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: AnimatedSwitcher(
            duration: AppMotion.base,
            switchInCurve: AppMotion.easeOut,
            child: _buildBody(),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Column(
      key: ValueKey('${_busy}_${_error != null}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Image.file(
              File(widget.imagePath),
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_busy) _buildLoading(),
        if (_error != null) _buildError(_error!),
        if (!_busy && _error == null && _result != null) ...[
          _buildClassificationCard(_result!),
          const SizedBox(height: AppSpacing.sm),
          _buildManualDropdown(_result!),
          const SizedBox(height: AppSpacing.sm),
          _buildStatGrid(),
          const SizedBox(height: AppSpacing.sm),
          if (_location != null) _buildLocationCard(_location!),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            label: _submitting ? 'Submitting' : 'Submit report',
            busy: _submitting,
            onTap: _submitting ? null : _submit,
          ),
        ],
      ],
    );
  }

  Widget _buildLoading() {
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                color: AppColors.olive,
                strokeWidth: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Analyzing image', style: AppText.heading),
            const SizedBox(height: 4),
            Text('Detecting category and severity', style: AppText.caption),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppColors.danger, size: 18),
              const SizedBox(width: 8),
              Text(
                'Something went wrong',
                style: AppText.heading.copyWith(color: AppColors.danger),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(message, style: AppText.bodySecondary),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: SecondaryButton(
              label: 'Retry',
              icon: Icons.refresh_rounded,
              expand: false,
              height: 40,
              onTap: _run,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassificationCard(AIAnalysisResult r) {
    final isOther = r.category == 'Other';
    final detectionLabel = isOther
        ? 'Analysis inconclusive'
        : r.category;
    final detectionDesc = isOther
        ? 'The photo is too unclear for precise detection. Please select the category manually below.'
        : r.description;

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('AI CLASSIFICATION', style: AppText.label),
              const Spacer(),
              if (!isOther)
                SeverityChip(severity: _effectiveSeverity, showScore: true),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(detectionLabel, style: AppText.title),
          const SizedBox(height: 8),
          Text(detectionDesc, style: AppText.bodySecondary),
          if (_manualCategoryOverride != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.oliveGhost,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(Icons.tune_rounded,
                      color: AppColors.olive, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Manual override · $_manualCategoryOverride · $_effectiveSeverity/10',
                      style: AppText.caption.copyWith(
                        color: AppColors.olive,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualDropdown(AIAnalysisResult r) {
    final isEnabled = r.category == 'Other';
    final categories = _categorySeverity.keys.toList();
    final initialValue = _manualCategoryOverride ??
        (categories.contains(r.category) ? r.category : categories.first);

    return AnimatedOpacity(
      duration: AppMotion.base,
      opacity: isEnabled ? 1.0 : 0.4,
      child: IgnorePointer(
        ignoring: !isEnabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MANUAL CLASSIFICATION', style: AppText.label),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: initialValue,
              dropdownColor: AppColors.surfaceHigh,
              iconEnabledColor: AppColors.olive,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              style: AppText.body,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide:
                      const BorderSide(color: AppColors.olive, width: 1.5),
                ),
                disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: const BorderSide(color: AppColors.hairline),
                ),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: isEnabled
                  ? (v) {
                      if (v == null) return;
                      setState(() => _manualCategoryOverride = v);
                    }
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatGrid() {
    final severity = _effectiveSeverity;
    final color = SeverityIndicator.colorFor(severity);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'PRIORITY',
            value: _priorityLabelFor(severity),
            color: color,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _StatTile(
            label: 'SEVERITY',
            value: '$severity / 10',
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(ResolvedLocation loc) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LocationRow(
            icon: Icons.gps_fixed_rounded,
            label: 'COORDINATES',
            value:
                '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          const Divider(height: 1, color: AppColors.divider),
          const SizedBox(height: AppSpacing.sm),
          _LocationRow(
            icon: Icons.place_outlined,
            label: 'ADDRESS',
            value: loc.address,
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
        ],
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
        Icon(icon, color: AppColors.olive, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppText.label),
              const SizedBox(height: 4),
              Text(
                value,
                style: AppText.body.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
