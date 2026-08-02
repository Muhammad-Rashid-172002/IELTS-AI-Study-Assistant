import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fyproject/screens/Onboarding_Screen/Onboarding_screen.dart';

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() =>
      _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();

  late final AnimationController _entranceController;
  late final AnimationController _backgroundController;

  String _searchQuery = '';
  String _selectedLanguageCode = 'en';

  final List<AppLanguage> _languages = const [
    AppLanguage(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      symbol: 'EN',
      description: 'Recommended',
    ),
    AppLanguage(
      code: 'ur',
      name: 'Urdu',
      nativeName: 'اردو',
      symbol: 'ا',
      description: 'اردو میں ہدایات',
    ),
    AppLanguage(
      code: 'ar',
      name: 'Arabic',
      nativeName: 'العربية',
      symbol: 'ع',
      description: 'تعليمات باللغة العربية',
    ),
    AppLanguage(
      code: 'hi',
      name: 'Hindi',
      nativeName: 'हिन्दी',
      symbol: 'हि',
      description: 'हिंदी में निर्देश',
    ),
    AppLanguage(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      symbol: 'ES',
      description: 'Instrucciones en español',
    ),
    AppLanguage(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      symbol: '中',
      description: '中文说明',
    ),
  ];

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    )..forward();

    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _entranceController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  List<AppLanguage> get _filteredLanguages {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) return _languages;

    return _languages.where((language) {
      return language.name.toLowerCase().contains(query) ||
          language.nativeName.toLowerCase().contains(query) ||
          language.description.toLowerCase().contains(query);
    }).toList();
  }

  AppLanguage get _selectedLanguage {
    return _languages.firstWhere(
      (language) => language.code == _selectedLanguageCode,
    );
  }

  void _continue() {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 550),
        pageBuilder: (_, animation, secondaryAnimation) {
          return PremiumOnboardingScreen();
        },
        transitionsBuilder: (_, animation, secondaryAnimation, child) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          final slide =
              Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              );

          return FadeTransition(
            opacity: fade,
            child: SlideTransition(position: slide, child: child),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languages = _filteredLanguages;

    return Scaffold(
      backgroundColor: const Color(0xFF07111F),
      body: Stack(
        children: [
          const Positioned.fill(child: _LanguageBackground()),
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _AmbientDotsPainter(
                    progress: _backgroundController.value,
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
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.035),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(
                        parent: _entranceController,
                        curve: Curves.easeOutCubic,
                      ),
                    ),
                child: Column(
                  children: [
                    Expanded(
                      child: CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
                              child: _buildHeader(),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
                              child: _buildSearchField(),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(22, 18, 22, 0),
                              child: _buildEnglishNotice(),
                            ),
                          ),
                          if (languages.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyLanguageState(
                                onClear: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                22,
                                22,
                                22,
                                24,
                              ),
                              sliver: SliverGrid(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final language = languages[index];
                                  final isSelected =
                                      language.code == _selectedLanguageCode;

                                  return _LanguageCard(
                                    language: language,
                                    isSelected: isSelected,
                                    animationIndex: index,
                                    entranceController: _entranceController,
                                    onTap: () {
                                      FocusScope.of(context).unfocus();
                                      setState(() {
                                        _selectedLanguageCode = language.code;
                                      });
                                    },
                                  );
                                }, childCount: languages.length),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      mainAxisSpacing: 14,
                                      crossAxisSpacing: 14,
                                      childAspectRatio: 0.95,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    _buildBottomAction(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF8B5CF6)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF06B6D4).withOpacity(0.20),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.translate_rounded,
            color: Colors.white,
            size: 25,
          ),
        ),
        const SizedBox(width: 15),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Choose your language',
                style: TextStyle(
                  color: Color(0xFFF8FAFC),
                  fontSize: 27,
                  height: 1.12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Select the language for app instructions, explanations and AI guidance.',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 13.5,
                  height: 1.55,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF101C2E).withOpacity(0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.075)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.20),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(
          color: Color(0xFFF8FAFC),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: const Color(0xFF22D3EE),
        decoration: InputDecoration(
          hintText: 'Search language',
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF94A3B8),
            size: 22,
          ),
          suffixIcon: _searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Color(0xFF94A3B8),
                    size: 20,
                  ),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
        ),
      ),
    );
  }

  Widget _buildEnglishNotice() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            const Color(0xFF2563EB).withOpacity(0.13),
            const Color(0xFF06B6D4).withOpacity(0.08),
          ],
        ),
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFF22D3EE).withOpacity(0.12),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF67E8F9),
              size: 19,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'IELTS questions and tests remain in English. Only the app interface, instructions and explanations will be translated.',
              style: TextStyle(
                color: Color(0xFFCBD5E1),
                fontSize: 12.4,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 15, 22, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF07111F).withOpacity(0.96),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.055))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.24),
            blurRadius: 26,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Selected: ${_selectedLanguage.nativeName}',
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2563EB),
                    Color(0xFF06B6D4),
                    Color(0xFF7C3AED),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withOpacity(0.28),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: _continue,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.15,
                      ),
                    ),
                    SizedBox(width: 9),
                    Icon(Icons.arrow_forward_rounded, size: 21),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 11),
          const Text(
            'You can change this later in Settings',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF64748B),
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class AppLanguage {
  final String code;
  final String name;
  final String nativeName;
  final String symbol;
  final String description;

  const AppLanguage({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.symbol,
    required this.description,
  });
}

class _LanguageCard extends StatelessWidget {
  final AppLanguage language;
  final bool isSelected;
  final int animationIndex;
  final AnimationController entranceController;
  final VoidCallback onTap;

  const _LanguageCard({
    required this.language,
    required this.isSelected,
    required this.animationIndex,
    required this.entranceController,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final start = math.min(0.25 + (animationIndex * 0.07), 0.72);
    final end = math.min(start + 0.28, 1.0);

    final animation = CurvedAnimation(
      parent: entranceController,
      curve: Interval(start, end, curve: Curves.easeOutBack),
    );

    return ScaleTransition(
      scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
      child: FadeTransition(
        opacity: animation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(22),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                color: isSelected
                    ? const Color(0xFF132B43)
                    : const Color(0xFF101C2E).withOpacity(0.90),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF22D3EE).withOpacity(0.68)
                      : Colors.white.withOpacity(0.065),
                  width: isSelected ? 1.45 : 1,
                ),
                boxShadow: [
                  if (isSelected)
                    BoxShadow(
                      color: const Color(0xFF06B6D4).withOpacity(0.16),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.13),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      width: 25,
                      height: 25,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF22D3EE)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF22D3EE)
                              : const Color(0xFF475569),
                          width: 1.4,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              color: Color(0xFF07111F),
                              size: 17,
                            )
                          : null,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: isSelected
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF2563EB),
                                    Color(0xFF06B6D4),
                                    Color(0xFF8B5CF6),
                                  ],
                                )
                              : const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF182A40),
                                    Color(0xFF122033),
                                  ],
                                ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Text(
                          language.symbol,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        language.nativeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFF8FAFC),
                          fontSize: 17,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        language.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        language.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFF67E8F9)
                              : const Color(0xFF64748B),
                          fontSize: 9.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
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
                Color(0xFF040A13),
                Color(0xFF07111F),
                Color(0xFF0A192B),
                Color(0xFF07111F),
              ],
              stops: [0.0, 0.36, 0.70, 1.0],
            ),
          ),
        ),
        const Positioned(
          top: -140,
          right: -120,
          child: _GlowCircle(size: 330, color: Color(0x2C2563EB)),
        ),
        const Positioned(
          top: 330,
          left: -150,
          child: _GlowCircle(size: 300, color: Color(0x1806B6D4)),
        ),
        const Positioned(
          bottom: -160,
          right: -130,
          child: _GlowCircle(size: 360, color: Color(0x188B5CF6)),
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
  final double progress;

  _AmbientDotsPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    const positions = [
      Offset(0.08, 0.16),
      Offset(0.88, 0.12),
      Offset(0.93, 0.36),
      Offset(0.12, 0.54),
      Offset(0.84, 0.67),
      Offset(0.20, 0.80),
      Offset(0.67, 0.24),
      Offset(0.53, 0.91),
    ];

    for (int index = 0; index < positions.length; index++) {
      final position = positions[index];
      final angle = (progress * math.pi * 2) + (index * 0.8);

      final x = (position.dx * size.width) + (math.sin(angle) * 4.5);
      final y = (position.dy * size.height) + (math.cos(angle) * 6.5);
      final opacity = 0.05 + ((math.sin(angle) + 1) * 0.035);

      paint.color = index.isEven
          ? const Color(0xFF38BDF8).withOpacity(opacity)
          : const Color(0xFFA78BFA).withOpacity(opacity);

      canvas.drawCircle(Offset(x, y), index % 3 == 0 ? 1.8 : 1.2, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AmbientDotsPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _EmptyLanguageState extends StatelessWidget {
  final VoidCallback onClear;

  const _EmptyLanguageState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF101C2E),
                borderRadius: BorderRadius.circular(23),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: const Icon(
                Icons.language_rounded,
                color: Color(0xFF64748B),
                size: 34,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Language not found',
              style: TextStyle(
                color: Color(0xFFF8FAFC),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try searching for another available language.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Clear search'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF67E8F9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

