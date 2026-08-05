import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/admin_theme.dart';
import '../data/admin_auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _service = AdminAuthService();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _loading = true);

    try {
      await _service.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(18),
            backgroundColor: const Color(0xFF7F1D1D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Login failed: $error',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, size: 21),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AdminColors.background.withOpacity(.72),
      labelStyle: const TextStyle(
        color: AdminColors.textMuted,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: AdminColors.textMuted.withOpacity(.72),
        fontSize: 13,
      ),
      prefixIconColor: AdminColors.cyan,
      suffixIconColor: AdminColors.textMuted,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: AdminColors.cyan, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LoginBackground()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final height = constraints.maxHeight;

                final isDesktop = width >= 1050;
                final isTablet = width >= 650 && width < 1050;
                final horizontalPadding = isDesktop
                    ? 36.0
                    : isTablet
                    ? 28.0
                    : 18.0;

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 22,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: height - 44),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1160),
                        child: isDesktop
                            ? IntrinsicHeight(
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    const Expanded(
                                      flex: 11,
                                      child: _BrandPanel(),
                                    ),
                                    const SizedBox(width: 30),
                                    Expanded(
                                      flex: 9,
                                      child: Align(
                                        alignment: Alignment.center,
                                        child: _LoginCard(
                                          formKey: _formKey,
                                          emailController: _emailController,
                                          passwordController:
                                              _passwordController,
                                          loading: _loading,
                                          obscure: _obscure,
                                          onToggleObscure: () {
                                            setState(
                                              () => _obscure = !_obscure,
                                            );
                                          },
                                          onLogin: _login,
                                          inputDecoration: _inputDecoration,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxWidth: isTablet ? 640 : 470,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _MobileBrandHeader(tablet: isTablet),
                                    SizedBox(height: isTablet ? 26 : 20),
                                    _LoginCard(
                                      formKey: _formKey,
                                      emailController: _emailController,
                                      passwordController: _passwordController,
                                      loading: _loading,
                                      obscure: _obscure,
                                      onToggleObscure: () {
                                        setState(() => _obscure = !_obscure);
                                      },
                                      onLogin: _login,
                                      inputDecoration: _inputDecoration,
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool loading;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final InputDecoration Function({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  })
  inputDecoration;

  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.loading,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 380;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 470),
      padding: EdgeInsets.all(compact ? 20 : 28),
      decoration: BoxDecoration(
        color: AdminColors.surface.withOpacity(.96),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AdminColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.22),
            blurRadius: 42,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: AdminColors.cyan.withOpacity(.05),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: AutofillGroup(
        child: Form(
          key: formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient: AdminColors.gradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AdminColors.cyan.withOpacity(.24),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: Colors.white,
                      size: 27,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AdminColors.cyan.withOpacity(.10),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: AdminColors.cyan.withOpacity(.22),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.lock_rounded,
                          color: AdminColors.cyan,
                          size: 14,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'SECURE ACCESS',
                          style: TextStyle(
                            color: AdminColors.cyan,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: .6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),
              const Text(
                'Welcome back',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 29,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Sign in to manage IELTS content, users and AI generation workflows.',
                style: TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 13,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 28),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [
                  AutofillHints.username,
                  AutofillHints.email,
                ],
                style: const TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w600,
                ),
                decoration: inputDecoration(
                  label: 'Admin email',
                  hint: 'admin@example.com',
                  icon: Icons.alternate_email_rounded,
                ),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  final isValid = RegExp(
                    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                  ).hasMatch(email);

                  if (!isValid) {
                    return 'Please enter a valid email address';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: passwordController,
                obscureText: obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                enableSuggestions: false,
                autocorrect: false,
                onFieldSubmitted: (_) {
                  if (!loading) onLogin();
                },
                style: const TextStyle(
                  color: AdminColors.text,
                  fontWeight: FontWeight.w600,
                ),
                decoration: inputDecoration(
                  label: 'Password',
                  hint: 'Enter your secure password',
                  icon: Icons.lock_outline_rounded,
                  suffixIcon: IconButton(
                    tooltip: obscure ? 'Show password' : 'Hide password',
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.length < 6) {
                    return 'Password must be at least 6 characters long';
                  }

                  return null;
                },
              ),
              const SizedBox(height: 13),
              const Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: AdminColors.textMuted,
                    size: 15,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Only authorised administrators can access this dashboard.',
                      style: TextStyle(
                        color: AdminColors.textMuted,
                        fontSize: 10.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: loading ? null : onLogin,
                  style: FilledButton.styleFrom(
                    backgroundColor: AdminColors.cyan,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AdminColors.cyan.withOpacity(.38),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    elevation: 0,
                  ),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: loading
                        ? const Row(
                            key: ValueKey('loading'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 11),
                              Text(
                                'Signing in...',
                                style: TextStyle(fontWeight: FontWeight.w800),
                              ),
                            ],
                          )
                        : const Row(
                            key: ValueKey('button'),
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.login_rounded, size: 20),
                              SizedBox(width: 9),
                              Text(
                                'Sign In to Admin Panel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: .1,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Divider(color: AdminColors.border.withOpacity(.8)),
              const SizedBox(height: 13),
              const Center(
                child: Text(
                  'IELTS AI Master • Administration Portal',
                  style: TextStyle(
                    color: AdminColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 610),
      padding: const EdgeInsets.all(42),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AdminColors.surface.withOpacity(.94),
            AdminColors.background.withOpacity(.86),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              gradient: AdminColors.gradient,
              borderRadius: BorderRadius.circular(23),
              boxShadow: [
                BoxShadow(
                  color: AdminColors.cyan.withOpacity(.24),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 30),
          const Text(
            'IELTS AI Master\nAdmin Portal',
            style: TextStyle(
              color: AdminColors.text,
              fontSize: 39,
              height: 1.08,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'A secure command centre for managing learning content, AI generation jobs and platform operations.',
            style: TextStyle(
              color: AdminColors.textMuted,
              fontSize: 14,
              height: 1.65,
            ),
          ),
          const SizedBox(height: 34),
          const _FeatureTile(
            icon: Icons.auto_awesome_motion_rounded,
            title: 'AI Content Operations',
            subtitle: 'Monitor generation queues and publish IELTS material.',
          ),
          const SizedBox(height: 14),
          const _FeatureTile(
            icon: Icons.analytics_outlined,
            title: 'Performance Oversight',
            subtitle: 'Review usage, progress and learning activity.',
          ),
          const SizedBox(height: 14),
          const _FeatureTile(
            icon: Icons.shield_outlined,
            title: 'Secure Administration',
            subtitle: 'Controlled access through IELTS authentication.',
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: AdminColors.cyan.withOpacity(.07),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AdminColors.cyan.withOpacity(.16)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.cloud_done_outlined,
                  color: AdminColors.cyan,
                  size: 20,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Enterprise-grade secure administration environment',
                    style: TextStyle(
                      color: AdminColors.text,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
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
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AdminColors.cyan.withOpacity(.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AdminColors.cyan.withOpacity(.16)),
          ),
          child: Icon(icon, color: AdminColors.cyan, size: 21),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AdminColors.textMuted,
                  fontSize: 11,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MobileBrandHeader extends StatelessWidget {
  final bool tablet;

  const _MobileBrandHeader({this.tablet = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: tablet ? 78 : 66,
          height: tablet ? 78 : 66,
          decoration: BoxDecoration(
            gradient: AdminColors.gradient,
            borderRadius: BorderRadius.circular(21),
            boxShadow: [
              BoxShadow(
                color: AdminColors.cyan.withOpacity(.25),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.auto_awesome_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'IELTS AI Master',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AdminColors.text,
            fontSize: tablet ? 28 : 23,
            fontWeight: FontWeight.w900,
            letterSpacing: -.4,
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'Administration Portal',
          style: TextStyle(
            color: AdminColors.cyan,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
      ],
    );
  }
}

class _LoginBackground extends StatelessWidget {
  const _LoginBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: AdminColors.background),
        Positioned(
          top: -160,
          right: -100,
          child: _GlowCircle(
            size: 410,
            color: AdminColors.cyan.withOpacity(.10),
          ),
        ),
        Positioned(
          bottom: -190,
          left: -130,
          child: _GlowCircle(
            size: 440,
            color: AdminColors.violet.withOpacity(.09),
          ),
        ),
        Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GridPainter())),
        ),
      ],
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AdminColors.border.withOpacity(.12)
      ..strokeWidth = .7;

    const step = 42.0;

    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
