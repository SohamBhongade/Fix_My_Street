import 'package:flutter/material.dart';

import '../widgets/glass_card.dart';
import 'camera_screen.dart';
import 'volunteer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AuroraBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 28),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        GlassCard(
                          padding: const EdgeInsets.all(22),
                          onTap: () => _navigate(context, const CameraScreen()),
                          child: _ActionTile(
                            icon: Icons.camera_alt_rounded,
                            accent: const Color(0xFF00E5FF),
                            title: 'Report an Issue',
                            subtitle:
                                'Snap a photo. AI analyzes severity and category in seconds.',
                          ),
                        ),
                        const SizedBox(height: 18),
                        GlassCard(
                          padding: const EdgeInsets.all(22),
                          borderColor: const Color(0x66B388FF),
                          onTap: () =>
                              _navigate(context, const VolunteerScreen()),
                          child: _ActionTile(
                            icon: Icons.volunteer_activism_rounded,
                            accent: const Color(0xFFB388FF),
                            title: 'Volunteer Console',
                            subtitle:
                                'Browse open reports, prioritize critical fixes, mark them resolved.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildFooter(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFFB388FF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x6600E5FF),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: const Icon(Icons.eco_rounded, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text(
              'FixMyStreet AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 22,
                letterSpacing: 0.4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Smart urban maintenance for Ras Al Khaimah.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'Powered by Gemini · MongoDB Atlas',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.45),
          fontSize: 11,
          letterSpacing: 1.4,
        ),
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;

  const _ActionTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: accent.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.45),
                blurRadius: 16,
              ),
            ],
          ),
          child: Icon(icon, color: accent, size: 28),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        Icon(
          Icons.arrow_forward_ios_rounded,
          color: accent,
          size: 16,
        ),
      ],
    );
  }
}

class _AuroraBackground extends StatelessWidget {
  const _AuroraBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: RadialGradient(
          radius: 1.2,
          center: Alignment(-0.6, -0.8),
          colors: [
            Color(0xFF1A1B3A),
            Color(0xFF0A0A1F),
            Color(0xFF050510),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -80,
            right: -60,
            child: _blob(220, const Color(0xFF00E5FF)),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: _blob(260, const Color(0xFFB388FF)),
          ),
        ],
      ),
    );
  }

  Widget _blob(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: 0.32),
            color.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }
}
