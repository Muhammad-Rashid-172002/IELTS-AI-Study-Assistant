import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fyproject/screens/Onboarding_Screen/Onboarding_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key, this.fromSettings = false});

  final bool fromSettings;

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  late final AnimationController _entranceController;
  late final AnimationController _ambientController;

  String _query = '';
  String _selectedCode = 'en';
  bool _loading = false;

  final List<AppLanguage> _languages = const [
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      symbol: 'EN',
      description: 'Recommended for IELTS preparation',
      accent: Color(0xFF38BDF8),
    ),
    AppLanguage(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      symbol: 'ا',
      description: 'ایپ کی ہدایات اردو میں',
      accent: Color(0xFF34D399),
    ),
    AppLanguage(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      symbol: 'ع',
      description: 'إرشادات التطبيق باللغة العربية',
      accent: Color(0xFFF59E0B),
    ),
    AppLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      symbol: 'हि',
      description: 'ऐप निर्देश हिंदी में',
      accent: Color(0xFFF472B6),
    ),
    AppLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      symbol: 'ES',
      description: 'Instrucciones de la aplicación',
      accent: Color(0xFFA78BFA),
    ),
    AppLanguage(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      symbol: '中',
      description: '应用程序说明',
      accent: Color(0xFFFB7185),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 850),
    )..forward();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entranceController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  AppLanguage get _selectedLanguage {
    return _languages.firstWhere((language) => language.code == _selectedCode);
  }

  List<AppLanguage> get _filteredLanguages {
    final query = _query.trim().toLowerCase();

    if (query.isEmpty) return _languages;

    return _languages.where((language) {
      return language.name.toLowerCase().contains(query) ||
          language.nativeName.toLowerCase().contains(query) ||
          language.description.toLowerCase().contains(query);
    }).toList();
  }

  void _selectLanguage(AppLanguage language) {
    FocusScope.of(context).unfocus();
    setState(() => _selectedCode = language.code);
  }

  Future<void> _continue() async {
    if (_loading) return;

    setState(() => _loading = true);

    await Future<void>.delayed(const Duration(milliseconds: 220));

    if (!mounted) return;

    if (widget.fromSettings) {
      Navigator.of(context).pop<AppLanguage>(_selectedLanguage);
      return;
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 520),
        pageBuilder: (_, animation, secondaryAnimation) {
          return PremiumOnboardingScreen();
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languages = _filteredLanguages;

    return Scaffold(
      backgroundColor: LanguageColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LanguageBackground()),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _ambientController,
              builder: (_, __) {
                return CustomPaint(
                  painter: _AmbientDotsPainter(
                    progress: _ambientController.value,
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entranceController,
                curve: Curves.easeOut,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: CustomScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(child: _buildTopBar()),
                        SliverToBoxAdapter(child: _buildHero()),
                        SliverToBoxAdapter(child: _buildSearch()),
                        SliverToBoxAdapter(child: _buildNotice()),
                        if (languages.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _EmptyLanguageState(
                              onClear: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 18, 20, 26),
                            sliver: SliverList.separated(
                              itemCount: languages.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 11),
                              itemBuilder: (context, index) {
                                final language = languages[index];

                                return _AnimatedLanguageItem(
                                  index: index,
                                  controller: _entranceController,
                                  child: _LanguageListTile(
                                    language: language,
                                    selected: language.code == _selectedCode,
                                    onTap: () => _selectLanguage(language),
                                  ),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildBottomBar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 20, 4),
      child: Row(
        children: [
          if (Navigator.of(context).canPop())
            IconButton(
              onPressed: () => Navigator.maybePop(context),
              style: IconButton.styleFrom(
                backgroundColor: LanguageColors.surface,
                foregroundColor: LanguageColors.primaryText,
                side: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
              icon: const Icon(Icons.arrow_back_rounded),
            )
          else
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LanguageColors.gradient,
              ),
              child: const Icon(
                Icons.translate_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'App Language',
                  style: TextStyle(
                    color: LanguageColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Choose your preferred guidance language',
                  style: TextStyle(
                    color: LanguageColors.mutedText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: LanguageColors.cyan.withOpacity(0.09),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: LanguageColors.cyan.withOpacity(0.16)),
            ),
            child: const Text(
              '6 languages',
              style: TextStyle(
                color: LanguageColors.cyan,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    final language = _selectedLanguage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF18365C),
              const Color(0xFF10283E),
              language.accent.withOpacity(0.16),
            ],
          ),
          border: Border.all(color: language.accent.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.22),
              blurRadius: 28,
              offset: const Offset(0, 15),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              width: 68,
              height: 68,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  colors: [
                    language.accent,
                    LanguageColors.blue,
                    LanguageColors.violet,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: language.accent.withOpacity(0.2),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  language.symbol,
                  key: ValueKey(language.code),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Column(
                  key: ValueKey(language.code),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CURRENT SELECTION',
                      style: TextStyle(
                        color: LanguageColors.cyan,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      language.nativeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LanguageColors.primaryText,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      language.name,
                      style: const TextStyle(
                        color: LanguageColors.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const CircleAvatar(
              radius: 16,
              backgroundColor: LanguageColors.success,
              child: Icon(
                Icons.check_rounded,
                color: Color(0xFF052014),
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 19, 20, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _query = value),
        cursorColor: LanguageColors.cyan,
        style: const TextStyle(
          color: LanguageColors.primaryText,
          fontSize: 13.5,
        ),
        decoration: InputDecoration(
          hintText: 'Search available languages',
          hintStyle: const TextStyle(
            color: LanguageColors.subtleText,
            fontSize: 12.5,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: LanguageColors.mutedText,
            size: 21,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _query = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: LanguageColors.mutedText,
                    size: 19,
                  ),
                ),
          filled: true,
          fillColor: LanguageColors.surface.withOpacity(0.9),
          border: _fieldBorder(LanguageColors.border),
          enabledBorder: _fieldBorder(LanguageColors.border),
          focusedBorder: _fieldBorder(LanguageColors.cyan, width: 1.35),
        ),
      ),
    );
  }

  Widget _buildNotice() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: LanguageColors.blue.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: LanguageColors.cyan.withOpacity(0.13)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: LanguageColors.cyan,
              size: 19,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'IELTS tests remain in English. Your selected language is used for navigation, instructions and explanations.',
                style: TextStyle(
                  color: LanguageColors.secondaryText,
                  fontSize: 11.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final language = _selectedLanguage;

    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        13,
        20,
        14 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: LanguageColors.background.withOpacity(0.97),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.055))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 25,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 39,
                  height: 39,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: language.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    language.symbol,
                    style: TextStyle(
                      color: language.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    language.nativeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LanguageColors.primaryText,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LanguageColors.gradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: LanguageColors.blue.withOpacity(0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _loading ? null : _continue,
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.3,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        children: [
                          Text(
                            'Continue',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 7),
                          Icon(Icons.arrow_forward_rounded, size: 19),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AppLanguage {
  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.symbol,
    required this.description,
    required this.accent,
  });

  final String code;
  final String name;
  final String nativeName;
  final String symbol;
  final String description;
  final Color accent;
}

class _LanguageListTile extends StatelessWidget {
  const _LanguageListTile({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final AppLanguage language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${language.name} language',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(21),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 230),
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF132A40)
                  : LanguageColors.surface.withOpacity(0.88),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: selected
                    ? language.accent.withOpacity(0.62)
                    : Colors.white.withOpacity(0.065),
                width: selected ? 1.4 : 1,
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: language.accent.withOpacity(0.12),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 230),
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(17),
                    gradient: selected
                        ? LinearGradient(
                            colors: [
                              language.accent,
                              LanguageColors.blue,
                              LanguageColors.violet,
                            ],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF1B2D42), Color(0xFF132238)],
                          ),
                  ),
                  child: Text(
                    language.symbol,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.nativeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LanguageColors.primaryText,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        language.name,
                        style: const TextStyle(
                          color: LanguageColors.secondaryText,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        language.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? language.accent
                              : LanguageColors.subtleText,
                          fontSize: 9.8,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 29,
                  height: 29,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: selected ? language.accent : Colors.transparent,
                    border: Border.all(
                      color: selected ? language.accent : LanguageColors.border,
                      width: 1.4,
                    ),
                  ),
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          color: Color(0xFF06111E),
                          size: 18,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AnimatedLanguageItem extends StatelessWidget {
  const _AnimatedLanguageItem({
    required this.index,
    required this.controller,
    required this.child,
  });

  final int index;
  final AnimationController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.18 + (index * 0.055), 0.60);
    final end = math.min(start + 0.35, 1.0);

    final animation = CurvedAnimation(
      parent: controller,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );

    return FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.13),
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}

class _EmptyLanguageState extends StatelessWidget {
  const _EmptyLanguageState({required this.onClear});

  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.search_off_rounded,
              color: LanguageColors.mutedText,
              size: 50,
            ),
            const SizedBox(height: 14),
            const Text(
              'No language found',
              style: TextStyle(
                color: LanguageColors.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Try another language name.',
              style: TextStyle(color: LanguageColors.mutedText, fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Clear search'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageBackground extends StatelessWidget {
  const _LanguageBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF030914),
                Color(0xFF07111F),
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
            ),
          ),
        ),
        const Positioned(
          top: -170,
          right: -135,
          child: _GlowOrb(size: 370, color: Color(0x282563EB)),
        ),
        const Positioned(
          top: 390,
          left: -180,
          child: _GlowOrb(size: 350, color: Color(0x1506B6D4)),
        ),
        const Positioned(
          bottom: -190,
          right: -150,
          child: _GlowOrb(size: 410, color: Color(0x158B5CF6)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

class _AmbientDotsPainter extends CustomPainter {
  const _AmbientDotsPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    const points = [
      Offset(0.09, 0.15),
      Offset(0.88, 0.12),
      Offset(0.93, 0.35),
      Offset(0.12, 0.52),
      Offset(0.84, 0.69),
      Offset(0.18, 0.84),
    ];

    for (int index = 0; index < points.length; index++) {
      final point = points[index];
      final angle = (progress * math.pi * 2) + (index * 0.77);
      final x = (point.dx * size.width) + math.sin(angle) * 4;
      final y = (point.dy * size.height) + math.cos(angle) * 6;
      final opacity = 0.035 + ((math.sin(angle) + 1) * 0.025);

      paint.color = index.isEven
          ? LanguageColors.cyan.withOpacity(opacity)
          : LanguageColors.violet.withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), index % 3 == 0 ? 1.7 : 1.1, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientDotsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class LanguageColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const primaryText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const border = Color(0xFF26364A);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF34D399);

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

OutlineInputBorder _fieldBorder(Color color, {double width = 1}) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(17),
    borderSide: BorderSide(color: color, width: width),
  );
}
