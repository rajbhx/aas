import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/di/repository_providers.dart';

/// Model Tuning Settings Screen
class ModelTuningSettings extends ConsumerWidget {
  const ModelTuningSettings({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('Model Tuning'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _SectionHeader(title: 'GENERATION PARAMETERS'),
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
                  icon: FontAwesomeIcons.temperatureHigh,
                  title: 'Temperature',
                  subtitle: 'Controls creativity (${settings.modelTemperature.toStringAsFixed(2)})',
                  value: settings.modelTemperature,
                  min: 0.01,
                  max: 2.0,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateModelTemperature(val);
                    ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                _SliderSetting(
                  icon: FontAwesomeIcons.bullseye,
                  title: 'Top P',
                  subtitle: 'Nucleus sampling threshold (${settings.modelTopP.toStringAsFixed(2)})',
                  value: settings.modelTopP,
                  min: 0.01,
                  max: 1.0,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateModelTopP(val);
                    ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                _SliderSetting(
                  icon: FontAwesomeIcons.layerGroup,
                  title: 'Top K',
                  subtitle: 'Limits vocabulary tokens (${settings.modelTopK})',
                  value: settings.modelTopK.toDouble(),
                  min: 1,
                  max: 100,
                  divisions: 99,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateModelTopK(val.toInt());
                    ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          _SectionHeader(title: 'LENGTH & MEMORY'),
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
                  icon: FontAwesomeIcons.textWidth,
                  title: 'Max Tokens',
                  subtitle: 'Maximum generation length (${settings.modelMaxTokens})',
                  value: settings.modelMaxTokens.toDouble(),
                  min: 256,
                  max: 8192,
                  divisions: 31,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateModelMaxTokens(val.toInt());
                    ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
                  },
                ),
                const Divider(color: Colors.white10, height: 1),
                _SliderSetting(
                  icon: FontAwesomeIcons.memory,
                  title: 'Context Size Limit',
                  subtitle: 'Caps memory footprint (${settings.contextSizeLimit})',
                  value: settings.contextSizeLimit.toDouble(),
                  min: 512,
                  max: 8192,
                  divisions: 15,
                  onChanged: (val) {
                    ref.read(settingsProvider.notifier).updateContextSizeLimit(val.toInt());
                    ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Parameter Info
          _SectionHeader(title: 'PARAMETER GUIDE'),
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
                _ParamInfo(
                  name: 'Temperature',
                  low: '0.1 = Focused, deterministic',
                  high: '1.5+ = Creative, random',
                ),
                const SizedBox(height: 12),
                _ParamInfo(
                  name: 'Top P',
                  low: '0.5 = Conservative sampling',
                  high: '0.95 = Broad sampling',
                ),
                const SizedBox(height: 12),
                _ParamInfo(
                  name: 'Top K',
                  low: '10 = Very focused',
                  high: '100 = More variety',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Parameter info widget
class _ParamInfo extends StatelessWidget {
  final String name;
  final String low;
  final String high;

  const _ParamInfo({
    required this.name,
    required this.low,
    required this.high,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text('↓ $low', style: TextStyle(color: EdgeTheme.textTertiary, fontSize: 11)),
        Text('↑ $high', style: TextStyle(color: EdgeTheme.textTertiary, fontSize: 11)),
      ],
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
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
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
              divisions: divisions,
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
