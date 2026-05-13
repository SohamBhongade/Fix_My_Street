import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../services/database_service.dart';
import '../widgets/severity_indicator.dart';
import 'camera_screen.dart';
import 'issue_detail_screen.dart';
import 'map_explore_screen.dart';
import 'volunteer_screen.dart';

const Color _kBackground = Color(0xFF000000);
const Color _kSurface = Color(0xFF13181F);
const Color _kCyan = Color(0xFF00E5FF);
const Color _kTextPrimary = Color(0xFFFFFFFF);
const Color _kTextSecondary = Color(0xFF9CA3AF);

const LatLng _kRakCenter = LatLng(25.7911, 55.9432);
const double _kRakZoom = 11.0;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ReportModel> _reports = const [];
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

  void _navigate(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBackground,
      body: SafeArea(
        child: Column(
          children: [
            const _BrandHeader(),
            Container(
              height: 0.5,
              color: _kCyan.withValues(alpha: 0.5),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Expanded(
                      child: _MapHeroCard(
                        reports: _reports,
                        loading: _loading,
                        onExplore: () => _navigate(const MapExploreScreen()),
                        onMarkerTap: (r) =>
                            _navigate(IssueDetailScreen(report: r)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 88,
                      child: _ActionTile(
                        icon: Icons.camera_alt_rounded,
                        title: 'Report an Issue',
                        subtitle:
                            'Snap a photo. AI analyzes severity and category instantly.',
                        onTap: () => _navigate(const CameraScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 88,
                      child: _ActionTile(
                        icon: Icons.volunteer_activism_rounded,
                        title: 'Volunteer Console',
                        subtitle:
                            'Browse open reports and mark critical fixes resolved.',
                        onTap: () => _navigate(const VolunteerScreen()),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kBackground,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Row(
        children: [
          const Icon(
            Icons.location_on_rounded,
            color: _kCyan,
            size: 32,
          ),
          const SizedBox(width: 14),
          const Text(
            'FIXMYSTREET AI',
            style: TextStyle(
              color: _kTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _MapHeroCard extends StatelessWidget {
  final List<ReportModel> reports;
  final bool loading;
  final VoidCallback onExplore;
  final ValueChanged<ReportModel> onMarkerTap;

  const _MapHeroCard({
    required this.reports,
    required this.loading,
    required this.onExplore,
    required this.onMarkerTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCyan, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              options: const MapOptions(
                initialCenter: _kRakCenter,
                initialZoom: _kRakZoom,
                interactionOptions:
                    InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                ),
                if (!loading && reports.isNotEmpty)
                  MarkerLayer(
                    markers: reports.map((r) {
                      final dotSize = SeverityDot.sizeFor(r.severity);
                      return Marker(
                        point: LatLng(r.latitude, r.longitude),
                        width: dotSize,
                        height: dotSize,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onMarkerTap(r),
                          child: SeverityDot(severity: r.severity),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
            if (loading)
              const Align(
                alignment: Alignment.center,
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: _kCyan,
                    strokeWidth: 2,
                  ),
                ),
              ),
            // Bottom CTA strip — sits above the map; only this strip opens
            // the full Explore Map so individual marker taps still work.
            Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onExplore,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00FFFFFF), Color(0xF2FFFFFF)],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(18, 40, 18, 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'EXPLORE LIVE MAP',
                                style: TextStyle(
                                  color: _kBackground,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 17,
                                  letterSpacing: 1.6,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                loading
                                    ? 'Loading reports across Ras Al Khaimah…'
                                    : reports.isEmpty
                                        ? 'Tap to view all reports across Ras Al Khaimah.'
                                        : '${reports.length} live reports · tap a dot for details.',
                                style: TextStyle(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: _kCyan,
                          size: 22,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _kSurface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _kCyan, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _kCyan, width: 1),
                ),
                child: Icon(icon, color: _kCyan, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _kTextPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                color: _kCyan,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
