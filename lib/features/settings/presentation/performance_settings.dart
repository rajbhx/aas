import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/di/repository_providers.dart';
import 'acceleration_config.dart';

/// Performance Settings Screen
class PerformanceSettings extends ConsumerWidget {
  const PerformanceSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Performance'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          // Acceleration Section
          const AccelerationConfig(),
          const SizedBox(height: 24),

          // Memory Settings
          _SectionHeader(title: 'MEMORY OPTIMIZATION'),
          _SettingsCard(
            icon: FontAwesomeIcons.microchip,
            title: 'Enable Low RAM Mode',
            subtitle: 'Optimizes local LLM for low-memory devices (≤6 GB RAM). Uses 4-bit quantization, reduced context length, and lighter inference.',
            trailing: Switch(
              value: settings.lowRamMode,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).updateLowRamMode(val);
                ref.read(settingsRepositoryProvider).updateLowRamMode(val);
              },
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: FontAwesomeIcons.bolt,
            title: 'Aggressive Memory Saving',
            subtitle: 'Unloads the entire local LLM from RAM when the app is idle or sent to background. Can free 2–4 GB of RAM instantly.',
            trailing: Switch(
              value: settings.aggressiveMemorySaving,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).updateAggressiveMemorySaving(val);
                ref.read(settingsRepositoryProvider).updateAggressiveMemorySaving(val);
              },
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: FontAwesomeIcons.trashCan,
            title: 'Clear Model Cache on Exit',
            subtitle: 'Automatically deletes temporary KV cache when the app is closed to recover maximum memory.',
            trailing: Switch(
              value: settings.clearCacheOnExit,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).updateClearCacheOnExit(val);
                ref.read(settingsRepositoryProvider).updateClearCacheOnExit(val);
              },
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),

          // Background Behavior
          _SectionHeader(title: 'BACKGROUND BEHAVIOR'),
          _BackgroundBehaviorCard(
            terminateOnBackground: settings.terminateOnBackground,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              ref.read(settingsProvider.notifier).updateTerminateOnBackground(val);
              ref.read(settingsRepositoryProvider).updateTerminateOnBackground(val);
            },
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

/// Background behavior card
class _BackgroundBehaviorCard extends StatelessWidget {
  final bool terminateOnBackground;
  final ValueChanged<bool> onChanged;

  const _BackgroundBehaviorCard({
    required this.terminateOnBackground,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: terminateOnBackground 
                  ? EdgeTheme.errorRed.withValues(alpha: 0.1) 
                  : EdgeTheme.successGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: FaIcon(
              terminateOnBackground ? FontAwesomeIcons.powerOff : FontAwesomeIcons.pause,
              color: terminateOnBackground ? EdgeTheme.errorRed : EdgeTheme.successGreen,
              size: 18,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Background Behavior',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  terminateOnBackground 
                      ? 'Kill LLM process when app goes to background'
                      : 'Keep LLM in memory when app is backgrounded',
                  style: TextStyle(
                    color: EdgeTheme.textTertiary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: terminateOnBackground,
            onChanged: onChanged,
            activeThumbColor: EdgeTheme.lavender,
          ),
        ],
      ),
    );
  }
}
