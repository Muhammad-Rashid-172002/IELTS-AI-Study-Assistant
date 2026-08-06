import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fyproject/screens/pages/registration/Auth_gateway_screen.dart';
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
    if (FirebaseAuth.instance.currentUser == null) {
      return const _ProfileSignedOutState();
    }

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

            final completedSkillEntries = profile.skillBands.entries
                .where((entry) => entry.value > 0 && entry.value <= 9)
                .toList();

            final missingSkills = profile.skillBands.entries
                .where((entry) => entry.value <= 0 || entry.value > 9)
                .map((entry) => entry.key)
                .toList();

            final hasAnyBand = completedSkillEntries.isNotEmpty;
            final hasCompleteOverallBand = completedSkillEntries.length == 4;

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
                const SizedBox(height: 16),
                _ProfileBandStatusCard(
                  estimatedBand: profile.estimatedBand,
                  targetBand: profile.targetBand,
                  completedSkillCount: completedSkillEntries.length,
                  missingSkills: missingSkills,
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
                      title: hasCompleteOverallBand
                          ? 'Estimated Overall Band'
                          : 'Provisional Band',
                      subtitle: hasAnyBand
                          ? profile.estimatedBand.toStringAsFixed(1)
                          : 'Not available',
                      color: hasCompleteOverallBand
                          ? ProfileColors.green
                          : ProfileColors.cyan,
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

class _ProfileBandStatusCard extends StatelessWidget {
  final double estimatedBand;
  final double targetBand;
  final int completedSkillCount;
  final List<String> missingSkills;

  const _ProfileBandStatusCard({
    required this.estimatedBand,
    required this.targetBand,
    required this.completedSkillCount,
    required this.missingSkills,
  });

  @override
  Widget build(BuildContext context) {
    final hasAnyResult = completedSkillCount > 0;
    final isComplete = completedSkillCount == 4;
    final bandGap = hasAnyResult
        ? (targetBand - estimatedBand).clamp(0.0, 9.0)
        : targetBand;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ProfileColors.blue.withOpacity(.22),
            ProfileColors.cyan.withOpacity(.10),
            ProfileColors.violet.withOpacity(.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: ProfileColors.cyan.withOpacity(.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.16),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isComplete ? 'ESTIMATED OVERALL BAND' : 'PROVISIONAL BAND',
                  style: const TextStyle(
                    color: ProfileColors.cyan,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .7,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color:
                      (isComplete ? ProfileColors.green : ProfileColors.violet)
                          .withOpacity(.12),
                  borderRadius: BorderRadius.circular(99),
                  border: Border.all(
                    color:
                        (isComplete
                                ? ProfileColors.green
                                : ProfileColors.violet)
                            .withOpacity(.28),
                  ),
                ),
                child: Text(
                  isComplete
                      ? '4 OF 4 COMPLETE'
                      : '$completedSkillCount OF 4 COMPLETE',
                  style: TextStyle(
                    color: isComplete
                        ? ProfileColors.green
                        : ProfileColors.violet,
                    fontSize: 7.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                hasAnyResult ? estimatedBand.toStringAsFixed(1) : '—',
                style: const TextStyle(
                  color: ProfileColors.text,
                  fontSize: 42,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 10),
              Container(
                margin: const EdgeInsets.only(bottom: 3),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: ProfileColors.orange.withOpacity(.11),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  'Target ${targetBand.toStringAsFixed(1)}',
                  style: const TextStyle(
                    color: ProfileColors.orange,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            !hasAnyResult
                ? 'Complete your first IELTS assessment to generate a '
                      'provisional band.'
                : isComplete
                ? bandGap <= 0
                      ? 'You have reached your selected target band.'
                      : '${bandGap.toStringAsFixed(1)} band gap remaining.'
                : 'This estimate uses your completed skills only. '
                      'Complete ${missingSkills.join(' and ')} to unlock '
                      'your full estimated overall band.',
            style: const TextStyle(
              color: ProfileColors.secondary,
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
          if (!isComplete) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: ProfileColors.background.withOpacity(.50),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: ProfileColors.orange.withOpacity(.24),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.assignment_late_outlined,
                    color: ProfileColors.orange,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          missingSkills.isEmpty
                              ? 'Complete all skill assessments'
                              : 'Missing: ${missingSkills.join(', ')}',
                          style: const TextStyle(
                            color: ProfileColors.text,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Listening, Reading, Writing and Speaking are all '
                          'required for a complete IELTS overall estimate.',
                          style: TextStyle(
                            color: ProfileColors.muted,
                            fontSize: 9,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
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

class _ProfileSignedOutState extends StatelessWidget {
  const _ProfileSignedOutState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ProfileColors.background,
      body: Stack(
        children: [
          Positioned(
            top: -130,
            right: -120,
            child: Container(
              width: 310,
              height: 310,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ProfileColors.blue.withOpacity(.24),
                    ProfileColors.blue.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -150,
            left: -140,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    ProfileColors.violet.withOpacity(.18),
                    ProfileColors.violet.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 430),
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ProfileColors.surface.withOpacity(.98),
                        ProfileColors.blue.withOpacity(.10),
                        ProfileColors.violet.withOpacity(.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: ProfileColors.cyan.withOpacity(.20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.28),
                        blurRadius: 34,
                        offset: const Offset(0, 18),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              ProfileColors.cyan,
                              ProfileColors.blue,
                              ProfileColors.violet,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: ProfileColors.cyan.withOpacity(.25),
                              blurRadius: 28,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 45,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Please Login',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProfileColors.text,
                          fontSize: 27,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.6,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        'Sign in to access your IELTS profile, skill bands, '
                        'certificates, preferences and account settings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: ProfileColors.secondary,
                          fontSize: 12,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 21),
                      const _ProfileLoginBenefit(
                        icon: Icons.insights_rounded,
                        text: 'Track provisional and overall bands',
                      ),
                      const SizedBox(height: 9),
                      const _ProfileLoginBenefit(
                        icon: Icons.workspace_premium_outlined,
                        text: 'Access certificates and achievements',
                      ),
                      const SizedBox(height: 9),
                      const _ProfileLoginBenefit(
                        icon: Icons.cloud_done_outlined,
                        text: 'Keep your progress securely synced',
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                ProfileColors.blue,
                                ProfileColors.cyan,
                                ProfileColors.violet,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: ProfileColors.blue.withOpacity(.30),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AuthenticationGatewayScreen(
                                        initialMode: AuthMode.signIn,
                                      ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.login_rounded),
                            label: const Text(
                              'Login to Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLoginBenefit extends StatelessWidget {
  final IconData icon;
  final String text;

  const _ProfileLoginBenefit({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: ProfileColors.background.withOpacity(.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ProfileColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: ProfileColors.cyan, size: 19),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: ProfileColors.secondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const Icon(
            Icons.check_circle_rounded,
            color: ProfileColors.green,
            size: 17,
          ),
        ],
      ),
    );
  }
}
