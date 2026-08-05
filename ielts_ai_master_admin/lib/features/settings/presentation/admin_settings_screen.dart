import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/admin_theme.dart';
import '../../../core/widgets/admin_scaffold.dart';
import '../../auth/data/admin_auth_service.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'Unknown account';
    final displayName = (user?.displayName?.trim().isNotEmpty ?? false)
        ? user!.displayName!.trim()
        : 'Administrator';

    return AdminScaffold(
      title: 'Settings',
      subtitle: 'Manage your admin account and project configuration',
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
        children: [
          _ProfileHero(
            name: displayName,
            email: email,
            isVerified: user?.emailVerified ?? false,
          ),
          const SizedBox(height: 20),
          const _SectionHeader(
            title: 'Account',
            subtitle: 'Admin identity and access information',
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.email_outlined,
            iconColor: AdminColors.cyan,
            title: 'Signed-in account',
            subtitle: email,
            trailing: const _StatusPill(
              label: 'ACTIVE',
              color: AdminColors.success,
            ),
          ),
          const SizedBox(height: 10),
          _SettingsTile(
            icon: Icons.verified_user_outlined,
            iconColor: AdminColors.violet,
            title: 'Email verification',
            subtitle: user?.emailVerified == true
                ? 'Your administrator email is verified.'
                : 'Verify this email to improve account security.',
            trailing: _StatusPill(
              label: user?.emailVerified == true ? 'VERIFIED' : 'PENDING',
              color: user?.emailVerified == true
                  ? AdminColors.success
                  : AdminColors.warning,
            ),
          ),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Project',
            subtitle: 'Backend and environment configuration',
          ),
          const SizedBox(height: 10),
          const _SettingsTile(
            icon: Icons.cloud_done_outlined,
            iconColor: AdminColors.success,
            title: 'Firebase backend',
            subtitle:
                'The admin panel and user application should use the same Firebase project.',
            trailing: _StatusPill(
              label: 'CONNECTED',
              color: AdminColors.success,
            ),
          ),
          const SizedBox(height: 10),
          const _SettingsTile(
            icon: Icons.security_rounded,
            iconColor: AdminColors.warning,
            title: 'Security rules',
            subtitle:
                'Keep Firestore and Storage rules restricted to authorized admin accounts.',
          ),
          const SizedBox(height: 10),
          const _SettingsTile(
            icon: Icons.sync_rounded,
            iconColor: AdminColors.cyan,
            title: 'Realtime synchronization',
            subtitle:
                'Published content and generation jobs update automatically across the project.',
            trailing: _StatusPill(label: 'ENABLED', color: AdminColors.cyan),
          ),
          const SizedBox(height: 22),
          const _SectionHeader(
            title: 'Session',
            subtitle: 'Securely manage your current admin session',
          ),
          const SizedBox(height: 10),
          _LogoutCard(email: email, onLogout: () => _confirmLogout(context)),
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: const BorderSide(color: AdminColors.border),
          ),
          titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
          contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 6),
          actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          title: const Row(
            children: [
              _DialogIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Logout from admin panel?',
                  style: TextStyle(
                    color: AdminColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'You will need to sign in again to access admin controls and project data.',
            style: TextStyle(color: AdminColors.textMuted, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {
      await AdminAuthService().signOut();
    }
  }
}

class _ProfileHero extends StatelessWidget {
  final String name;
  final String email;
  final bool isVerified;

  const _ProfileHero({
    required this.name,
    required this.email,
    required this.isVerified,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.cyan.withOpacity(.16),
            AdminColors.violet.withOpacity(.12),
            AdminColors.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AdminColors.cyan.withOpacity(.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AdminColors.cyan, AdminColors.violet],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AdminColors.cyan.withOpacity(.25),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const _StatusPill(
                      label: 'ADMIN',
                      color: AdminColors.violet,
                    ),
                    _StatusPill(
                      label: isVerified ? 'VERIFIED' : 'UNVERIFIED',
                      color: isVerified
                          ? AdminColors.success
                          : AdminColors.warning,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AdminColors.text,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(color: AdminColors.textMuted, fontSize: 10.5),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AdminColors.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    if (trailing != null) ...[
                      const SizedBox(width: 10),
                      trailing!,
                    ],
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoutCard extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;

  const _LogoutCard({required this.email, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    const danger = Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: danger.withOpacity(.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: danger.withOpacity(.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.logout_rounded, color: danger, size: 22),
              SizedBox(width: 10),
              Text(
                'Logout from this device',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Currently signed in as $email. Logging out will securely end this admin session.',
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 10.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Logout Securely',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.24)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
          letterSpacing: .5,
        ),
      ),
    );
  }
}

class _DialogIcon extends StatelessWidget {
  const _DialogIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withOpacity(.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: const Icon(
        Icons.logout_rounded,
        color: Color(0xFFEF4444),
        size: 21,
      ),
    );
  }
}
