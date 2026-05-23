import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/di/state_providers.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../data/repositories/settings_repository.dart';
import '../../../core/di/repository_providers.dart';
import '../../../data/datasources/hugging_face_service.dart';
import './saved_data_screen.dart';
import './hf_account_screen.dart';
import './hf_login_screen.dart';
import './acceleration_config.dart';

/// Settings screen with modern charcoal aesthetic
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _hasToken = false;

  @override
  void initState() {
    super.initState();
    _checkTokenStatus();
  }

  Future<void> _checkTokenStatus() async {
    final hfService = ref.read(hfServiceProvider);
    final token = await hfService.getToken();
    if (mounted) {
      setState(() {
        _hasToken = token != null && token.isNotEmpty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final activeModel = ref.watch(activeModelProvider);

    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('System Configuration'),
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

          // Core Section
          _SectionHeader(title: 'INTELLIGENCE CORE'),
          _SettingsCard(
            icon: FontAwesomeIcons.microchip,
            title: 'Active Intelligence',
            subtitle: activeModel?.name ?? 'No core loaded',
            trailing: TextButton(
              onPressed: () => context.go('/model-hub'),
              style: TextButton.styleFrom(foregroundColor: EdgeTheme.lavender),
              child: const Text('MANAGE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ),

          const SizedBox(height: 24),

          // Memory & Performance Section
          _SectionHeader(title: 'MEMORY & PERFORMANCE'),
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
              activeColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 12),

          // Background Behavior
          _BackgroundBehaviorCard(
            terminateOnBackground: settings.terminateOnBackground,
            onChanged: (val) {
              HapticFeedback.selectionClick();
              ref.read(settingsProvider.notifier).updateTerminateOnBackground(val);
              ref.read(settingsRepositoryProvider).updateTerminateOnBackground(val);
            },
          ),

          const SizedBox(height: 12),

          _SettingsCard(
            icon: FontAwesomeIcons.bolt,
            title: 'Aggressive Memory Saving',
            subtitle: 'Unloads the entire local LLM from RAM when the app is idle or sent to background. Can free 2–4 GB of RAM instantly. Slightly longer reload time on resume.',
            trailing: Switch(
              value: settings.aggressiveMemorySaving,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).updateAggressiveMemorySaving(val);
                ref.read(settingsRepositoryProvider).updateAggressiveMemorySaving(val);
              },
              activeColor: EdgeTheme.lavender,
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
              activeColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),

          // Acceleration Section
          const AccelerationConfig(),

          const SizedBox(height: 24),

          // System Section
          _SectionHeader(title: 'SYSTEM'),
          _SettingsCard(
            icon: FontAwesomeIcons.palette,
            title: 'Interface Theme',
            subtitle: settings.themeMode.toUpperCase(),
            trailing: PopupMenuButton<String>(
              icon: const FaIcon(FontAwesomeIcons.chevronDown, size: 12, color: EdgeTheme.textTertiary),
              color: EdgeTheme.surfaceColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              onSelected: (value) {
                ref.read(settingsProvider.notifier).updateThemeMode(value);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'system', child: Text('SYSTEM', style: TextStyle(fontSize: 12))),
                PopupMenuItem(value: 'light', child: Text('LIGHT', style: TextStyle(fontSize: 12))),
                PopupMenuItem(value: 'dark', child: Text('DARK', style: TextStyle(fontSize: 12))),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _SettingsCard(
            icon: FontAwesomeIcons.bell,
            title: 'System Notifications',
            subtitle: 'ENABLED',
            trailing: Switch(
              value: true,
              onChanged: (val) {},
              activeColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),

          // Security Section
          _SectionHeader(title: 'SECURITY & PRIVACY'),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              children: [
                const FaIcon(FontAwesomeIcons.shieldHalved, color: EdgeTheme.lavender, size: 20),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Enclave Encryption',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'All neural processing is strictly local. Identity data is never transmitted.',
                        style: TextStyle(color: EdgeTheme.textTertiary, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          _SettingsCard(
            icon: FontAwesomeIcons.fingerprint,
            title: 'Biometric Lock',
            subtitle: 'Require FaceID/Fingerprint to access BRAINY.AI.',
            trailing: Switch(
              value: settings.biometricLock,
              onChanged: (val) {
                HapticFeedback.selectionClick();
                ref.read(settingsProvider.notifier).updateBiometricLock(val);
                ref.read(settingsRepositoryProvider).updateBiometricLock(val);
              },
              activeColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),

          // Hugging Face Section
          _SectionHeader(title: 'HUGGING FACE CLOUD'),
          
          if (_hasToken) ...[
            _HFAccountCard(onTap: () {
              Navigator.push(
                context, 
                MaterialPageRoute(builder: (_) => const HFAccountScreen()),
              );
            }),
            const SizedBox(height: 12),
          ],

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const FaIcon(FontAwesomeIcons.cloud, color: EdgeTheme.lavender, size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Cloud Intelligence',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            _hasToken ? 'Connected via Secure Session' : 'Get access to powerful remote nodes',
                            style: const TextStyle(color: EdgeTheme.textTertiary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    if (_hasToken)
                      IconButton(
                        icon: const FaIcon(FontAwesomeIcons.trashCan, size: 14, color: EdgeTheme.errorRed),
                        onPressed: () async {
                          final hfService = ref.read(hfServiceProvider);
                          await hfService.deleteToken();
                          ref.invalidate(hfProfileProvider);
                          setState(() {
                            _hasToken = false;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (!_hasToken)
                  ElevatedButton.icon(
                    onPressed: () async {
                      final success = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HFLoginScreen()),
                      );
                      if (success == true) {
                        ref.invalidate(hfProfileProvider);
                        setState(() => _hasToken = true);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: EdgeTheme.lavender,
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.key, size: 16),
                    label: const Text('CONNECT HUGGING FACE TOKEN', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HFAccountScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EdgeTheme.lavender,
                      side: const BorderSide(color: EdgeTheme.lavender),
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const FaIcon(FontAwesomeIcons.userLarge, size: 14),
                    label: const Text('MANAGE CLOUD SESSION', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Note: Connect using an Access Token (Read/Write) to run remote models directly.',
                  style: TextStyle(color: EdgeTheme.textSecondary.withValues(alpha: 0.5), fontSize: 10, height: 1.4, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Fine Tuning Section
          _SectionHeader(title: 'MODEL FINE-TUNING'),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              children: [
                _SliderSetting(
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
                const Divider(color: Colors.white10, height: 1),
                _SliderSetting(
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
                  title: 'Context Size Limit (RAM)',
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

          _SectionHeader(title: 'INTELLIGENCE SETTINGS'),
          _SettingsCard(
            icon: FontAwesomeIcons.brain,
            title: 'Disable Deep Reasoning',
            subtitle: 'Try to force models to answer immediately without the hidden "Thinking" step. Makes replies much faster but potentially less accurate.',
            trailing: Switch(
              value: settings.disableDeepReasoning,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).updateDisableDeepReasoning(val);
                ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
              },
              activeColor: EdgeTheme.lavender,
            ),
          ),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: FontAwesomeIcons.solidBell,
            title: 'Response Summary',
            subtitle: 'Show AI snapshot in notifications.',
            trailing: Switch(
              value: settings.responseSummaryEnabled,
              onChanged: (val) => ref.read(settingsProvider.notifier).updateResponseSummaryEnabled(val),
              activeColor: EdgeTheme.lavender,
            ),
          ),
          _SettingsCard(
            icon: FontAwesomeIcons.waveSquare,
            title: 'Voice Rhythm',
            subtitle: 'Visualize AI speech rhythm.',
            trailing: Switch(
              value: settings.voiceVisualizerEnabled,
              onChanged: (val) => ref.read(settingsProvider.notifier).updateVoiceVisualizerEnabled(val),
              activeColor: EdgeTheme.lavender,
            ),
          ),

          const SizedBox(height: 24),
          
          _SectionHeader(title: 'AI VOICE CONFIGURATION'),
          _SettingsCard(
            icon: FontAwesomeIcons.microphoneLines,
            title: 'AI Voice Generator',
            subtitle: 'Enable or disable AI spoken responses in Live Mode.',
            trailing: Switch(
              value: settings.aiVoiceEnabled,
              onChanged: (val) {
                ref.read(settingsProvider.notifier).updateAiVoiceEnabled(val);
                ref.read(settingsRepositoryProvider).saveSettings(ref.read(settingsProvider));
              },
              activeColor: EdgeTheme.lavender,
            ),
          ),
          if (settings.aiVoiceEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: EdgeTheme.surfaceColor,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Column(
                children: [
                  _SliderSetting(
                    title: 'Voice Pitch',
                    subtitle: 'Adjust the tone of the voice (${settings.aiVoicePitch.toStringAsFixed(2)})',
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

          const SizedBox(height: 24),
          
          // Save Data Section
          _SectionHeader(title: 'DATA PERSISTENCE'),
          _SettingsCard(
            icon: FontAwesomeIcons.database,
            title: 'Save Data',
            subtitle: 'Access your saved Creations and Artifacts.',
            trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EdgeTheme.textTertiary),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SavedDataScreen()),
              );
            },
          ),

          const SizedBox(height: 24),

          // About Section
          _SectionHeader(title: 'SYSTEM KERNEL'),
          _SettingsCard(
            icon: FontAwesomeIcons.microchip,
            title: 'Kernel Version',
            subtitle: '${AppConstants.appVersion} (Stable)',
          ),
          _SettingsCard(
            icon: FontAwesomeIcons.codeBranch,
            title: 'Build Signature',
            subtitle: 'v1.1.0-gold-stable+20260407',
          ),
          _SettingsCard(
            icon: FontAwesomeIcons.newspaper,
            title: 'Change Log',
            subtitle: 'Tap to see what\'s new in the system.',
            trailing: const FaIcon(FontAwesomeIcons.chevronRight, size: 12, color: EdgeTheme.textTertiary),
            onTap: () => _showChangelog(context),
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

  void _showChangelog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: EdgeTheme.surfaceColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 32),
            const Row(
              children: [
                FaIcon(FontAwesomeIcons.newspaper, color: EdgeTheme.lavender, size: 20),
                SizedBox(width: 16),
                Text('SYSTEM CHANGELOG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: [
                   _buildChangeItem('v1.1.0', 'Kernel update with asynchronous wallpaper engine.'),
                   _buildChangeItem('v1.0.8', 'Integrated Cloud Intelligence via Hugging Face.'),
                   _buildChangeItem('v1.0.5', 'Added direct code execution sandbox for artifacts.'),
                   _buildChangeItem('v1.0.2', 'Optimized local LLM inference speeds.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChangeItem(String version, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: EdgeTheme.lavender.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Text(version, style: const TextStyle(color: EdgeTheme.lavender, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(description, style: const TextStyle(color: EdgeTheme.textSecondary, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: EdgeTheme.textTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

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
    return Material(
      color: EdgeTheme.surfaceColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
              child: Center(child: FaIcon(icon, color: EdgeTheme.textSecondary, size: 16)),
            ),
            title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15)),
            subtitle: Text(subtitle, style: const TextStyle(color: EdgeTheme.textTertiary, fontSize: 12)),
            trailing: trailing,
          ),
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Background Behavior',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOption(
                  context,
                  title: 'Terminate',
                  subtitle: 'Recommended – frees maximum RAM',
                  isSelected: terminateOnBackground,
                  onTap: () => onChanged(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOption(
                  context,
                  title: 'Keep Alive',
                  subtitle: 'Faster resume but uses more RAM',
                  isSelected: !terminateOnBackground,
                  onTap: () => onChanged(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Current status: ${terminateOnBackground ? "Model will be unloaded when backgrounded" : "Model will stay in memory"}',
            style: const TextStyle(color: EdgeTheme.lavender, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? EdgeTheme.lavender.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? EdgeTheme.lavender : Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? EdgeTheme.lavender : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected ? EdgeTheme.lavender.withValues(alpha: 0.7) : EdgeTheme.textTertiary,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliderSetting extends StatelessWidget {
  final String title;
  final String subtitle;
  final double value;
  final double min;
  final double max;
  final int? divisions;
  final ValueChanged<double> onChanged;

  const _SliderSetting({
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: EdgeTheme.textTertiary, fontSize: 11)),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: EdgeTheme.lavender,
              inactiveTrackColor: Colors.white10,
              thumbColor: EdgeTheme.lavender,
              overlayColor: EdgeTheme.lavender.withValues(alpha: 0.1),
              trackHeight: 2,
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

class _HFAccountCard extends ConsumerWidget {
  final VoidCallback onTap;
  const _HFAccountCard({required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hfService = ref.read(hfServiceProvider);

    return FutureBuilder<HFProfile>(
      future: hfService.fetchUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final isLoading = snapshot.connectionState == ConnectionState.waiting;

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: EdgeTheme.surfaceColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.1)),
              boxShadow: [
                 if (profile?.isPro ?? false) 
                   BoxShadow(
                     color: EdgeTheme.lavender.withValues(alpha: 0.1),
                     blurRadius: 10,
                     offset: const Offset(0, 4),
                   ),
              ],
            ),
            child: Row(
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(strokeWidth: 2, color: EdgeTheme.lavender),
                  )
                else
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: EdgeTheme.lavender.withValues(alpha: 0.1),
                    backgroundImage: profile?.avatarUrl != null ? NetworkImage(profile!.avatarUrl!) : null,
                    child: profile?.avatarUrl == null 
                        ? const FaIcon(FontAwesomeIcons.user, color: EdgeTheme.lavender, size: 16)
                        : null,
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isLoading ? 'SYNCING PROFILE...' : (profile?.fullname ?? profile?.username ?? 'CLOUD ACCOUNT'),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isLoading ? 'Connecting to Hub...' : '${profile?.plan.toUpperCase() ?? "STANDARD"} TIER • ${profile?.isPro ?? false ? "HIGH" : "STANDARD"} PRIORITY',
                        style: TextStyle(
                          color: (profile?.isPro ?? false) ? EdgeTheme.lavender : EdgeTheme.textTertiary, 
                          fontSize: 10, 
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const FaIcon(FontAwesomeIcons.chevronRight, color: Colors.white10, size: 14),
              ],
            ),
          ),
        );
      },
    );
  }
}
