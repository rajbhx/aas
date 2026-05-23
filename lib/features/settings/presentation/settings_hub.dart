import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../presentation/routing/app_router.dart';

/// Settings Hub - Categorized settings navigation
class SettingsHub extends ConsumerWidget {
  const SettingsHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = [
      _CategoryTile(
        icon: FontAwesomeIcons.bolt,
        iconColor: Colors.amber,
        title: 'Performance',
        subtitle: 'Memory, GPU acceleration & background behavior',
        route: AppRoutes.settingsPerformance,
      ),
      _CategoryTile(
        icon: FontAwesomeIcons.palette,
        iconColor: Colors.purple,
        title: 'Appearance',
        subtitle: 'Theme, notifications & interface preferences',
        route: AppRoutes.settingsAppearance,
      ),
      _CategoryTile(
        icon: FontAwesomeIcons.shieldHalved,
        iconColor: Colors.green,
        title: 'Security & Privacy',
        subtitle: 'Biometric lock & data encryption',
        route: AppRoutes.settingsSecurity,
      ),
      _CategoryTile(
        icon: FontAwesomeIcons.sliders,
        iconColor: Colors.blue,
        title: 'Model Tuning',
        subtitle: 'Temperature, top P/K, tokens & context size',
        route: AppRoutes.settingsModelTuning,
      ),
      _CategoryTile(
        icon: FontAwesomeIcons.brain,
        iconColor: Colors.pink,
        title: 'AI Behavior',
        subtitle: 'Reasoning, voice config & response preferences',
        route: AppRoutes.settingsAIBehavior,
      ),
      _CategoryTile(
        icon: FontAwesomeIcons.circleInfo,
        iconColor: EdgeTheme.lavender,
        title: 'About',
        subtitle: 'Version, build info & change log',
        route: AppRoutes.settingsAbout,
      ),
    ];

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Settings'),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const FaIcon(FontAwesomeIcons.barsStaggered, size: 18),
            onPressed: () => Scaffold.of(context).openEndDrawer(),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // System Banner
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: EdgeTheme.lavender.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EdgeTheme.lavender.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(FontAwesomeIcons.robot, color: EdgeTheme.lavender, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'BRAINY.AI',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 1),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SECURE • OFFLINE • PRIVATE',
                        style: TextStyle(
                          color: EdgeTheme.lavender.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          ...categories,
          const SizedBox(height: 32),
          Center(
            child: Text(
              'MADE FOR THE BOLD',
              style: TextStyle(
                color: EdgeTheme.textTertiary.withValues(alpha: 0.3),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Category tile widget
class _CategoryTile extends StatelessWidget {
  final FaIconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String route;

  const _CategoryTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            context.push(route);
          },
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: FaIcon(icon, color: iconColor, size: 20),
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: EdgeTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const FaIcon(
                  FontAwesomeIcons.chevronRight,
                  size: 12,
                  color: EdgeTheme.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
