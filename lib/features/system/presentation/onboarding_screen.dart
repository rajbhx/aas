import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/edge_theme.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  bool _isRequestingPermissions = false;

  final List<OnboardingData> _pages = [
    const OnboardingData(
      title: 'Welcome to BRAINY.AI',
      description: 'The world\'s most powerful offline AI companion. Your intelligence, strictly on-device.',
      icon: FontAwesomeIcons.robot,
      color: EdgeTheme.lavender,
    ),
    const OnboardingData(
      title: '100% Private & Secure',
      description: 'Your messages never leave your device. No cloud, no tracking, just pure privacy.',
      icon: FontAwesomeIcons.shieldHalved,
      color: EdgeTheme.successGreen,
    ),
    const OnboardingData(
      title: 'Edge Intelligence',
      description: 'High-performance LLMs running locally. Experience the future of edge computing.',
      icon: FontAwesomeIcons.boltLightning,
      color: Colors.orangeAccent,
    ),
    const OnboardingData(
      title: 'Permissions Required',
      description: 'We need access to your microphone for voice input, storage for model files, and notifications for system monitoring. All data stays on your device.',
      icon: FontAwesomeIcons.lock,
      color: Colors.cyanAccent,
    ),
  ];

  /// Request all required permissions for the app
  Future<void> _requestPermissions() async {
    try {
      // Request microphone permission for voice input
      await Permission.microphone.request();

      // Request storage permission for model files (Android 12 and below)
      if (await Permission.storage.isLimited) {
        await Permission.storage.request();
      }

      // Request notifications permission for Android 13+
      if (await Permission.notification.isDenied) {
        await Permission.notification.request();
      }

      // Request location permission if needed for device info (optional)
      // await Permission.location.request();
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
  }

  Future<void> _completeOnboarding() async {
    // Request permissions before completing onboarding
    if (!_isRequestingPermissions) {
      setState(() => _isRequestingPermissions = true);
      await _requestPermissions();
      setState(() => _isRequestingPermissions = false);
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemCount: _pages.length,
            itemBuilder: (context, index) {
              final page = _pages[index];
              return _buildPage(page);
            },
          ),
          
          // Navigation Bottom
          Positioned(
            bottom: 60,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentIndex == index ? 24 : 8,
                      decoration: BoxDecoration(
                        color: _currentIndex == index ? EdgeTheme.lavender : Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                GestureDetector(
                  onTap: _isRequestingPermissions
                      ? null
                      : () {
                          if (_currentIndex < _pages.length - 1) {
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                            );
                          } else {
                            _completeOnboarding();
                          }
                        },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      gradient: EdgeTheme.brainyGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: EdgeTheme.purpleGlow(EdgeTheme.lavender),
                    ),
                    child: Center(
                      child: _isRequestingPermissions
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              _currentIndex == _pages.length - 1
                                  ? 'GET STARTED'
                                  : 'CONTINUE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
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

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: data.color.withValues(alpha: 0.2)),
            ),
            child: FaIcon(data.icon, size: 80, color: data.color),
          ),
          const SizedBox(height: 60),
          Text(
            data.title.toUpperCase(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            data.description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: EdgeTheme.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String description;
  final FaIconData icon;
  final Color color;

  const OnboardingData({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
