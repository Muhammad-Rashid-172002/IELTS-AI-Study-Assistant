import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  Color get primary => const Color(0xFF2DD4BF);
  Color get secondary => const Color(0xFF0F766E);
  Color get bg => const Color(0xFF08111F);

  Future<void> _sendEmail(BuildContext context) async {
    final Uri uri = Uri(
      scheme: 'mailto',
      path: 'muhammadrashid172002@gmail.com',
     queryParameters: {
  'subject': 'IELTS AI App Support',
  'body': '''
Hello Support Team,

Thank you for using IELTS AI.

Please describe your issue or question below. Our team will review your request and respond as soon as possible.

Issue Details:
--------------------------------------------------

--------------------------------------------------

Device Information:
• Device Model:
• Android/iOS Version:
• App Version:

Thank you for helping us improve IELTS AI.

Best regards,
IELTS AI Support Team
''',
},
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      showCustomSnackBar(
        context: context,
        title: "Email App Missing",
        message: "No email application was found on your device.",
        isError: true,
      );
    }
  }

  void showCustomSnackBar({
    required BuildContext context,
    required String title,
    required String message,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(18),

        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),

          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isError
                  ? [const Color(0xFFEF4444), const Color(0xFFB91C1C)]
                  : [
                      const Color(0xFF2DD4BF),
                      const Color(0xFF14B8A6),
                      const Color(0xFF0F766E),
                    ],

              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),

            borderRadius: BorderRadius.circular(24),

            boxShadow: [
              BoxShadow(
                color: isError
                    ? Colors.red.withOpacity(0.28)
                    : const Color(0xFF14B8A6).withOpacity(0.28),

                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),

          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),

                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  shape: BoxShape.circle,
                ),

                child: Icon(
                  isError
                      ? Icons.error_outline_rounded
                      : Icons.check_circle_rounded,

                  color: Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,

                  children: [
                    Text(
                      title,

                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      message,

                      style: TextStyle(
                        color: Colors.white.withOpacity(0.82),
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 270,
            pinned: true,
            elevation: 0,
            backgroundColor: bg,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              color: Colors.white,
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [bg, const Color(0xFF102A43), secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(34),
                    bottomRight: Radius.circular(34),
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 52, 24, 22),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 74,
                          width: 74,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, secondary],
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.35),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.support_agent_rounded,
                            color: Colors.white,
                            size: 38,
                          ),
                        ),

                        const SizedBox(height: 16),

                        const Text(
                          "Help & Support",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          "Report any error, bug, login issue, AI problem, or payment issue.",
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.72),
                            fontSize: 14,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _supportCard(
                    icon: Icons.email_rounded,
                    title: "Email Support",
                    subtitle: "muhammadrashid172002@gmail.com",
                    onTap: () => _sendEmail(context),
                  ),

                  const SizedBox(height: 16),

                  _supportCard(
                    icon: Icons.bug_report_rounded,
                    title: "Report Any Error",
                    subtitle:
                        "Tell us about app crashes, bugs, AI errors, login issues, or wrong results.",
                    onTap: () => _sendEmail(context),
                  ),

                  const SizedBox(height: 16),

                  _supportCard(
                    icon: Icons.psychology_rounded,
                    title: "AI Result Issue",
                    subtitle:
                        "Report wrong band scores, missing feedback, or AI response problems.",
                    onTap: () => _sendEmail(context),
                  ),

                  const SizedBox(height: 16),

                  _supportCard(
                    icon: Icons.lock_outline_rounded,
                    title: "Account Help",
                    subtitle:
                        "Need help with login, profile update, or account access?",
                    onTap: () => _sendEmail(context),
                  ),

                  const SizedBox(height: 24),

                  _infoBox(),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
// support card widget
  Widget _supportCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.10),
            Colors.white.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, secondary]),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
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
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.40),
                  size: 17,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primary.withOpacity(0.16), Colors.white.withOpacity(0.05)],
        ),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: primary.withOpacity(0.18)),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_awesome_rounded, color: primary, size: 36),
          const SizedBox(height: 14),
          const Text(
            "IELTS AI Support",
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "For any app issue, AI issue, crash, login problem, or feedback, contact us through email support.",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
