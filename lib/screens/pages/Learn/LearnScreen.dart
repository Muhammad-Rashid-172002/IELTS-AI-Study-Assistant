import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LearnScreen extends StatefulWidget {
  const LearnScreen({super.key});
  @override
  State<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends State<LearnScreen> {
  final _search = TextEditingController();
  String query = '';

  static const categories = <LearnCategory>[
    LearnCategory(
      'listening',
      'Listening Masterclass',
      'Question types, strategies and mini practice',
      Icons.headphones_rounded,
      LearnColors.cyan,
      18,
    ),
    LearnCategory(
      'reading',
      'Reading Masterclass',
      'Skimming, scanning and question strategies',
      Icons.menu_book_rounded,
      LearnColors.blue,
      20,
    ),
    LearnCategory(
      'writing',
      'Writing Masterclass',
      'Task 1, Task 2 and model answers',
      Icons.edit_note_rounded,
      LearnColors.violet,
      24,
    ),
    LearnCategory(
      'speaking',
      'Speaking Masterclass',
      'Fluency, pronunciation and all three parts',
      Icons.mic_rounded,
      LearnColors.green,
      16,
    ),
    LearnCategory(
      'vocabulary',
      'Vocabulary Builder',
      'Academic words, collocations and quizzes',
      Icons.translate_rounded,
      LearnColors.orange,
      30,
    ),
    LearnCategory(
      'grammar',
      'Grammar Course',
      'IELTS grammar from foundation to advanced',
      Icons.spellcheck_rounded,
      LearnColors.pink,
      22,
    ),
  ];

  List<LearnCategory> get filtered => query.isEmpty
      ? categories
      : categories
            .where(
              (e) => '${e.title} ${e.subtitle}'.toLowerCase().contains(query),
            )
            .toList();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearnColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header(context)),
            SliverToBoxAdapter(child: _searchBar()),
            SliverToBoxAdapter(child: _dailyGoal()),
            const SliverToBoxAdapter(
              child: SectionTitle(
                title: 'IELTS Learning Paths',
                subtitle:
                    'Learn concepts first, then practise with confidence.',
              ),
            ),
            _grid(),
            SliverToBoxAdapter(child: _coach()),
            SliverToBoxAdapter(child: _featured()),
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
    child: Row(
      children: [
        const GradientIcon(icon: Icons.auto_stories_rounded),
        const SizedBox(width: 13),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learn',
                style: TextStyle(
                  color: LearnColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                'Master IELTS step by step',
                style: TextStyle(color: LearnColors.muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SavedLessonsScreen()),
          ),
          icon: const Icon(Icons.bookmark_outline_rounded),
        ),
      ],
    ),
  );

  Widget _searchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
    child: TextField(
      controller: _search,
      cursorColor: LearnColors.cyan,
      style: const TextStyle(color: LearnColors.text),
      onChanged: (v) => setState(() => query = v.trim().toLowerCase()),
      decoration: InputDecoration(
        hintText: 'Search lessons, skills or topics...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: query.isEmpty
            ? null
            : IconButton(
                onPressed: () => setState(() {
                  query = '';
                  _search.clear();
                }),
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: LearnColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: const BorderSide(color: LearnColors.border),
        ),
      ),
    ),
  );

  Widget _dailyGoal() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const DailyGoalCard(streak: 0, done: 0, goal: 3);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (_, snap) {
        final d = snap.data?.data() ?? {};
        return DailyGoalCard(
          streak: asInt(d['streak']),
          done: asInt(d['dailyLessonsCompleted']),
          goal: asInt(d['dailyLessonGoal'], 3),
        );
      },
    );
  }

  Widget _grid() {
    if (filtered.isEmpty)
      return const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.all(36), child: EmptyState()),
      );
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      sliver: SliverLayoutBuilder(
        builder: (_, c) {
          final cols = c.crossAxisExtent >= 850 ? 3 : 2;
          return SliverGrid(
            delegate: SliverChildBuilderDelegate((context, i) {
              final item = filtered[i];
              return CategoryCard(
                category: item,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LearnCategoryScreen(category: item),
                  ),
                ),
              );
            }, childCount: filtered.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: cols,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .92,
            ),
          );
        },
      ),
    );
  }

  Widget _coach() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            LearnColors.blue.withOpacity(.25),
            LearnColors.violet.withOpacity(.18),
            LearnColors.cyan.withOpacity(.10),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: LearnColors.violet.withOpacity(.35)),
      ),
      child: const Row(
        children: [
          GradientIcon(icon: Icons.psychology_alt_rounded),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Study Coach',
                  style: TextStyle(
                    color: LearnColors.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Get lessons based on your weak skills and target band.',
                  style: TextStyle(
                    color: LearnColors.secondary,
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_ios_rounded,
            color: LearnColors.secondary,
            size: 15,
          ),
        ],
      ),
    ),
  );

  Widget _featured() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SectionTitle(
        title: 'Quick Lessons',
        subtitle: 'Short lessons you can complete today.',
      ),
      SizedBox(
        height: 155,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('learning_lessons')
              .where('status', isEqualTo: 'published')
              .where('isFeatured', isEqualTo: true)
              .limit(8)
              .snapshots(),
          builder: (context, snap) {
            final lessons = snap.hasData && snap.data!.docs.isNotEmpty
                ? snap.data!.docs.map(LearnLesson.fromDocument).toList()
                : fallbackLessons.take(6).toList();
            return ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: lessons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final lesson = lessons[i];
                return QuickLesson(
                  lesson: lesson,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LearnLessonScreen(lesson: lesson),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    ],
  );
}

class LearnCategoryScreen extends StatelessWidget {
  final LearnCategory category;
  const LearnCategoryScreen({super.key, required this.category});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LearnColors.background,
    appBar: AppBar(
      backgroundColor: LearnColors.background,
      title: Text(category.title),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('learning_lessons')
          .where('categoryId', isEqualTo: category.id)
          .where('status', isEqualTo: 'published')
          .snapshots(),
      builder: (context, snap) {
        final lessons = snap.hasData && snap.data!.docs.isNotEmpty
            ? snap.data!.docs.map(LearnLesson.fromDocument).toList()
            : fallbackLessons
                  .where((e) => e.categoryId == category.id)
                  .toList();
        lessons.sort((a, b) => a.order.compareTo(b.order));
        if (lessons.isEmpty)
          return const Center(
            child: EmptyState(
              title: 'Lessons coming soon',
              subtitle: 'Publish lessons from the admin panel.',
            ),
          );
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            CategoryHero(category: category),
            const SizedBox(height: 16),
            ...List.generate(
              lessons.length,
              (i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LessonTile(
                  number: i + 1,
                  lesson: lessons[i],
                  color: category.color,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LearnLessonScreen(lesson: lessons[i]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class LearnLessonScreen extends StatefulWidget {
  final LearnLesson lesson;
  const LearnLessonScreen({super.key, required this.lesson});
  @override
  State<LearnLessonScreen> createState() => _LearnLessonScreenState();
}

class _LearnLessonScreenState extends State<LearnLessonScreen> {
  bool complete = false, loading = false;
  Future<void> markComplete() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || loading) return;
    setState(() => loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('lesson_progress')
          .doc(widget.lesson.id)
          .set({
            'lessonId': widget.lesson.id,
            'categoryId': widget.lesson.categoryId,
            'title': widget.lesson.title,
            'progress': 100,
            'completed': true,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
      if (mounted) setState(() => complete = true);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('saved_lessons')
        .doc(widget.lesson.id)
        .set({
          'lessonId': widget.lesson.id,
          'categoryId': widget.lesson.categoryId,
          'title': widget.lesson.title,
          'summary': widget.lesson.summary,
          'durationMinutes': widget.lesson.durationMinutes,
          'level': widget.lesson.level,
          'savedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: LearnColors.background,
    appBar: AppBar(
      backgroundColor: LearnColors.background,
      title: const Text('Lesson'),
      actions: [
        IconButton(
          onPressed: save,
          icon: const Icon(Icons.bookmark_add_outlined),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: heroDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 7,
                children: [
                  Tag(widget.lesson.level),
                  Tag('${widget.lesson.durationMinutes} min'),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                widget.lesson.title,
                style: const TextStyle(
                  color: LearnColors.text,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.lesson.summary,
                style: const TextStyle(
                  color: LearnColors.secondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        InfoBlock(
          title: 'What you will learn',
          icon: Icons.lightbulb_outline_rounded,
          lines: widget.lesson.objectives.isEmpty
              ? const [
                  'Understand the IELTS strategy.',
                  'Identify common mistakes.',
                  'Apply the method in mini practice.',
                ]
              : widget.lesson.objectives,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(17),
          decoration: panelDecoration(),
          child: SelectableText(
            widget.lesson.content.isEmpty
                ? defaultLessonText(widget.lesson)
                : widget.lesson.content,
            style: const TextStyle(
              color: LearnColors.secondary,
              height: 1.7,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 12),
        const InfoBlock(
          title: 'Common mistakes',
          icon: Icons.warning_amber_rounded,
          lines: [
            'Ignoring instructions or word limits.',
            'Looking only for exact keyword matches.',
            'Spending too long on one question.',
          ],
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
        decoration: const BoxDecoration(
          color: LearnColors.surface,
          border: Border(top: BorderSide(color: LearnColors.border)),
        ),
        child: SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: complete || loading ? null : markComplete,
            icon: loading
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    complete
                        ? Icons.check_circle_rounded
                        : Icons.task_alt_rounded,
                  ),
            label: Text(complete ? 'Lesson Completed' : 'Mark as Complete'),
          ),
        ),
      ),
    ),
  );
}

class SavedLessonsScreen extends StatelessWidget {
  const SavedLessonsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: LearnColors.background,
      appBar: AppBar(
        backgroundColor: LearnColors.background,
        title: const Text('Saved Lessons'),
      ),
      body: uid == null
          ? const Center(
              child: EmptyState(
                title: 'Sign in required',
                subtitle: 'Sign in to save lessons.',
              ),
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('saved_lessons')
                  .orderBy('savedAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty)
                  return const Center(
                    child: EmptyState(
                      title: 'No saved lessons',
                      subtitle: 'Tap the bookmark icon on a lesson.',
                    ),
                  );
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final d = docs[i].data();
                    final lesson = LearnLesson(
                      docs[i].id,
                      (d['categoryId'] ?? '').toString(),
                      (d['title'] ?? '').toString(),
                      (d['summary'] ?? '').toString(),
                      asInt(d['durationMinutes'], 8),
                      (d['level'] ?? 'Intermediate').toString(),
                      i,
                    );
                    return LessonTile(
                      number: i + 1,
                      lesson: lesson,
                      color: LearnColors.cyan,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LearnLessonScreen(lesson: lesson),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}

class LearnCategory {
  final String id, title, subtitle;
  final IconData icon;
  final Color color;
  final int lessonCount;
  const LearnCategory(
    this.id,
    this.title,
    this.subtitle,
    this.icon,
    this.color,
    this.lessonCount,
  );
}

class LearnLesson {
  final String id, categoryId, title, summary, level, content;
  final int durationMinutes, order;
  final List<String> objectives;
  const LearnLesson(
    this.id,
    this.categoryId,
    this.title,
    this.summary,
    this.durationMinutes,
    this.level,
    this.order, {
    this.content = '',
    this.objectives = const [],
  });
  factory LearnLesson.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return LearnLesson(
      doc.id,
      (d['categoryId'] ?? '').toString(),
      (d['title'] ?? 'IELTS Lesson').toString(),
      (d['summary'] ?? '').toString(),
      asInt(d['durationMinutes'], 8),
      (d['level'] ?? 'Intermediate').toString(),
      asInt(d['order']),
      content: (d['content'] ?? '').toString(),
      objectives: d['objectives'] is List
          ? (d['objectives'] as List).map((e) => e.toString()).toList()
          : const [],
    );
  }
}

class LearnColors {
  static const background = Color(0xFF08111F),
      surface = Color(0xFF111C2E),
      border = Color(0xFF25344C),
      text = Color(0xFFF8FAFC),
      secondary = Color(0xFFCBD5E1),
      muted = Color(0xFF94A3B8),
      cyan = Color(0xFF06B6D4),
      blue = Color(0xFF3B82F6),
      violet = Color(0xFF8B5CF6),
      green = Color(0xFF22C55E),
      orange = Color(0xFFF59E0B),
      pink = Color(0xFFEC4899);
}

class DailyGoalCard extends StatelessWidget {
  final int streak, done, goal;
  const DailyGoalCard({
    super.key,
    required this.streak,
    required this.done,
    required this.goal,
  });
  @override
  Widget build(BuildContext context) {
    final g = goal <= 0 ? 1 : goal;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: heroDecoration(),
        child: Column(
          children: [
            Row(
              children: [
                const GradientIcon(icon: Icons.local_fire_department_rounded),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Daily Learning Goal',
                        style: TextStyle(
                          color: LearnColors.text,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$done of $g lessons completed',
                        style: const TextStyle(
                          color: LearnColors.secondary,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$streak 🔥',
                  style: const TextStyle(
                    color: LearnColors.orange,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            LinearProgressIndicator(
              value: (done / g).clamp(0.0, 1.0),
              minHeight: 8,
              borderRadius: BorderRadius.circular(20),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryCard extends StatelessWidget {
  final LearnCategory category;
  final VoidCallback onTap;
  const CategoryCard({super.key, required this.category, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(20),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CourseIcon(icon: category.icon, color: category.color),
          const Spacer(),
          Text(
            category.title,
            maxLines: 2,
            style: const TextStyle(
              color: LearnColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            category.subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LearnColors.muted,
              fontSize: 9,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            '${category.lessonCount} lessons',
            style: TextStyle(
              color: category.color,
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class QuickLesson extends StatelessWidget {
  final LearnLesson lesson;
  final VoidCallback onTap;
  const QuickLesson({super.key, required this.lesson, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 220,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: panelDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.bolt_rounded, color: LearnColors.orange),
            const Spacer(),
            Text(
              lesson.title,
              maxLines: 2,
              style: const TextStyle(
                color: LearnColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Tag('${lesson.durationMinutes} min'),
                const SizedBox(width: 6),
                Tag(lesson.level),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class CategoryHero extends StatelessWidget {
  final LearnCategory category;
  const CategoryHero({super.key, required this.category});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: heroDecoration(),
    child: Row(
      children: [
        CourseIcon(icon: category.icon, color: category.color, size: 58),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category.title,
                style: const TextStyle(
                  color: LearnColors.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                category.subtitle,
                style: const TextStyle(
                  color: LearnColors.secondary,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class LessonTile extends StatelessWidget {
  final int number;
  final LearnLesson lesson;
  final Color color;
  final VoidCallback onTap;
  const LessonTile({
    super.key,
    required this.number,
    required this.lesson,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(17),
    child: Container(
      padding: const EdgeInsets.all(15),
      decoration: panelDecoration(),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(.12),
            child: Text(
              '$number',
              style: TextStyle(color: color, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson.title,
                  style: const TextStyle(
                    color: LearnColors.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${lesson.durationMinutes} min • ${lesson.level}',
                  style: const TextStyle(
                    color: LearnColors.muted,
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: LearnColors.muted,
            size: 15,
          ),
        ],
      ),
    ),
  );
}

class InfoBlock extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> lines;
  const InfoBlock({
    super.key,
    required this.title,
    required this.icon,
    required this.lines,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: panelDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: LearnColors.cyan),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                color: LearnColors.text,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...lines.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '•  $e',
              style: const TextStyle(
                color: LearnColors.secondary,
                height: 1.45,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  final String title, subtitle;
  const SectionTitle({super.key, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: LearnColors.text,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: LearnColors.muted, fontSize: 10),
        ),
      ],
    ),
  );
}

class CourseIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  const CourseIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(.12),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color, size: size * .52),
  );
}

class GradientIcon extends StatelessWidget {
  final IconData icon;
  const GradientIcon({super.key, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
    width: 47,
    height: 47,
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [LearnColors.cyan, LearnColors.blue, LearnColors.violet],
      ),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Icon(icon, color: Colors.white),
  );
}

class Tag extends StatelessWidget {
  final String label;
  const Tag(this.label, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: LearnColors.background,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: LearnColors.border),
    ),
    child: Text(
      label,
      style: const TextStyle(color: LearnColors.secondary, fontSize: 8.5),
    ),
  );
}

class EmptyState extends StatelessWidget {
  final String title, subtitle;
  const EmptyState({
    super.key,
    this.title = 'No lessons found',
    this.subtitle = 'Try another search term.',
  });
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.search_off_rounded, color: LearnColors.cyan, size: 48),
      const SizedBox(height: 12),
      Text(
        title,
        style: const TextStyle(
          color: LearnColors.text,
          fontWeight: FontWeight.w900,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        subtitle,
        textAlign: TextAlign.center,
        style: const TextStyle(color: LearnColors.muted),
      ),
    ],
  );
}

BoxDecoration panelDecoration() => BoxDecoration(
  color: LearnColors.surface,
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: LearnColors.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.12),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ],
);
BoxDecoration heroDecoration() => BoxDecoration(
  gradient: LinearGradient(
    colors: [
      LearnColors.surface,
      LearnColors.cyan.withOpacity(.10),
      LearnColors.violet.withOpacity(.08),
    ],
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: LearnColors.cyan.withOpacity(.24)),
);
int asInt(dynamic v, [int f = 0]) =>
    v is num ? v.round() : int.tryParse(v?.toString() ?? '') ?? f;
String defaultLessonText(LearnLesson lesson) =>
    'This lesson explains ${lesson.title.toLowerCase()} in a clear IELTS-focused way.\n\nStart by identifying what the question is testing. Read or listen to the instruction carefully, note the word limit, and predict the type of information required.\n\nIELTS commonly replaces words from the question with synonyms and paraphrases. Focus on meaning instead of searching only for exact keyword matches.\n\nAfter practice, review why each answer is correct and why the alternatives are incorrect.';

const fallbackLessons = <LearnLesson>[
  LearnLesson(
    'listening_form',
    'listening',
    'Form Completion Strategy',
    'Prediction, spelling and word-limit techniques.',
    8,
    'Intermediate',
    1,
  ),
  LearnLesson(
    'listening_mcq',
    'listening',
    'Listening Multiple Choice',
    'Identify distractors and paraphrased ideas.',
    10,
    'Intermediate',
    2,
  ),
  LearnLesson(
    'reading_skimming',
    'reading',
    'Skimming for Main Ideas',
    'Read faster without losing central meaning.',
    7,
    'Foundation',
    1,
  ),
  LearnLesson(
    'reading_tfn',
    'reading',
    'True, False, Not Given',
    'Separate contradiction from missing information.',
    11,
    'Intermediate',
    2,
  ),
  LearnLesson(
    'writing_overview',
    'writing',
    'Writing a Strong Overview',
    'Report the most important visual trends.',
    12,
    'Intermediate',
    1,
  ),
  LearnLesson(
    'writing_task2',
    'writing',
    'Task 2 Essay Structure',
    'Build clear introductions and body paragraphs.',
    14,
    'Intermediate',
    2,
  ),
  LearnLesson(
    'speaking_part2',
    'speaking',
    'Mastering the Cue Card',
    'Plan in one minute and speak for two minutes.',
    9,
    'Intermediate',
    1,
  ),
  LearnLesson(
    'vocab_collocations',
    'vocabulary',
    'Academic Collocations',
    'Use natural combinations in Writing and Speaking.',
    8,
    'Band 7',
    1,
  ),
  LearnLesson(
    'grammar_complex',
    'grammar',
    'Complex Sentences',
    'Use clauses accurately in IELTS responses.',
    10,
    'Intermediate',
    1,
  ),
];
