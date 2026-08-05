import 'package:flutter/material.dart';
import 'package:ielts_ai_master_admin/core/theme/admin_theme.dart';
import 'package:ielts_ai_master_admin/features/Subscription/subcription_screen.dart';
import 'package:ielts_ai_master_admin/features/auth/data/admin_auth_service.dart';
import 'package:ielts_ai_master_admin/features/diagnostic/presentation/diagnostic_management_screen.dart';
import 'package:ielts_ai_master_admin/features/generation/presentation/generation_jobs_screen.dart';
import 'package:ielts_ai_master_admin/features/listening/presentation/listening_management_screen.dart';
import 'package:ielts_ai_master_admin/features/mock_test_admin_module/presentation/mock_test_management_screen.dart';
import 'package:ielts_ai_master_admin/features/reading_admin_generator/presentation/reading_management_screen.dart';
import 'package:ielts_ai_master_admin/features/settings/presentation/admin_settings_screen.dart';
import 'package:ielts_ai_master_admin/features/speaking_admin_module/presentation/speaking_management_screen.dart';
import 'package:ielts_ai_master_admin/features/users/presentation/users_management_screen.dart';
import 'package:ielts_ai_master_admin/features/vocabulary_admin_full/presentation/vocabulary_management_screen.dart';
import 'package:ielts_ai_master_admin/features/writing_admin_module/presentation/writing_management_screen.dart';

import 'dashboard_home_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  late final List<Widget> _pages;

  static const List<_NavigationItem> _items = [
    _NavigationItem(
      label: 'Dashboard',
      description: 'Platform overview',
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
      group: _NavigationGroup.overview,
    ),
    _NavigationItem(
      label: 'Listening',
      description: 'Audio tests and practice',
      icon: Icons.headphones_outlined,
      selectedIcon: Icons.headphones_rounded,
      group: _NavigationGroup.content,
    ),
    _NavigationItem(
      label: 'Reading',
      description: 'Passages and questions',
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book_rounded,
      group: _NavigationGroup.content,
    ),
    _NavigationItem(
      label: 'Writing',
      description: 'Tasks and AI evaluation',
      icon: Icons.edit_note_outlined,
      selectedIcon: Icons.edit_note_rounded,
      group: _NavigationGroup.content,
    ),
    _NavigationItem(
      label: 'Speaking',
      description: 'Tests, recordings and bands',
      icon: Icons.mic_none_rounded,
      selectedIcon: Icons.mic_rounded,
      group: _NavigationGroup.content,
    ),
    _NavigationItem(
      label: 'Vocabulary',
      description: 'Words, quizzes and mastery',
      icon: Icons.translate_outlined,
      selectedIcon: Icons.translate_rounded,
      group: _NavigationGroup.content,
    ),
    _NavigationItem(
      label: 'Mock Tests',
      description: 'Full simulations and question bank',
      icon: Icons.fact_check_outlined,
      selectedIcon: Icons.fact_check_rounded,
      group: _NavigationGroup.assessment,
    ),
    _NavigationItem(
      label: 'Diagnostic',
      description: 'Four-skill level assessments',
      icon: Icons.health_and_safety_outlined,
      selectedIcon: Icons.health_and_safety_rounded,
      group: _NavigationGroup.assessment,
    ),
    _NavigationItem(
      label: 'AI Jobs',
      description: 'Generation queue and status',
      icon: Icons.auto_awesome_outlined,
      selectedIcon: Icons.auto_awesome_rounded,
      group: _NavigationGroup.platform,
    ),
    _NavigationItem(
      label: 'Users',
      description: 'Learners and activity',
      icon: Icons.people_outline_rounded,
      selectedIcon: Icons.people_rounded,
      group: _NavigationGroup.platform,
    ),
    _NavigationItem(
      label: 'Subscriptions',
      description: 'Payments and premium activation',
      icon: Icons.workspace_premium_outlined,
      selectedIcon: Icons.workspace_premium_rounded,
      group: _NavigationGroup.platform,
    ),
    _NavigationItem(
      label: 'Settings',
      description: 'Admin configuration',
      icon: Icons.settings_outlined,
      selectedIcon: Icons.settings_rounded,
      group: _NavigationGroup.platform,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pages = [
      DashboardHomeScreen(
        onOpenListening: () => _selectPage(1),
        onOpenReading: () => _selectPage(2),
        onOpenWriting: () => _selectPage(3),
        onOpenSpeaking: () => _selectPage(4),
        onOpenVocabulary: () => _selectPage(5),
        onOpenMockTests: () => _selectPage(6),
        onOpenDiagnostics: () => _selectPage(7),
        onOpenJobs: () => _selectPage(8),
        onOpenUsers: () => _selectPage(9),
        onOpenSubscriptions: () => _selectPage(10),
      ),
      const ListeningManagementScreen(),
      const ReadingManagementScreen(),
      const WritingManagementScreen(),
      const SpeakingManagementScreen(),
      const VocabularyManagementScreen(),
      const MockTestManagementScreen(),
      const DiagnosticManagementScreen(),
      const GenerationJobsScreen(),
      const UsersManagementScreen(),
      const AdminSubscriptionManagementScreen(),
      const AdminSettingsScreen(),
    ];

    assert(
      _items.length == _pages.length,
      'Admin navigation items and pages must have the same length.',
    );
  }

  void _selectPage(int index) {
    if (!mounted || index < 0 || index >= _pages.length || index == _index) {
      return;
    }

    setState(() => _index = index);
  }

  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AdminColors.surface,
        title: const Text(
          'Sign out?',
          style: TextStyle(
            color: AdminColors.text,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: const Text(
          'You will need to sign in again to access the admin panel.',
          style: TextStyle(color: AdminColors.textMuted, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      await AdminAuthService().signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width >= 1180) {
      return _DesktopAdminLayout(
        selectedIndex: _index,
        items: _items,
        pages: _pages,
        onSelected: _selectPage,
        onLogout: _logout,
      );
    }

    if (width >= 760) {
      return _TabletAdminLayout(
        selectedIndex: _index,
        items: _items,
        pages: _pages,
        onSelected: _selectPage,
        onLogout: _logout,
      );
    }

    return _MobileAdminLayout(
      selectedIndex: _index,
      items: _items,
      pages: _pages,
      onSelected: _selectPage,
      onLogout: _logout,
    );
  }
}

// -----------------------------------------------------------------------------
// Desktop layout
// -----------------------------------------------------------------------------

class _DesktopAdminLayout extends StatelessWidget {
  final int selectedIndex;
  final List<_NavigationItem> items;
  final List<Widget> pages;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const _DesktopAdminLayout({
    required this.selectedIndex,
    required this.items,
    required this.pages,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(
        children: [
          _DesktopSidebar(
            selectedIndex: selectedIndex,
            items: items,
            onSelected: onSelected,
            onLogout: onLogout,
          ),
          Expanded(
            child: _PageHost(selectedIndex: selectedIndex, pages: pages),
          ),
        ],
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  final int selectedIndex;
  final List<_NavigationItem> items;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const _DesktopSidebar({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 304,
      decoration: BoxDecoration(
        color: AdminColors.surface,
        border: const Border(right: BorderSide(color: AdminColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.12),
            blurRadius: 28,
            offset: const Offset(8, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: _Brand(expanded: true),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
                children: [
                  _SidebarGroup(
                    title: 'OVERVIEW',
                    items: items,
                    indexes: const [0],
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                  ),
                  const SizedBox(height: 12),
                  _SidebarGroup(
                    title: 'IELTS CONTENT',
                    items: items,
                    indexes: const [1, 2, 3, 4, 5],
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                  ),
                  const SizedBox(height: 12),
                  _SidebarGroup(
                    title: 'ASSESSMENTS',
                    items: items,
                    indexes: const [6, 7],
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                  ),
                  const SizedBox(height: 12),
                  _SidebarGroup(
                    title: 'PLATFORM',
                    items: items,
                    indexes: const [8, 9, 10, 11],
                    selectedIndex: selectedIndex,
                    onSelected: onSelected,
                  ),
                ],
              ),
            ),
            _AdminStatusPanel(onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _SidebarGroup extends StatelessWidget {
  final String title;
  final List<_NavigationItem> items;
  final List<int> indexes;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _SidebarGroup({
    required this.title,
    required this.items,
    required this.indexes,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SidebarSectionLabel(label: title),
        ...indexes.map(
          (index) => _SidebarItem(
            item: items[index],
            selected: selectedIndex == index,
            onTap: () => onSelected(index),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Tablet layout
// -----------------------------------------------------------------------------

class _TabletAdminLayout extends StatelessWidget {
  final int selectedIndex;
  final List<_NavigationItem> items;
  final List<Widget> pages;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const _TabletAdminLayout({
    required this.selectedIndex,
    required this.items,
    required this.pages,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminColors.background,
      body: Row(
        children: [
          Container(
            width: 88,
            decoration: BoxDecoration(
              color: AdminColors.surface,
              border: const Border(
                right: BorderSide(color: AdminColors.border),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.10),
                  blurRadius: 20,
                  offset: const Offset(6, 0),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 18),
                    child: _Brand(expanded: false),
                  ),
                  const Divider(height: 1, color: AdminColors.border),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = selectedIndex == index;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Tooltip(
                            message: '${item.label}\n${item.description}',
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => onSelected(index),
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  height: 58,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? AdminColors.primary.withOpacity(.18)
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: selected
                                          ? AdminColors.primary.withOpacity(.40)
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Icon(
                                    selected ? item.selectedIcon : item.icon,
                                    color: selected
                                        ? AdminColors.cyan
                                        : AdminColors.textMuted,
                                    size: 23,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: IconButton.filledTonal(
                      tooltip: 'Sign Out',
                      onPressed: onLogout,
                      icon: const Icon(Icons.logout_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _PageHost(selectedIndex: selectedIndex, pages: pages),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Mobile layout
// -----------------------------------------------------------------------------

class _MobileAdminLayout extends StatelessWidget {
  final int selectedIndex;
  final List<_NavigationItem> items;
  final List<Widget> pages;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const _MobileAdminLayout({
    required this.selectedIndex,
    required this.items,
    required this.pages,
    required this.onSelected,
    required this.onLogout,
  });

  static const primaryIndexes = [0, 1, 6, 10];

  @override
  Widget build(BuildContext context) {
    final selectedPrimaryIndex = primaryIndexes.indexOf(selectedIndex);
    final moreSelected = selectedPrimaryIndex == -1;

    return Scaffold(
      backgroundColor: AdminColors.background,
      drawer: _MobileDrawer(
        selectedIndex: selectedIndex,
        items: items,
        onSelected: (index) {
          Navigator.pop(context);
          onSelected(index);
        },
        onLogout: () {
          Navigator.pop(context);
          onLogout();
        },
      ),
      appBar: AppBar(
        backgroundColor: AdminColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: Text(
                items[selectedIndex].label,
                style: const TextStyle(
                  color: AdminColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AdminColors.success.withOpacity(.10),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AdminColors.success.withOpacity(.24)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.circle, color: AdminColors.success, size: 7),
                  SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: AdminColors.success,
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      letterSpacing: .7,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AdminColors.border),
        ),
      ),
      body: _PageHost(selectedIndex: selectedIndex, pages: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: moreSelected
            ? primaryIndexes.length
            : selectedPrimaryIndex,
        onDestinationSelected: (destinationIndex) {
          if (destinationIndex < primaryIndexes.length) {
            onSelected(primaryIndexes[destinationIndex]);
            return;
          }

          _showMoreSheet(context);
        },
        destinations: [
          for (final index in primaryIndexes)
            NavigationDestination(
              icon: Icon(items[index].icon),
              selectedIcon: Icon(items[index].selectedIcon),
              label: items[index].label,
            ),
          NavigationDestination(
            icon: Icon(
              moreSelected ? Icons.grid_view_rounded : Icons.grid_view_outlined,
            ),
            selectedIcon: const Icon(Icons.grid_view_rounded),
            label: 'More',
          ),
        ],
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    const secondaryIndexes = [2, 3, 4, 5, 8, 9, 10, 11];

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AdminColors.surface,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: MediaQuery.sizeOf(context).height * .82,
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Text(
                    'More Admin Tools',
                    style: TextStyle(
                      color: AdminColors.text,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Flexible(
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const BouncingScrollPhysics(),
                    itemCount: secondaryIndexes.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisExtent: 112,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                    itemBuilder: (context, position) {
                      final index = secondaryIndexes[position];
                      final item = items[index];
                      final selected = selectedIndex == index;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(sheetContext);
                            onSelected(index);
                          },
                          borderRadius: BorderRadius.circular(17),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AdminColors.primary.withOpacity(.16)
                                  : AdminColors.background,
                              borderRadius: BorderRadius.circular(17),
                              border: Border.all(
                                color: selected
                                    ? AdminColors.primary.withOpacity(.45)
                                    : AdminColors.border,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  selected ? item.selectedIcon : item.icon,
                                  color: selected
                                      ? AdminColors.cyan
                                      : AdminColors.textMuted,
                                ),
                                const Spacer(),
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    color: AdminColors.text,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  item.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AdminColors.textMuted,
                                    fontSize: 9.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final int selectedIndex;
  final List<_NavigationItem> items;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  const _MobileDrawer({
    required this.selectedIndex,
    required this.items,
    required this.onSelected,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AdminColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 22, 20, 18),
              child: _Brand(expanded: true),
            ),
            const Divider(height: 1, color: AdminColors.border),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  for (var index = 0; index < items.length; index++)
                    _SidebarItem(
                      item: items[index],
                      selected: selectedIndex == index,
                      onTap: () => onSelected(index),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: OutlinedButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign Out'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Shared widgets
// -----------------------------------------------------------------------------

class _PageHost extends StatelessWidget {
  final int selectedIndex;
  final List<Widget> pages;

  const _PageHost({required this.selectedIndex, required this.pages});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AdminColors.background),
      child: IndexedStack(index: selectedIndex, children: pages),
    );
  }
}

class _Brand extends StatelessWidget {
  final bool expanded;

  const _Brand({required this.expanded});

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 48,
      height: 48,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminColors.cyan, AdminColors.primary, AdminColors.violet],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AdminColors.cyan.withOpacity(.22),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AdminColors.background.withOpacity(.78),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(
              Icons.auto_stories_rounded,
              color: Colors.white,
              size: 25,
            ),
            Positioned(
              top: 7,
              right: 7,
              child: Container(
                width: 13,
                height: 13,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [AdminColors.cyan, AdminColors.violet],
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 8,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!expanded) return logo;

    return Row(
      children: [
        logo,
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IELTS AI Admin',
                style: TextStyle(
                  color: AdminColors.text,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Content Intelligence Platform',
                style: TextStyle(color: AdminColors.textMuted, fontSize: 9.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AdminStatusPanel extends StatelessWidget {
  final VoidCallback onLogout;

  const _AdminStatusPanel({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AdminColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AdminColors.primary,
                child: Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Administrator',
                      style: TextStyle(
                        color: AdminColors.text,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.circle, color: AdminColors.success, size: 7),
                        SizedBox(width: 5),
                        Text(
                          'Secure session active',
                          style: TextStyle(
                            color: AdminColors.textMuted,
                            fontSize: 8.8,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(42),
              alignment: Alignment.centerLeft,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSectionLabel extends StatelessWidget {
  final String label;

  const _SidebarSectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AdminColors.textMuted,
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.15,
            ),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Divider(color: AdminColors.border, thickness: .7),
          ),
        ],
      ),
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final _NavigationItem item;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              gradient: selected
                  ? LinearGradient(
                      colors: [
                        AdminColors.primary.withOpacity(.22),
                        AdminColors.cyan.withOpacity(.08),
                      ],
                    )
                  : null,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: selected
                    ? AdminColors.primary.withOpacity(.42)
                    : Colors.transparent,
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: AdminColors.primary.withOpacity(.10),
                        blurRadius: 16,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : null,
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected
                        ? AdminColors.cyan.withOpacity(.12)
                        : AdminColors.background.withOpacity(.65),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(
                    selected ? item.selectedIcon : item.icon,
                    color: selected ? AdminColors.cyan : AdminColors.textMuted,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        style: TextStyle(
                          color: selected
                              ? AdminColors.text
                              : AdminColors.textMuted,
                          fontSize: 11.8,
                          fontWeight: selected
                              ? FontWeight.w900
                              : FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected
                              ? AdminColors.textMuted
                              : AdminColors.textMuted.withOpacity(.72),
                          fontSize: 8.7,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  Container(
                    width: 4,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AdminColors.cyan,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AdminColors.cyan.withOpacity(.35),
                          blurRadius: 8,
                        ),
                      ],
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

enum _NavigationGroup { overview, content, assessment, platform }

class _NavigationItem {
  final String label;
  final String description;
  final IconData icon;
  final IconData selectedIcon;
  final _NavigationGroup group;

  const _NavigationItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.selectedIcon,
    required this.group,
  });
}
