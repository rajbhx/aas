import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/edge_theme.dart';
import '../../../core/di/repository_providers.dart';
import '../../../data/datasources/hugging_face_service.dart';

class HFAccountScreen extends ConsumerStatefulWidget {
  const HFAccountScreen({super.key});

  @override
  ConsumerState<HFAccountScreen> createState() => _HFAccountScreenState();
}

class _HFAccountScreenState extends ConsumerState<HFAccountScreen> {
  late Future<HFProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ref.read(hfServiceProvider).fetchUserProfile();
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = ref.read(hfServiceProvider).fetchUserProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EdgeTheme.primaryBackground,
      appBar: AppBar(
        title: const Text('CLOUD ACCOUNT'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const FaIcon(FontAwesomeIcons.rotate, size: 16),
            onPressed: _refreshProfile,
            tooltip: 'Sync with Cloud Hub',
          ),
        ],
      ),
      body: FutureBuilder<HFProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: EdgeTheme.lavender));
          }

          if (snapshot.hasError) {
            return _buildErrorState(context, snapshot.error.toString());
          }

          if (!snapshot.hasData) {
             return _buildErrorState(context, 'No data received from Hub.');
          }

          final profile = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildProfileHeader(context, profile),
                const SizedBox(height: 32),
                _buildSectionTitle('INFERENCE STATUS'),
                const SizedBox(height: 16),
                _buildStatusCard(
                  title: 'Serverless Priority',
                  value: profile.isPro ? 'High Priority' : 'Standard',
                  icon: FontAwesomeIcons.bolt,
                  color: profile.isPro ? EdgeTheme.lavender : EdgeTheme.textSecondary,
                  description: profile.isPro 
                      ? 'You are on a Pro plan. Your Hub Inference requests are high-priority.'
                      : 'You are on the Free tier. Requests are standard priority and subject to dynamic rate limiting.',
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('ACCOUNT SAFETY'),
                const SizedBox(height: 16),
                _buildSecurityCard(),
                const SizedBox(height: 32),
                _buildActionButtons(context),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, HFProfile profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: EdgeTheme.lavender.withValues(alpha: 0.1),
            backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
            child: profile.avatarUrl == null 
                ? const FaIcon(FontAwesomeIcons.user, color: EdgeTheme.lavender, size: 30)
                : null,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullname ?? profile.username,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                Text(
                  '@${profile.username}',
                  style: const TextStyle(color: EdgeTheme.lavender, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: profile.isPro ? EdgeTheme.lavender.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: profile.isPro ? EdgeTheme.lavender : Colors.white10),
                  ),
                  child: Text(
                    profile.plan.toUpperCase(),
                    style: TextStyle(
                      color: profile.isPro ? EdgeTheme.lavender : EdgeTheme.textTertiary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: EdgeTheme.textTertiary,
        fontSize: 10,
        fontWeight: FontWeight.w800,
        letterSpacing: 2,
      ),
    );
  }

  Widget _buildStatusCard({
    required String title,
    required String value,
    required FaIconData icon,
    required Color color,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, color: color, size: 16),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(color: EdgeTheme.textTertiary, fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: EdgeTheme.surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Row(
        children: [
          FaIcon(FontAwesomeIcons.shieldHalved, color: EdgeTheme.successGreen, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hardware Enclave Protected',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your access token is stored securely in the device Keychain.',
                  style: TextStyle(color: EdgeTheme.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _buildActionButton(
          label: 'Manage Subscriptions',
          icon: FontAwesomeIcons.creditCard,
          onTap: () => _launchUrl('https://huggingface.co/settings/billing'),
        ),
        const SizedBox(height: 12),
        _buildActionButton(
          label: 'Sign Out',
          icon: FontAwesomeIcons.rightFromBracket,
          onTap: () async {
            final hfService = ref.read(hfServiceProvider);
            await hfService.deleteToken();
            ref.invalidate(hfProfileProvider);
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }

  Widget _buildActionButton({required String label, required FaIconData icon, required VoidCallback onTap}) {
    return ListTile(
      onTap: onTap,
      tileColor: EdgeTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      leading: FaIcon(icon, color: EdgeTheme.lavender, size: 18),
      title: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      trailing: const FaIcon(FontAwesomeIcons.chevronRight, color: Colors.white10, size: 14),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Widget _buildErrorState(BuildContext context, String error) {
    final isPermissionError = error.contains('Token Permission');
    
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FaIcon(
              isPermissionError ? FontAwesomeIcons.shieldHalved : FontAwesomeIcons.circleExclamation, 
              color: isPermissionError ? EdgeTheme.lavender : EdgeTheme.errorRed, 
              size: 40
            ),
            const SizedBox(height: 24),
            Text(
              isPermissionError ? 'Session Limit' : 'Profile Sync Error',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              error.replaceFirst('Exception: ', ''),
              textAlign: TextAlign.center,
              style: const TextStyle(color: EdgeTheme.textTertiary, fontSize: 13, height: 1.5),
            ),
            if (isPermissionError) ...[
              const SizedBox(height: 24),
              Container(
                 padding: const EdgeInsets.all(16),
                 decoration: BoxDecoration(
                   color: EdgeTheme.lavender.withValues(alpha: 0.05),
                   borderRadius: BorderRadius.circular(16),
                   border: Border.all(color: EdgeTheme.lavender.withValues(alpha: 0.1)),
                 ),
                 child: const Text(
                   'Tip: Use a token with "Read" or "Write" role. Fine-grained tokens must have the "whoami" permission.',
                   style: TextStyle(color: EdgeTheme.textSecondary, fontSize: 11, fontStyle: FontStyle.italic),
                   textAlign: TextAlign.center,
                 ),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _refreshProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: EdgeTheme.lavender,
                foregroundColor: Colors.black,
                minimumSize: const Size(200, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const FaIcon(FontAwesomeIcons.rotate, size: 14),
              label: const Text('SYNC AGAIN', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
            const SizedBox(height: 12),
             TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Back to Settings', style: TextStyle(color: EdgeTheme.textTertiary)),
            ),
          ],
        ),
      ),
    );
  }
}
