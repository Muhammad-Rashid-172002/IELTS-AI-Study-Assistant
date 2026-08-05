import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fyproject/Language_selection_screen/language_selection_screen.dart';
import 'package:fyproject/screens/help_and%20_Support/help_and_support.dart';
import 'package:fyproject/screens/pages/Subscription/Subscription_screen.dart';
import 'package:fyproject/screens/pages/about_app/about_app.dart';
import 'package:fyproject/screens/pages/certificate/certificate_screen.dart';
import 'package:fyproject/screens/pages/registration/registration.dart';
import 'package:url_launcher/url_launcher.dart';
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      },
                    ),

                    ProfileTile(
                      icon: Icons.verified_outlined,
                      title: 'Certificates',
                      subtitle: '${profile.certificates} certificates',
                      color: ProfileColors.green,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CertificatesScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ProfileSection(
                  title: 'Preferences',
                  children: [
                    ProfileTile(
                      icon: Icons.language_rounded,
                      title: 'App Language',
                      subtitle: 'Change your preferred language',
                      color: Colors.blue,
                      onTap: () async {
                        final selectedLanguage =
                            await Navigator.push<AppLanguage>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LanguageSelectionScreen(
                                  fromSettings: true,
                                ),
                              ),
                            );

                        if (selectedLanguage == null || !mounted) return;

                        setState(() {
                          // selectedLanguage.code
                          // selectedLanguage.name
                          // selectedLanguage.nativeName
                        });

                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              behavior: SnackBarBehavior.floating,
                              elevation: 0,
                              backgroundColor: Colors.transparent,
                              margin: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                              duration: const Duration(seconds: 2),
                              content: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(18),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF2563EB),
                                      Color(0xFF06B6D4),
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF2563EB,
                                      ).withOpacity(0.30),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(.18),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.check_circle_rounded,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Language Updated',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            '${selectedLanguage.nativeName} is now your app language.',
                                            style: TextStyle(
                                              color: Colors.white.withOpacity(
                                                .9,
                                              ),
                                              fontSize: 12.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                      },
                    ),
                    ProfileTile(
                      icon: Icons.notifications_outlined,
                      title: 'Notification Settings',
                      subtitle: profile.notificationsEnabled
                          ? 'Enabled'
                          : 'Disabled',
                      color: ProfileColors.orange,
                      onTap: () => _showNotificationSettings(),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ProfileSection(
                  title: 'Privacy & Data',
                  children: [
                    ProfileTile(
                      icon: Icons.privacy_tip_outlined,
                      title: 'Privacy Policy',
                      subtitle: 'Review how your data is handled',
                      color: ProfileColors.cyan,
                      onTap: _openPrivacyPolicy,
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const HelpAndSupportScreen(),
                        ),
                      ),
                    ),
                    ProfileTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About App',
                      subtitle: 'IELTS AI Master • Version 1.1.2+7',
                      color: ProfileColors.violet,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AboutAppScreen(),
                        ),
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

  Future<void> _openPrivacyPolicy() async {
    final Uri url = Uri.parse('https://ielts-ai-privacy.vercel.app/');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open Privacy Policy.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showNotificationSettings() {
    bool enabled = true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Color(0xFF101C2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFF59E0B), Color(0xFFFFC107)],
                        ),
                      ),
                      child: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Notifications',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Receive reminders, AI updates and important announcements.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, height: 1.5),
                    ),
                    const SizedBox(height: 26),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF18253A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.notifications_rounded,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Push Notifications',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  enabled
                                      ? 'Notifications are currently enabled.'
                                      : 'Notifications are currently disabled.',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: enabled,
                            activeThumbColor: Colors.white,
                            activeTrackColor: const Color(0xFF22C55E),
                            inactiveThumbColor: const Color(0xFF94A3B8),
                            inactiveTrackColor: const Color(0xFF334155),
                            onChanged: (value) {
                              setSheetState(() {
                                enabled = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(sheetContext);

                          ScaffoldMessenger.of(this.context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                behavior: SnackBarBehavior.floating,
                                elevation: 0,
                                backgroundColor: Colors.transparent,
                                margin: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  24,
                                ),
                                content: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    gradient: LinearGradient(
                                      colors: enabled
                                          ? const [
                                              Color(0xFF16A34A),
                                              Color(0xFF22C55E),
                                            ]
                                          : const [
                                              Color(0xFFDC2626),
                                              Color(0xFFEF4444),
                                            ],
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        enabled
                                            ? Icons.notifications_active_rounded
                                            : Icons.notifications_off_rounded,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        enabled
                                            ? 'Notifications Enabled'
                                            : 'Notifications Disabled',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(17),
                          ),
                        ),
                        child: const Text(
                          'Save Preference',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static String _date(DateTime? date) {
    if (date == null) return 'Not set';
    return '${date.day}/${date.month}/${date.year}';
  }
}
