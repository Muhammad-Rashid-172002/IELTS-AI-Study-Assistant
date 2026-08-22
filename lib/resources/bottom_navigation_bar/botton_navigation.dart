import 'package:flutter/material.dart';
import 'package:fyproject/AI_Coach/presentation/ai_coach_screen.dart';
import 'package:fyproject/screens/pages/Learn/LearnScreen.dart';
import 'package:fyproject/screens/pages/home/home.dart';
import 'package:fyproject/screens/pages/profile/presentation/profile_screen.dart';
import 'package:fyproject/screens/pages/progress/presentation/progress_dashboard_screen.dart';

class IELTSMainNavigation extends StatefulWidget {
  const IELTSMainNavigation({super.key});

  @override
  State<IELTSMainNavigation> createState() => _IELTSMainNavigationState();
}

class _IELTSMainNavigationState extends State<IELTSMainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeDashboard(),
    const LearnScreen(),
    const ProgressDashboardScreen(),
    const ProfileScreen(),
  ];

  final List<_NavigationItemData> _items = const [
    _NavigationItemData(
      label: 'Home',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    _NavigationItemData(
      label: 'Learn',
      icon: Icons.auto_stories_outlined,
      activeIcon: Icons.auto_stories_rounded,
    ),

    _NavigationItemData(
      label: 'Progress',
      icon: Icons.insights_outlined,
      activeIcon: Icons.insights_rounded,
    ),
    _NavigationItemData(
      label: 'Profile',
      icon: Icons.person_outline_rounded,
      activeIcon: Icons.person_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useNavigationRail = constraints.maxWidth >= 900;
        final content = IndexedStack(
          index: _currentIndex.clamp(0, _screens.length - 1),
          children: _screens,
        );

        if (useNavigationRail) {
          return Scaffold(
            backgroundColor: MainNavColors.background,
            body: SafeArea(
              child: Row(
                children: [
                  _PremiumNavigationRail(
                    currentIndex: _currentIndex,
                    items: _items,
                    onTap: _selectDestination,
                    onCoachTap: () => _openCoach(context),
                  ),
                  VerticalDivider(
                    width: 1,
                    color: Colors.white.withOpacity(.06),
                  ),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: MainNavColors.background,
          extendBody: true,
          body: content,
          floatingActionButton: _AICoachFloatingButton(
            onTap: () => _openCoach(context),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _PremiumBottomNavigation(
            currentIndex: _currentIndex,
            items: _items,
            onTap: _selectDestination,
          ),
        );
      },
    );
  }

  void _selectDestination(int index) {
    if (index < 0 || index >= _screens.length) return;
    setState(() => _currentIndex = index);
  }

  void _openCoach(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AiCoachScreen()));
  }
}

class _PremiumNavigationRail extends StatelessWidget {
  final int currentIndex;
  final List<_NavigationItemData> items;
  final ValueChanged<int> onTap;
  final VoidCallback onCoachTap;

  const _PremiumNavigationRail({
    required this.currentIndex,
    required this.items,
    required this.onTap,
    required this.onCoachTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 116,
      padding: const EdgeInsets.fromLTRB(12, 18, 12, 16),
      decoration: BoxDecoration(
        color: MainNavColors.surface.withOpacity(.72),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            MainNavColors.surface.withOpacity(.95),
            MainNavColors.background.withOpacity(.98),
          ],
        ),
      ),
      child: Column(
        children: [
          Semantics(
            label: 'IELTS AI Master',
            image: true,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: MainNavColors.gradient,
                borderRadius: BorderRadius.circular(17),
                boxShadow: [
                  BoxShadow(
                    color: MainNavColors.cyan.withOpacity(.18),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: const Icon(
                Icons.auto_stories_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'IELTS AI',
            style: TextStyle(
              color: MainNavColors.mainText,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: .3,
            ),
          ),
          const SizedBox(height: 26),
          for (var index = 0; index < items.length; index++) ...[
            _NavigationItem(
              data: items[index],
              selected: currentIndex == index,
              onTap: () => onTap(index),
            ),
            const SizedBox(height: 8),
          ],
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onCoachTap,
              borderRadius: BorderRadius.circular(22),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: MainNavColors.gradient,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: MainNavColors.cyan.withOpacity(.20),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.psychology_alt_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'AI Coach',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
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

class _PremiumBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final List<_NavigationItemData> items;
  final ValueChanged<int> onTap;

  const _PremiumBottomNavigation({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: EdgeInsets.fromLTRB(
        10,
        9,
        10,
        9 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: MainNavColors.surface.withOpacity(0.97),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: MainNavColors.blue.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _NavigationItem(
              data: items[0],
              selected: currentIndex == 0,
              onTap: () => onTap(0),
            ),
          ),
          Expanded(
            child: _NavigationItem(
              data: items[1],
              selected: currentIndex == 1,
              onTap: () => onTap(1),
            ),
          ),
          const SizedBox(width: 72),
          Expanded(
            child: _NavigationItem(
              data: items[2],
              selected: currentIndex == 2,
              onTap: () => onTap(2),
            ),
          ),
          Expanded(
            child: _NavigationItem(
              data: items[3],
              selected: currentIndex == 3,
              onTap: () => onTap(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final _NavigationItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? MainNavColors.cyan.withOpacity(0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  selected ? data.activeIcon : data.icon,
                  key: ValueKey<bool>(selected),
                  color: selected
                      ? MainNavColors.cyan
                      : MainNavColors.mutedText,
                  size: selected ? 23 : 22,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? MainNavColors.mainText
                      : MainNavColors.mutedText,
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: selected ? 18 : 0,
                height: 3,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: selected ? MainNavColors.gradient : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AICoachFloatingButton extends StatelessWidget {
  final VoidCallback onTap;

  const _AICoachFloatingButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, 7),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: MainNavColors.gradient,
              border: Border.all(color: MainNavColors.background, width: 5),
              boxShadow: [
                BoxShadow(
                  color: MainNavColors.cyan.withOpacity(0.30),
                  blurRadius: 26,
                  spreadRadius: 1,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: MainNavColors.violet.withOpacity(0.20),
                  blurRadius: 30,
                  spreadRadius: -3,
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.psychology_alt_rounded,
                  color: Colors.white,
                  size: 29,
                ),
                Positioned(
                  top: 9,
                  right: 10,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF67E8F9),
                      border: Border.all(color: Colors.white, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: MainNavColors.cyan.withOpacity(0.7),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationItemData {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _NavigationItemData({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class MainNavColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const surfaceLight = Color(0xFF182A40);
  static const mainText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF34D399);

  static const gradient = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF06B6D4), Color(0xFF7C3AED)],
  );
}

class _CoachWelcomeCard extends StatelessWidget {
  const _CoachWelcomeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            MainNavColors.blue.withOpacity(0.22),
            MainNavColors.cyan.withOpacity(0.11),
            MainNavColors.violet.withOpacity(0.16),
          ],
        ),
        border: Border.all(color: MainNavColors.cyan.withOpacity(0.18)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: MainNavColors.blue,
            child: Icon(
              Icons.psychology_alt_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How can I help today?',
                  style: TextStyle(
                    color: MainNavColors.mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Ask about your study plan, mistakes, writing, speaking or target band.',
                  style: TextStyle(
                    color: MainNavColors.secondaryText,
                    fontSize: 10.8,
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

class _CoachQuickActions extends StatelessWidget {
  const _CoachQuickActions();

  @override
  Widget build(BuildContext context) {
    const actions = [
      'What should I practice today?',
      'Explain my weak areas',
      'Create a Band 7 plan',
      'Give me a speaking cue card',
    ];

    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: actions.map((action) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: MainNavColors.surface.withOpacity(0.92),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Text(
            action,
            style: const TextStyle(
              color: MainNavColors.secondaryText,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String text;
  final bool isCoach;

  const _ChatBubble({required this.text, required this.isCoach});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isCoach ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isCoach
              ? MainNavColors.surface
              : MainNavColors.blue.withOpacity(0.30),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isCoach ? 5 : 18),
            bottomRight: Radius.circular(isCoach ? 18 : 5),
          ),
          border: Border.all(
            color: isCoach
                ? Colors.white.withOpacity(0.06)
                : MainNavColors.cyan.withOpacity(0.18),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: MainNavColors.secondaryText,
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _CoachInputBar extends StatelessWidget {
  const _CoachInputBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        11,
        16,
        11 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: MainNavColors.background.withOpacity(0.97),
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
              decoration: BoxDecoration(
                color: MainNavColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.07)),
              ),
              child: const TextField(
                style: TextStyle(color: MainNavColors.mainText, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Ask your AI Coach...',
                  hintStyle: TextStyle(color: MainNavColors.subtleText),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: MainNavColors.gradient,
            ),
            child: const Icon(
              Icons.send_rounded,
              color: Colors.white,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationBackground extends StatelessWidget {
  const _NavigationBackground();

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
                Color(0xFF09182A),
                Color(0xFF07111F),
              ],
              stops: [0, 0.35, 0.72, 1],
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -120,
          child: _GlowOrb(size: 340, color: Color(0x2B2563EB)),
        ),
        const Positioned(
          top: 340,
          left: -160,
          child: _GlowOrb(size: 320, color: Color(0x1706B6D4)),
        ),
        const Positioned(
          bottom: -180,
          right: -150,
          child: _GlowOrb(size: 390, color: Color(0x178B5CF6)),
        ),
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowOrb({required this.size, required this.color});

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
