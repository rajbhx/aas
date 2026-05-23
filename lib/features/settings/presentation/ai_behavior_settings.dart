import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/di/repository_providers.dart';

/// AI Behavior Settings Screen
class AIBehaviorSettings extends ConsumerWidget {
  const AIBehaviorSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('AI Behavior'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _SectionHeader(title: 'REASONING'),
          _SettingsCard(
            icon: FontAwesomeIcons.brain,
            title: 'Disable Deep Reasoning',
            subtitle: 'Force models to answer immediately without the hidden "Thinking" step. Makes replies faster but potentially less accurate.',
            trailing: Switch(
              value: settings.disableDeepReasoning,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).updateDisableDeepReasoning(val);
                ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
              },
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),

          _SectionHeader(title: 'RESPONSE PREFERENCES'),
          _SettingsCard(
            icon: FontAwesomeIcons.solidBell,
            title: 'Response Summary',
            subtitle: 'Show AI snapshot in notifications',
            trailing: Switch(
              value: settings.responseSummaryEnabled,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).updateResponseSummaryEnabled(val);
                ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
              },
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: FontAwesomeIcons.waveSquare,
            title: 'Voice Rhythm Visualizer',
            subtitle: 'Visualize AI speech rhythm during generation',
            trailing: Switch(
              value: settings.voiceVisualizerEnabled,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).updateVoiceVisualizerEnabled(val);
                ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
              },
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),

          _SectionHeader(title: 'AI VOICE CONFIGURATION'),
          _SettingsCard(
            icon: FontAwesomeIcons.microphoneLines,
            title: 'AI Voice Generator',
            subtitle: 'Enable or disable AI spoken responses in Live Mode',
            trailing: Switch(
              value: settings.aiVoiceEnabled,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).updateAiVoiceEnabled(val);
                ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
              },
              activeThumbColor: EdgeTheme.lavender,
            ),
          ),

          if (settings.aiVoiceEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: EdgeTheme.surfaceColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  _SliderSetting(
                    icon: FontAwesomeIcons.music,
                    title: 'Voice Pitch',
                    subtitle: 'Adjust the tone (${settings.aiVoicePitch.toStringAsFixed(2)})',
                    value: settings.aiVoicePitch,
                    min: 0.5,
                    max: 2.0,
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).updateAiVoicePitch(val);
                      ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
                    },
                  ),
                  const Divider(color: Colors.white10, height: 1),
                  _SliderSetting(
                    icon: FontAwesomeIcons.gaugeHigh,
                    title: 'Voice Speed',
                    subtitle: 'Adjust the talking speed (${settings.aiVoiceSpeed.toStringAsFixed(2)})',
                    value: settings.aiVoiceSpeed,
                    min: 0.1,
                    max: 1.5,
                    onChanged: (val) {
                      ref.read(settingsProvider.notifier).updateAiVoiceSpeed(val);
                      ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Slider setting widget
class _SliderSetting extends StatelessWidget {
  final FaIconData icon;
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, color: EdgeTheme.lavender, size: 14),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: EdgeTheme.textTertiary,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EdgeTheme.lavender,
              inactiveTrackColor: EdgeTheme.lavender.withValues(alpha: 0.2),
              thumbColor: EdgeTheme.lavender,
              overlayColor: EdgeTheme.lavender.withValues(alpha: 0.1),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: onChanged,
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
