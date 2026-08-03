import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyproject/screens/pages/registration/registration.dart';
import '../data/profile_repository.dart';
import '../models/profile_model.dart';
import '../widgets/profile_widgets.dart';
import 'edit_profile_screen.dart';
import 'profile_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repository = ProfileRepository();

  void _message(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _export() async {
    try {
      final json = await _repository.exportJson();
      await Clipboard.setData(ClipboardData(text: json));
      if (mounted) _message('Your JSON data export was copied.');
    } catch (error) {
      if (mounted) _message('Data export failed: $error');
    }
  }

  Future<void> _logout() async {
    final confirmed = await _confirm(
      'Logout?',
      'Your progress will remain synced with your account.',
      'Logout',
    );
    if (!confirmed) return;
    try {
       await _repository.signOut();
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const RegistrationScreen()),
      );
    } catch (error) {
      if (mounted) _message('Logout failed: $error');
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await _confirm(
      'Delete account permanently?',
      'Your profile, results and saved content will be deleted. This cannot be undone.',
      'Delete',
      danger: true,
    );
    if (!confirmed) return;

    try {
      await _repository.deleteAccount();
    } catch (error) {
      if (mounted) _message('Account deletion failed: $error');
    }
  }

  Future<bool> _confirm(
    String title,
    String message,
    String action, {
    bool danger = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: ProfileColors.surface,
            title: Text(
              title,
              style: const TextStyle(color: ProfileColors.text),
            ),
            content: Text(
              message,
              style: const TextStyle(
                color: ProfileColors.secondary,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: danger
                    ? FilledButton.styleFrom(backgroundColor: ProfileColors.red)
                    : null,
                onPressed: () => Navigator.pop(context, true),
                child: Text(action),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileColors.background,
      body: SafeArea(
        child: StreamBuilder<ProfileModel>(
          stream: _repository.watchProfile(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  snapshot.error.toString(),
                  style: const TextStyle(color: ProfileColors.red),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final profile = snapshot.data!;

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
              children: [
                const Text(
                  'Profile',
                  style: TextStyle(
                    color: ProfileColors.text,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Account, learning and privacy settings',
                  style: TextStyle(color: ProfileColors.muted, fontSize: 10.5),
                ),
                const SizedBox(height: 14),
                ProfileHeader(
                  profile: profile,
                  onEdit: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => EditProfileScreen(profile: profile),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ProfileSection(
                  title: 'IELTS Profile',
                  children: [
                    ProfileTile(
                      icon: Icons.school_outlined,
                      title: 'IELTS Type',
                      subtitle: profile.ieltsType,
                      color: ProfileColors.cyan,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(profile: profile),
                        ),
                      ),
                    ),
                    ProfileTile(
                      icon: Icons.flag_outlined,
                      title: 'Target Band',
                      subtitle: profile.targetBand.toStringAsFixed(1),
                      color: ProfileColors.orange,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(profile: profile),
                        ),
                      ),
                    ),
                    ProfileTile(
                      icon: Icons.calendar_month_outlined,
                      title: 'Exam Date',
                      subtitle: _date(profile.examDate),
                      color: ProfileColors.violet,
                    ),
                    ProfileTile(
                      icon: Icons.workspace_premium_outlined,
                      title: 'Education Level',
                      subtitle: profile.educationLevel,
                      color: ProfileColors.blue,
                    ),
                    ProfileTile(
                      icon: Icons.insights_rounded,
                      title: 'Current Estimated Band',
                      subtitle: profile.estimatedBand.toStringAsFixed(1),
                      color: ProfileColors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ProfileSection(
                  title: 'Learning & Subscription',
                  children: [
                    ProfileTile(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Subscription',
                      subtitle: profile.isPremium
                          ? '${profile.subscription} • ${_date(profile.subscriptionExpiry)}'
                          : 'Free plan',
                      color: ProfileColors.orange,
                      onTap: () => _message(
                        'Connect this tile with your subscription screen.',
                      ),
                    ),
                    ProfileTile(
                      icon: Icons.bookmark_outline_rounded,
                      title: 'Saved Tests',
                      subtitle: '${profile.savedTests} saved tests',
                      color: ProfileColors.cyan,
                      onTap: () =>
                          _message('Connect this tile with Saved Tests.'),
                    ),
                    ProfileTile(
                      icon: Icons.translate_rounded,
                      title: 'Saved Words',
                      subtitle: '${profile.savedWords} saved words',
                      color: ProfileColors.blue,
                      onTap: () =>
                          _message('Connect this tile with Saved Words.'),
                    ),
                    ProfileTile(
                      icon: Icons.verified_outlined,
                      title: 'Certificates',
                      subtitle: '${profile.certificates} certificates',
                      color: ProfileColors.green,
                      onTap: () =>
                          _message('Connect this tile with Certificates.'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ProfileSection(
                  title: 'Preferences',
                  children: [
                    ProfileTile(
                      icon: Icons.language_rounded,
                      title: 'Language',
                      subtitle: profile.language,
                      color: ProfileColors.cyan,
                      onTap: () =>
                          _message('Connect this with your language selector.'),
                    ),
                    ProfileTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notification Settings',
                      subtitle: profile.notificationsEnabled
                          ? 'Enabled'
                          : 'Disabled',
                      color: ProfileColors.orange,
                      onTap: () =>
                          _message('Connect this with notification settings.'),
                    ),
                    ProfileTile(
                      icon: Icons.palette_outlined,
                      title: 'Appearance',
                      subtitle: profile.appearance,
                      color: ProfileColors.violet,
                      onTap: () =>
                          _message('Connect this with your theme controller.'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ProfileSection(
                  title: 'Privacy & Data',
                  children: [
                    ProfileTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy',
                      subtitle: 'Manage privacy and permissions',
                      color: ProfileColors.cyan,
                      onTap: () =>
                          _message('Connect this with your privacy screen.'),
                    ),
                    ProfileTile(
                      icon: Icons.download_for_offline_outlined,
                      title: 'Data Export',
                      subtitle: 'Copy your complete JSON data export',
                      color: ProfileColors.blue,
                      onTap: _export,
                    ),
                    ProfileTile(
                      icon: Icons.lock_reset_rounded,
                      title: 'Change Password',
                      subtitle: 'Send a password reset email',
                      color: ProfileColors.orange,
                      onTap: () async {
                        try {
                          await _repository.sendPasswordReset();
                          if (mounted) {
                            _message('Password reset email sent.');
                          }
                        } catch (error) {
                          if (mounted) {
                            _message('Password reset failed: $error');
                          }
                        }
                      },
                    ),
                    ProfileTile(
                      icon: Icons.delete_forever_outlined,
                      title: 'Delete Account',
                      subtitle: 'Permanently delete account and data',
                      color: ProfileColors.red,
                      onTap: _deleteAccount,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ProfileSection(
                  title: 'Support',
                  children: [
                    ProfileTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & Support',
                      subtitle: 'FAQs, contact support and report a bug',
                      color: ProfileColors.cyan,
                      onTap: () =>
                          _message('Connect this with Help & Support.'),
                    ),
                    ProfileTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About App',
                      subtitle: 'IELTS AI Master • Version 1.0.0',
                      color: ProfileColors.violet,
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'IELTS AI Master',
                        applicationVersion: '1.0.0',
                        applicationLegalese:
                            'AI-powered IELTS learning and practice.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: ProfileColors.red,
                    side: const BorderSide(color: ProfileColors.red),
                    minimumSize: const Size.fromHeight(52),
                  ),
                  onPressed: _logout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static String _date(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }
}
