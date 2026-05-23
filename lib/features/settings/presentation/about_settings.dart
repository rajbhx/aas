import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/edge_theme.dart';

/// About Settings Screen
class AboutSettings extends StatelessWidget {
  const AboutSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('About'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // App Logo & Name
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: EdgeTheme.lavender.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const FaIcon(
                    FontAwesomeIcons.robot,
                    color: EdgeTheme.lavender,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'BRAINY.AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version ${AppConstants.appVersion}',
                  style: TextStyle(
                    color: EdgeTheme.textTertiary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _SectionHeader(title: 'SYSTEM INFORMATION'),
          _InfoCard(
            icon: FontAwesomeIcons.microchip,
            title: 'Kernel Version',
            value: '${AppConstants.appVersion} (Stable)',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: FontAwesomeIcons.codeBranch,
            title: 'Build Signature',
            value: 'v1.1.0-gold-stable+20260407',
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: FontAwesomeIcons.android,
            title: 'Platform',
            value: 'Android 10+ (API 29+)',
          ),

          const SizedBox(height: 24),

          _SectionHeader(title: 'TECHNOLOGY STACK'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _TechItem(name: 'Framework', value: 'Flutter 3.24+'),
                const SizedBox(height: 12),
                _TechItem(name: 'Language', value: 'Dart 3.5+'),
                const SizedBox(height: 12),
                _TechItem(name: 'LLM Engines', value: 'llama.cpp'),
                const SizedBox(height: 12),
                _TechItem(name: 'State Management', value: 'Riverpod'),
                const SizedBox(height: 12),
                _TechItem(name: 'Database', value: 'Drift (SQLite)'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _SectionHeader(title: 'LEGAL'),
          _InfoCard(
            icon: FontAwesomeIcons.fileContract,
            title: 'License',
            value: 'MIT License',
            onTap: () => _showLicense(context),
          ),
          const SizedBox(height: 12),
          _InfoCard(
            icon: FontAwesomeIcons.shieldHalved,
            title: 'Privacy Policy',
            value: 'All data processed locally',
            onTap: () => _showPrivacy(context),
          ),

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

  void _showLicense(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: EdgeTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MIT License',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Copyright (c) 2026 Brainy.Ai\n\nPermission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files.',
              style: TextStyle(
                color: EdgeTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPrivacy(BuildContext context) {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: EdgeTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Brainy.Ai processes all data locally on your device. No personal information, conversations, or models are ever transmitted to external servers. Your privacy is our priority.',
              style: TextStyle(
                color: EdgeTheme.textSecondary,
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tech item widget
class _TechItem extends StatelessWidget {
  final String name;
  final String value;

  const _TechItem({
    required this.name,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          name,
          style: TextStyle(
            color: EdgeTheme.textTertiary,
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Info card widget
class _InfoCard extends StatelessWidget {
  final FaIconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: EdgeTheme.lavender.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: FaIcon(icon, color: EdgeTheme.lavender, size: 18),
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
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          color: EdgeTheme.textTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
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

/// Section header widget
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: TextStyle(
          color: EdgeTheme.textTertiary,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}
