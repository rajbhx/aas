import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/di/repository_providers.dart';

/// Appearance Settings Screen
class AppearanceSettings extends ConsumerWidget {
  const AppearanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Appearance'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _SectionHeader(title: 'INTERFACE'),
          _SettingsCard(
            icon: FontAwesomeIcons.palette,
            title: 'Theme Mode',
            subtitle: 'Current: ${settings.themeMode.toUpperCase()}',
            trailing: PopupMenuButton<String>(
              icon: const FaIcon(FontAwesomeIcons.chevronDown, size: 12, color: EdgeTheme.textTertiary),
              color: EdgeTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                ref.read(settingsProvider.notifier).updateThemeMode(value);
                ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'system', child: Text('System Default', style: TextStyle(fontSize: 13))),
                PopupMenuItem(value: 'light', child: Text('Light Mode', style: TextStyle(fontSize: 13))),
                PopupMenuItem(value: 'dark', child: Text('Dark Mode', style: TextStyle(fontSize: 13))),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: FontAwesomeIcons.bell,
            title: 'System Notifications',
            subtitle: 'Show app notifications and alerts',
            trailing: Switch(
              value: true,
              onChanged: (val) {},
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),

          // Theme Preview
          _SectionHeader(title: 'THEME PREVIEW'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: EdgeTheme.lavender,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: EdgeTheme.primaryPurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: EdgeTheme.successGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: EdgeTheme.warningOrange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Brainy.Ai uses a premium dark theme with soft lavender and deep purple accents for a modern, high-end experience.',
                  style: TextStyle(
                    color: EdgeTheme.textTertiary,
                    fontSize: 12,
                    height: 1.5,
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

/// Settings card widget
class _SettingsCard extends StatelessWidget {
  final FaIconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
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
                        subtitle,
                        style: TextStyle(
                          color: EdgeTheme.textTertiary,
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
