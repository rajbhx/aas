import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/edge_theme.dart';
import '../../core/di/state_providers.dart';
import '../../features/settings/presentation/saved_data_screen.dart';

/// Side navigation drawer - positioned on RIGHT side
/// Using FontAwesome icons for premium look
class AppDrawer extends ConsumerWidget {
  final String currentRoute;

  const AppDrawer({
    super.key,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: EdgeTheme.primaryBackground,
      width: 280,
      child: Column(
        children: [
          // Header with gradient
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
            decoration: const BoxDecoration(
              gradient: EdgeTheme.brainyGradient,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: const FaIcon(
                        FontAwesomeIcons.robot,
                        color: EdgeTheme.lavender,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.robot,
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'BRAINY.AI',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 2,
                                  ),
                            ),
                          ],
                        ),
                        const Text(
                          'Brainy Intelligence',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildNewChatButton(context, ref),
          const SizedBox(height: 12),
          // Navigation items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildSectionLabel('AI INTELLIGENCE'),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.message,
                  label: 'Chat',
                  route: '/',
                  currentRoute: currentRoute,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.compass,
                  label: 'Model Hub',
                  route: '/model-hub',
                  currentRoute: currentRoute,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.microchip,
                  label: 'My Models',
                  route: '/my-models',
                  currentRoute: currentRoute,
                ),
                
                const SizedBox(height: 24),
                _buildSectionLabel('ANALYSIS & HISTORY'),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.clockRotateLeft,
                  label: 'Conversations',
                  route: '/history',
                  currentRoute: currentRoute,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.chartLine,
                  label: 'Benchmarks',
                  route: '/benchmarks',
                  currentRoute: currentRoute,
                ),

                const SizedBox(height: 24),
                _buildSectionLabel('ARCHIVES & DATA'),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.database,
                  label: 'Saved Data',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SavedDataScreen()),
                    );
                  },
                ),

                const SizedBox(height: 24),
                _buildSectionLabel('ADMINISTRATION'),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.gaugeHigh,
                  label: 'System Info',
                  route: '/system',
                  currentRoute: currentRoute,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.mask,
                  label: 'AI Personality',
                  route: '/personality',
                  currentRoute: currentRoute,
                ),
                const SizedBox(height: 4),
                _buildNavItem(
                  context,
                  icon: FontAwesomeIcons.gear,
                  label: 'Settings',
                  route: '/settings',
                  currentRoute: currentRoute,
                ),
                
                const SizedBox(height: 24),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
                const SizedBox(height: 16),
                _buildNavItem(
                   context,
                   icon: FontAwesomeIcons.circleExclamation,
                   label: 'Terminate Session',
                   color: EdgeTheme.errorRed,
                   onTap: () {
                     HapticFeedback.lightImpact();
                     ref.read(chatActionsProvider.notifier).requestReset();
                     Navigator.pop(context);
                     context.go('/');
                   },
                 ),
              ],
            ),
          ),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: Colors.white.withValues(alpha: 0.05), width: 1.0),
              ),
            ),
            child: Row(
              children: [
                const FaIcon(
                  FontAwesomeIcons.shieldHalved,
                  size: 16,
                  color: EdgeTheme.lavender,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '100% Offline & Private',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: EdgeTheme.textTertiary,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Text(
        label,
        style: TextStyle(
          color: EdgeTheme.textTertiary.withValues(alpha: 0.5),
          fontSize: 9,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required FaIconData icon,
    required String label,
    String? route,
    String? currentRoute,
    Color? color,
    VoidCallback? onTap,
  }) {
    final isSelected = route != null && currentRoute == route;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      leading: Container(
        width: 32,
        height: 32,
        decoration: isSelected
            ? const BoxDecoration(
                gradient: EdgeTheme.brainyGradient,
                shape: BoxShape.circle,
              )
            : BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle,
              ),
        padding: const EdgeInsets.all(8),
        child: FaIcon(
          icon,
          color: isSelected ? Colors.white : (color ?? EdgeTheme.textSecondary),
          size: 14,
        ),
      ),
      title: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isSelected ? Colors.white : (color ?? EdgeTheme.textSecondary),
              fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
              letterSpacing: 0.5,
              fontSize: 12,
            ),
      ),
      onTap: onTap ?? () {
        HapticFeedback.lightImpact();
        if (route != null) {
          Navigator.pop(context);
          context.navigate(route);
        }
      },
    );
  }

  Widget _buildNewChatButton(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          ref.read(chatActionsProvider.notifier).requestClear();
          Navigator.pop(context);
          context.go('/');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            gradient: EdgeTheme.brainyGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: EdgeTheme.purpleGlow(EdgeTheme.lavender),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const FaIcon(
                FontAwesomeIcons.plus,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              const Text(
                'NEW CHAT',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension NavigatorExtension on BuildContext {
  void navigate(String route) {
    GoRouter.of(this).go(route);
  }
}
