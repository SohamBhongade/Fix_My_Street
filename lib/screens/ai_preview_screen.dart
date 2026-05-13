import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../models/ai_analysis_result.dart';
import '../models/report_model.dart';
import '../services/ai_service.dart' show AIService, GroqException;
import '../services/database_service.dart' show DatabaseService, DatabaseException;
import '../services/location_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/severity_indicator.dart';

const Map<String, int> _categorySeverity = {
  'Exposed Wiring': 10,
  'Broken Pipelines': 10,
  'Potholes': 8,
  'Traffic Signal Malfunction': 8,
  'Broken Guardrails': 7,
  'Broken Street Lights': 6,
  'Water Accumulation': 5,
  'Cracked Sidewalks': 5,
  'Illegal Dumping': 5,
  'Overflowing Bins': 4,
  'Overgrown Vegetation': 4,
  'Broken Signs': 3,
  'Faded Road Markings': 3,
  'Litter Accumulation': 2,
  'Graffiti': 1,
};

Color _priorityColorFor(int severity) {
  if (severity >= 8) return const Color(0xFFFF1744);
  if (severity >= 4) return const Color(0xFFFF9100);
  return const Color(0xFF00E676);
}

String _priorityLabelFor(int severity) {
  if (severity >= 8) return 'CRITICAL';
  if (severity >= 4) return 'MODERATE';
  return 'MINOR';
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
      ? _categorySeverity[_manualCategoryOverride]!
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
    try {
      await DatabaseService.instance.saveReport(_buildReport());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report submitted. Thank you!')),
      );
      Navigator.of(context)..pop()..pop();
    } on DatabaseException catch (e) {
      if (!mounted) return;
      final isConnectionError = e.message.toLowerCase().contains('connect') ||
          e.message.toLowerCase().contains('master') ||
          e.message.toLowerCase().contains('socket') ||
          e.message.toLowerCase().contains('closed');

      if (!isRetry && isConnectionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connection lost. Retrying submission…')),
        );
        await Future.delayed(const Duration(seconds: 2));
        if (!mounted) return;
        await _submit(isRetry: true);
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission failed: $e')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'REPORT PREVIEW',
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
                GlassCard(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.file(
                      File(widget.imagePath),
                      height: 240,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_busy) _buildLoading(),
                if (_error != null) _buildError(_error!),
                if (!_busy && _error == null && _result != null) ...[
                  _buildAIAutoClassification(_result!),
                  const SizedBox(height: 18),
                  _buildManualDropdown(_result!),
                  const SizedBox(height: 18),
                  _buildStatGrid(_result!),
                  const SizedBox(height: 18),
                  if (_location != null) _buildLocationCard(_location!),
                  const SizedBox(height: 22),
                  _SubmitButton(
                    label: _submitting ? 'SUBMITTING…' : 'SUBMIT REPORT',
                    onTap: _submitting ? null : _submit,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return GlassCard(
      padding: const EdgeInsets.all(28),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF00E5FF)),
            const SizedBox(height: 16),
            const Text(
              'AI is analyzing your picture',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please wait...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return GlassCard(
      borderColor: const Color(0x66FF5252),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Color(0xFFFF5252)),
              SizedBox(width: 8),
              Text(
                'Something went wrong',
                style: TextStyle(
                  color: Color(0xFFFF5252),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF)),
              label: const Text(
                'Retry',
                style: TextStyle(color: Color(0xFF00E5FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAIAutoClassification(AIAnalysisResult r) {
    final severityColor = SeverityIndicator.colorFor(r.severity);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14060A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFF5252), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI AUTO CLASSIFICATION',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.55),
              fontSize: 11,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${r.category} detected',
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
                Shadow(color: severityColor.withValues(alpha: 0.5), blurRadius: 8),
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
          if (_manualCategoryOverride != null) ...[
            const SizedBox(height: 10),
            Text(
              'Manual override: $_manualCategoryOverride selected with $_effectiveSeverity/10 severity.',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 13,
                height: 1.45,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualDropdown(AIAnalysisResult r) {
    final categories = _categorySeverity.keys.toList();
    final initialValue = _manualCategoryOverride ??
        (categories.contains(r.category) ? r.category : categories.first);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'MANUAL CLASSIFICATION',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 11,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: initialValue,
          dropdownColor: const Color(0xFF14262C),
          iconEnabledColor: const Color(0xFF00E5FF),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF14262C),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
            ),
          ),
          items: categories
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _manualCategoryOverride = v);
          },
        ),
      ],
    );
  }

  Widget _buildStatGrid(AIAnalysisResult r) {
    final severity = _effectiveSeverity;
    final tileColor = _priorityColorFor(severity);

    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'PRIORITY',
            value: _priorityLabelFor(severity),
            color: tileColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'SEVERITY',
            value: _busy ? 'PENDING' : '$severity/10',
            color: _busy ? Colors.white.withValues(alpha: 0.5) : tileColor,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationCard(ResolvedLocation loc) {
    return GlassCard(
      borderColor: const Color(0x66B388FF),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LocationRow(
            icon: Icons.gps_fixed_rounded,
            label: 'GPS COORDINATES',
            value:
                '${loc.latitude.toStringAsFixed(5)}, ${loc.longitude.toStringAsFixed(5)}',
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
    return GlassCard(
      padding: const EdgeInsets.all(16),
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
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
              shadows: [
                Shadow(color: color.withValues(alpha: 0.55), blurRadius: 10),
              ],
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

class _SubmitButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _SubmitButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return AnimatedOpacity(
      opacity: disabled ? 0.5 : 1,
      duration: const Duration(milliseconds: 150),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF00E5FF),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Color(0x6600E5FF), blurRadius: 22),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
