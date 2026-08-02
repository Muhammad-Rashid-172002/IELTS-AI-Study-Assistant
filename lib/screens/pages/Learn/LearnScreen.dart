import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';

/// Real-time IELTS Learn Module
///
/// Required packages:
///   firebase_auth
///   cloud_firestore
///   firebase_storage
///
/// Firestore structure:
///
/// learn_courses/{courseId}
///   title: "Listening Course"
///   description: "Master every IELTS listening question type"
///   category: "listening"
///   iconName: "headphones"
///   accentHex: "22D3EE"
///   order: 1
///   isPublished: true
///   totalLessons: 24
///
/// learn_courses/{courseId}/units/{unitId}
///   title: "Listening Foundations"
///   description: "Core listening skills"
///   difficulty: "Foundation"
///   order: 1
///   isPublished: true
///
/// learn_courses/{courseId}/units/{unitId}/lessons/{lessonId}
///   title: "Understanding Form Completion"
///   description: "Learn how to predict and identify answers"
///   lessonType: "text" // text, video, mixed
///   difficulty: "Foundation"
///   durationMinutes: 12
///   order: 1
///   isPublished: true
///   isPremium: false
///   xp: 40
///   content: "Main lesson text..."
///   examples: [
///     {"title": "Example 1", "text": "Sample explanation"}
///   ]
///   miniPractice: [
///     {
///       "question": "Choose the correct answer",
///       "options": ["A", "B", "C"],
///       "correctAnswer": "B",
///       "explanation": "Why B is correct"
///     }
///   ]
///   quiz: [
///     {
///       "question": "Question text",
///       "options": ["A", "B", "C", "D"],
///       "correctAnswer": "A",
///       "explanation": "Explanation"
///     }
///   ]
///   videoUrl: null
///   videoStoragePath: "learn/videos/listening/unit1/lesson1.mp4"
///   thumbnailUrl: null
///   thumbnailStoragePath: "learn/thumbnails/listening_lesson1.jpg"
///
/// User progress:
///
/// users/{uid}/lessonProgress/{lessonId}
///   courseId
///   unitId
///   lessonId
///   completed
///   quizScore
///   earnedXp
///   completedAt
///   updatedAt
///
/// Storage is used only when a lesson has a video, thumbnail, PDF,
/// downloadable file or another media resource. Text-only lessons do not
/// require Firebase Storage.

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearnColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LearnBackground()),
          SafeArea(
            bottom: false,
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('learn_courses')
                  .where('isPublished', isEqualTo: true)
                  .orderBy('order')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _LearnErrorState(
                    message:
                        'Courses could not be loaded. Check Firestore rules and indexes.',
                    onRetry: () {},
                  );
                }

                if (!snapshot.hasData) {
                  return const _LearnLoadingState();
                }

                final courses = snapshot.data!.docs
                    .map(LearnCourse.fromDocument)
                    .toList();

                return _LearnHomeContent(courses: courses);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnHomeContent extends StatelessWidget {
  final List<LearnCourse> courses;

  const _LearnHomeContent({
    required this.courses,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: LearnColors.cyan,
      backgroundColor: LearnColors.surface,
      onRefresh: () async {
        await Future<void>.delayed(
          const Duration(milliseconds: 450),
        );
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: _LearnHeader(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 20, 18, 0),
              child: _LearnHeroCard(),
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 22, 18, 12),
              child: _SectionHeader(
                title: 'IELTS Courses',
                subtitle:
                    'Structured courses from Foundation to Expert',
              ),
            ),
          ),
          if (courses.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyCoursesState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 120),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final course = courses[index];

                    return _CourseCard(
                      course: course,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RealtimeCourseScreen(
                              course: course,
                            ),
                          ),
                        );
                      },
                    );
                  },
                  childCount: courses.length,
                ),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 13,
                  crossAxisSpacing: 13,
                  childAspectRatio: .78,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class RealtimeCourseScreen extends StatelessWidget {
  final LearnCourse course;

  const RealtimeCourseScreen({
    super.key,
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearnColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LearnBackground()),
          SafeArea(
            child: Column(
              children: [
                _InnerHeader(
                  title: course.title,
                  subtitle: 'Choose a level and continue learning',
                  icon: course.icon,
                  accent: course.accent,
                ),
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('learn_courses')
                        .doc(course.id)
                        .collection('units')
                        .where('isPublished', isEqualTo: true)
                        .orderBy('order')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const _InlineError(
                          message:
                              'Units could not be loaded.',
                        );
                      }

                      if (!snapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: LearnColors.cyan,
                          ),
                        );
                      }

                      final units = snapshot.data!.docs
                          .map(
                            (doc) => CourseUnit.fromDocument(
                              doc,
                              courseId: course.id,
                            ),
                          )
                          .toList();

                      if (units.isEmpty) {
                        return const _InlineEmpty(
                          icon: Icons.layers_clear_outlined,
                          title: 'No published units',
                          subtitle:
                              'Add course units in Firestore to show them here.',
                        );
                      }

                      final grouped =
                          _groupUnitsByDifficulty(units);

                      return ListView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(
                          18,
                          8,
                          18,
                          28,
                        ),
                        children: [
                          _CourseOverviewCard(course: course),
                          const SizedBox(height: 18),
                          for (final difficulty
                              in LearnDifficulty.values) ...[
                            if ((grouped[difficulty.label] ?? [])
                                .isNotEmpty) ...[
                              _DifficultyTitle(
                                difficulty: difficulty,
                                unitCount:
                                    grouped[difficulty.label]!
                                        .length,
                              ),
                              const SizedBox(height: 10),
                              ...grouped[difficulty.label]!.map(
                                (unit) => Padding(
                                  padding:
                                      const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  child: _UnitCard(
                                    unit: unit,
                                    course: course,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              RealtimeUnitScreen(
                                            course: course,
                                            unit: unit,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ],
                        ],
                      );
                    },
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

class RealtimeUnitScreen extends StatelessWidget {
  final LearnCourse course;
  final CourseUnit unit;

  const RealtimeUnitScreen({
    super.key,
    required this.course,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: LearnColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LearnBackground()),
          SafeArea(
            child: Column(
              children: [
                _InnerHeader(
                  title: unit.title,
                  subtitle: '${unit.difficulty} • Lessons',
                  icon: Icons.layers_rounded,
                  accent: course.accent,
                ),
                Expanded(
                  child: StreamBuilder<
                      QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('learn_courses')
                        .doc(course.id)
                        .collection('units')
                        .doc(unit.id)
                        .collection('lessons')
                        .where('isPublished', isEqualTo: true)
                        .orderBy('order')
                        .snapshots(),
                    builder: (context, lessonSnapshot) {
                      if (lessonSnapshot.hasError) {
                        return const _InlineError(
                          message:
                              'Lessons could not be loaded.',
                        );
                      }

                      if (!lessonSnapshot.hasData) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: LearnColors.cyan,
                          ),
                        );
                      }

                      final lessons =
                          lessonSnapshot.data!.docs
                              .map(
                                (doc) =>
                                    CourseLesson.fromDocument(
                                  doc,
                                  courseId: course.id,
                                  unitId: unit.id,
                                ),
                              )
                              .toList();

                      if (lessons.isEmpty) {
                        return const _InlineEmpty(
                          icon:
                              Icons.menu_book_outlined,
                          title: 'No published lessons',
                          subtitle:
                              'Add lessons inside this unit in Firestore.',
                        );
                      }

                      if (user == null) {
                        return _LessonList(
                          course: course,
                          unit: unit,
                          lessons: lessons,
                          progress: const {},
                        );
                      }

                      return StreamBuilder<
                          QuerySnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('lessonProgress')
                            .where(
                              'courseId',
                              isEqualTo: course.id,
                            )
                            .where(
                              'unitId',
                              isEqualTo: unit.id,
                            )
                            .snapshots(),
                        builder: (context, progressSnapshot) {
                          final progress = <String,
                              LessonProgress>{};

                          if (progressSnapshot.hasData) {
                            for (final doc
                                in progressSnapshot.data!.docs) {
                              final item =
                                  LessonProgress.fromDocument(
                                doc,
                              );

                              progress[item.lessonId] = item;
                            }
                          }

                          return _LessonList(
                            course: course,
                            unit: unit,
                            lessons: lessons,
                            progress: progress,
                          );
                        },
                      );
                    },
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

class _LessonList extends StatelessWidget {
  final LearnCourse course;
  final CourseUnit unit;
  final List<CourseLesson> lessons;
  final Map<String, LessonProgress> progress;

  const _LessonList({
    required this.course,
    required this.unit,
    required this.lessons,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final completedCount = lessons
        .where(
          (lesson) =>
              progress[lesson.id]?.completed == true,
        )
        .length;

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
      children: [
        _UnitProgressCard(
          unit: unit,
          completedLessons: completedCount,
          totalLessons: lessons.length,
          accent: course.accent,
        ),
        const SizedBox(height: 17),
        ...List.generate(lessons.length, (index) {
          final lesson = lessons[index];
          final lessonProgress = progress[lesson.id];
          final previousCompleted = index == 0 ||
              progress[lessons[index - 1].id]?.completed ==
                  true;
          final locked = !previousCompleted;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LessonCard(
              lesson: lesson,
              index: index,
              accent: course.accent,
              completed:
                  lessonProgress?.completed == true,
              quizScore: lessonProgress?.quizScore,
              locked: locked,
              onTap: () {
                if (locked) {
                  ScaffoldMessenger.of(context)
                    ..hideCurrentSnackBar()
                    ..showSnackBar(
                      const SnackBar(
                        behavior:
                            SnackBarBehavior.floating,
                        content: Text(
                          'Complete the previous lesson first.',
                        ),
                      ),
                    );
                  return;
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        RealtimeLessonScreen(
                      course: course,
                      unit: unit,
                      lesson: lesson,
                    ),
                  ),
                );
              },
            ),
          );
        }),
      ],
    );
  }
}

class RealtimeLessonScreen extends StatefulWidget {
  final LearnCourse course;
  final CourseUnit unit;
  final CourseLesson lesson;

  const RealtimeLessonScreen({
    super.key,
    required this.course,
    required this.unit,
    required this.lesson,
  });

  @override
  State<RealtimeLessonScreen> createState() =>
      _RealtimeLessonScreenState();
}

class _RealtimeLessonScreenState
    extends State<RealtimeLessonScreen> {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? _videoUrl;
  String? _thumbnailUrl;
  bool _resolvingMedia = false;
  bool _saving = false;

  final Map<int, String> _practiceAnswers = {};
  final Map<int, String> _quizAnswers = {};

  @override
  void initState() {
    super.initState();
    _resolveMedia();
  }

  Future<void> _resolveMedia() async {
    setState(() => _resolvingMedia = true);

    try {
      _videoUrl = await _resolveStorageUrl(
        directUrl: widget.lesson.videoUrl,
        storagePath: widget.lesson.videoStoragePath,
      );

      _thumbnailUrl = await _resolveStorageUrl(
        directUrl: widget.lesson.thumbnailUrl,
        storagePath: widget.lesson.thumbnailStoragePath,
      );
    } catch (_) {
      // Text content still works if a media URL cannot be resolved.
    } finally {
      if (mounted) {
        setState(() => _resolvingMedia = false);
      }
    }
  }

  Future<String?> _resolveStorageUrl({
    required String? directUrl,
    required String? storagePath,
  }) async {
    if (directUrl != null && directUrl.isNotEmpty) {
      return directUrl;
    }

    if (storagePath == null || storagePath.isEmpty) {
      return null;
    }

    return _storage.ref(storagePath).getDownloadURL();
  }

  int _calculateQuizScore() {
    if (widget.lesson.quiz.isEmpty) return 100;

    int correct = 0;

    for (int index = 0;
        index < widget.lesson.quiz.length;
        index++) {
      final question = widget.lesson.quiz[index];

      if (_quizAnswers[index] == question.correctAnswer) {
        correct++;
      }
    }

    return ((correct / widget.lesson.quiz.length) * 100)
        .round();
  }

  Future<void> _completeLesson() async {
    final user = _auth.currentUser;

    if (user == null) {
      _showMessage(
        'Sign in to save lesson completion.',
      );
      return;
    }

    final unansweredQuiz = List.generate(
      widget.lesson.quiz.length,
      (index) => index,
    ).where((index) => !_quizAnswers.containsKey(index));

    if (unansweredQuiz.isNotEmpty) {
      _showMessage(
        'Complete the lesson quiz before finishing.',
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final score = _calculateQuizScore();

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('lessonProgress')
          .doc(widget.lesson.id)
          .set({
        'courseId': widget.course.id,
        'unitId': widget.unit.id,
        'lessonId': widget.lesson.id,
        'lessonTitle': widget.lesson.title,
        'difficulty': widget.lesson.difficulty,
        'completed': true,
        'quizScore': score,
        'earnedXp': widget.lesson.xp,
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await _firestore.collection('users').doc(user.uid).set({
        'xpPoints': FieldValue.increment(widget.lesson.xp),
        'lastLearnedLessonId': widget.lesson.id,
        'lastLearnedCourseId': widget.course.id,
        'lastLearningActivityAt':
            FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LessonCompletionScreen(
            lesson: widget.lesson,
            quizScore: score,
            accent: widget.course.accent,
          ),
        ),
      );
    } catch (_) {
      _showMessage(
        'Lesson completion could not be saved.',
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showMessage(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: LearnColors.surfaceLight,
          content: Text(text),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearnColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LearnBackground()),
          SafeArea(
            child: Column(
              children: [
                _InnerHeader(
                  title: widget.lesson.title,
                  subtitle:
                      '${widget.lesson.difficulty} • ${widget.lesson.durationMinutes} min',
                  icon: _lessonTypeIcon(
                    widget.lesson.lessonType,
                  ),
                  accent: widget.course.accent,
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      18,
                      8,
                      18,
                      28,
                    ),
                    children: [
                      _LessonOverview(
                        lesson: widget.lesson,
                        accent: widget.course.accent,
                      ),
                      if (_resolvingMedia) ...[
                        const SizedBox(height: 15),
                        const LinearProgressIndicator(
                          color: LearnColors.cyan,
                          backgroundColor:
                              LearnColors.border,
                        ),
                      ],
                      if (_thumbnailUrl != null ||
                          _videoUrl != null) ...[
                        const SizedBox(height: 16),
                        _MediaLessonCard(
                          thumbnailUrl: _thumbnailUrl,
                          videoUrl: _videoUrl,
                          lessonType:
                              widget.lesson.lessonType,
                          accent: widget.course.accent,
                        ),
                      ],
                      if (widget.lesson.content.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _TextLessonCard(
                          content: widget.lesson.content,
                        ),
                      ],
                      if (widget.lesson.examples.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SectionHeader(
                          title: 'Examples',
                          subtitle:
                              'Study the pattern before practicing',
                        ),
                        const SizedBox(height: 10),
                        ...widget.lesson.examples.map(
                          (example) => Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 11,
                            ),
                            child: _ExampleCard(
                              example: example,
                              accent:
                                  widget.course.accent,
                            ),
                          ),
                        ),
                      ],
                      if (widget
                          .lesson.miniPractice.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SectionHeader(
                          title: 'Mini Practice',
                          subtitle:
                              'Apply the lesson immediately',
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(
                          widget.lesson.miniPractice.length,
                          (index) {
                            final question = widget
                                .lesson.miniPractice[index];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child: _InteractiveQuestionCard(
                                number: index + 1,
                                question: question,
                                selectedAnswer:
                                    _practiceAnswers[index],
                                revealAnswer:
                                    _practiceAnswers
                                        .containsKey(index),
                                accent:
                                    widget.course.accent,
                                onSelected: (answer) {
                                  setState(() {
                                    _practiceAnswers[index] =
                                        answer;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ],
                      if (widget.lesson.quiz.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        const _SectionHeader(
                          title: 'Lesson Quiz',
                          subtitle:
                              'Complete the quiz to finish this lesson',
                        ),
                        const SizedBox(height: 10),
                        ...List.generate(
                          widget.lesson.quiz.length,
                          (index) {
                            final question =
                                widget.lesson.quiz[index];

                            return Padding(
                              padding:
                                  const EdgeInsets.only(
                                bottom: 12,
                              ),
                              child: _InteractiveQuestionCard(
                                number: index + 1,
                                question: question,
                                selectedAnswer:
                                    _quizAnswers[index],
                                revealAnswer: false,
                                accent:
                                    widget.course.accent,
                                onSelected: (answer) {
                                  setState(() {
                                    _quizAnswers[index] =
                                        answer;
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 20),
                      _GradientButton(
                        title: 'Complete Lesson',
                        icon:
                            Icons.check_circle_outline_rounded,
                        isLoading: _saving,
                        onPressed: _completeLesson,
                      ),
                    ],
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

class LessonCompletionScreen extends StatelessWidget {
  final CourseLesson lesson;
  final int quizScore;
  final Color accent;

  const LessonCompletionScreen({
    super.key,
    required this.lesson,
    required this.quizScore,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LearnColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _LearnBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(22),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(27),
                  decoration: _learnCardDecoration(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: LearnColors.success
                              .withOpacity(.13),
                          border: Border.all(
                            color: LearnColors.success
                                .withOpacity(.45),
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.workspace_premium_rounded,
                          color: LearnColors.success,
                          size: 39,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Lesson Completed',
                        style: TextStyle(
                          color: LearnColors.mainText,
                          fontSize: 25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        lesson.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: LearnColors.secondaryText,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _CompletionMetric(
                              label: 'Quiz Score',
                              value: '$quizScore%',
                              accent: accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _CompletionMetric(
                              label: 'XP Earned',
                              value: '+${lesson.xp}',
                              accent: LearnColors.success,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _GradientButton(
                        title: 'Back to Lessons',
                        icon: Icons.arrow_back_rounded,
                        onPressed: () =>
                            Navigator.pop(context),
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

class LearnCourse {
  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color accent;
  final int totalLessons;

  const LearnCourse({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.accent,
    required this.totalLessons,
  });

  factory LearnCourse.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return LearnCourse(
      id: doc.id,
      title: (data['title'] ?? 'IELTS Course').toString(),
      description:
          (data['description'] ?? '').toString(),
      category: (data['category'] ?? doc.id).toString(),
      icon: _iconFromName(
        (data['iconName'] ?? data['category'] ?? '')
            .toString(),
      ),
      accent: _colorFromHex(
        (data['accentHex'] ?? '22D3EE').toString(),
      ),
      totalLessons: _asInt(data['totalLessons']),
    );
  }
}

class CourseUnit {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final String difficulty;
  final int order;

  const CourseUnit({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.difficulty,
    required this.order,
  });

  factory CourseUnit.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String courseId,
  }) {
    final data = doc.data();

    return CourseUnit(
      id: doc.id,
      courseId: courseId,
      title: (data['title'] ?? 'Course Unit').toString(),
      description:
          (data['description'] ?? '').toString(),
      difficulty:
          (data['difficulty'] ?? 'Foundation').toString(),
      order: _asInt(data['order']),
    );
  }
}

class CourseLesson {
  final String id;
  final String courseId;
  final String unitId;
  final String title;
  final String description;
  final String lessonType;
  final String difficulty;
  final int durationMinutes;
  final int xp;
  final bool isPremium;
  final String content;
  final List<LessonExample> examples;
  final List<LessonQuestion> miniPractice;
  final List<LessonQuestion> quiz;
  final String? videoUrl;
  final String? videoStoragePath;
  final String? thumbnailUrl;
  final String? thumbnailStoragePath;

  const CourseLesson({
    required this.id,
    required this.courseId,
    required this.unitId,
    required this.title,
    required this.description,
    required this.lessonType,
    required this.difficulty,
    required this.durationMinutes,
    required this.xp,
    required this.isPremium,
    required this.content,
    required this.examples,
    required this.miniPractice,
    required this.quiz,
    required this.videoUrl,
    required this.videoStoragePath,
    required this.thumbnailUrl,
    required this.thumbnailStoragePath,
  });

  factory CourseLesson.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    required String courseId,
    required String unitId,
  }) {
    final data = doc.data();

    return CourseLesson(
      id: doc.id,
      courseId: courseId,
      unitId: unitId,
      title: (data['title'] ?? 'Lesson').toString(),
      description:
          (data['description'] ?? '').toString(),
      lessonType:
          (data['lessonType'] ?? 'text').toString(),
      difficulty:
          (data['difficulty'] ?? 'Foundation').toString(),
      durationMinutes:
          _asInt(data['durationMinutes'], fallback: 10),
      xp: _asInt(data['xp'], fallback: 25),
      isPremium: data['isPremium'] == true,
      content: (data['content'] ?? '').toString(),
      examples: _asList(data['examples'])
          .map(
            (item) =>
                LessonExample.fromMap(_asMap(item)),
          )
          .toList(),
      miniPractice: _asList(data['miniPractice'])
          .map(
            (item) =>
                LessonQuestion.fromMap(_asMap(item)),
          )
          .toList(),
      quiz: _asList(data['quiz'])
          .map(
            (item) =>
                LessonQuestion.fromMap(_asMap(item)),
          )
          .toList(),
      videoUrl: _nullableString(data['videoUrl']),
      videoStoragePath:
          _nullableString(data['videoStoragePath']),
      thumbnailUrl:
          _nullableString(data['thumbnailUrl']),
      thumbnailStoragePath:
          _nullableString(data['thumbnailStoragePath']),
    );
  }
}

class LessonExample {
  final String title;
  final String text;

  const LessonExample({
    required this.title,
    required this.text,
  });

  factory LessonExample.fromMap(
    Map<String, dynamic> map,
  ) {
    return LessonExample(
      title: (map['title'] ?? 'Example').toString(),
      text: (map['text'] ?? '').toString(),
    );
  }
}

class LessonQuestion {
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  const LessonQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  factory LessonQuestion.fromMap(
    Map<String, dynamic> map,
  ) {
    return LessonQuestion(
      question: (map['question'] ?? '').toString(),
      options: _asList(map['options'])
          .map((item) => item.toString())
          .toList(),
      correctAnswer:
          (map['correctAnswer'] ?? '').toString(),
      explanation:
          (map['explanation'] ?? '').toString(),
    );
  }
}

class LessonProgress {
  final String lessonId;
  final bool completed;
  final int quizScore;

  const LessonProgress({
    required this.lessonId,
    required this.completed,
    required this.quizScore,
  });

  factory LessonProgress.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    return LessonProgress(
      lessonId: (data['lessonId'] ?? doc.id).toString(),
      completed: data['completed'] == true,
      quizScore: _asInt(data['quizScore']),
    );
  }
}

enum LearnDifficulty {
  foundation('Foundation'),
  intermediate('Intermediate'),
  upperIntermediate('Upper Intermediate'),
  advanced('Advanced'),
  expert('Expert');

  final String label;

  const LearnDifficulty(this.label);
}

class _LearnHeader extends StatelessWidget {
  const _LearnHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LearnColors.gradient,
          ),
          child: const Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Learn',
                style: TextStyle(
                  color: LearnColors.mainText,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Structured IELTS courses and lessons',
                style: TextStyle(
                  color: LearnColors.mutedText,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          style: IconButton.styleFrom(
            backgroundColor: LearnColors.surface,
            foregroundColor: LearnColors.mainText,
          ),
          icon: const Icon(Icons.bookmark_border_rounded),
        ),
      ],
    );
  }
}

class _LearnHeroCard extends StatelessWidget {
  const _LearnHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(27),
        gradient: LinearGradient(
          colors: [
            LearnColors.blue.withOpacity(.25),
            LearnColors.cyan.withOpacity(.11),
            LearnColors.violet.withOpacity(.17),
          ],
        ),
        border: Border.all(
          color: LearnColors.cyan.withOpacity(.18),
        ),
      ),
      child: const Row(
        children: [
          _CoursePathRing(),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Complete IELTS Course',
                  style: TextStyle(
                    color: LearnColors.mainText,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Learn through units, lessons, examples, mini practice and quizzes from Foundation to Expert.',
                  style: TextStyle(
                    color: LearnColors.secondaryText,
                    fontSize: 10.7,
                    height: 1.5,
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

class _CoursePathRing extends StatelessWidget {
  const _CoursePathRing();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 78,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            Color(0xFF2563EB),
            Color(0xFF06B6D4),
            Color(0xFF8B5CF6),
            Color(0xFF2563EB),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: LearnColors.cyan.withOpacity(.2),
            blurRadius: 18,
          ),
        ],
      ),
      child: Container(
        width: 65,
        height: 65,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: LearnColors.background,
        ),
        child: const Icon(
          Icons.route_rounded,
          color: LearnColors.cyan,
          size: 28,
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final LearnCourse course;
  final VoidCallback onTap;

  const _CourseCard({
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _learnCardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: course.accent.withOpacity(.13),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      course.icon,
                      color: course.accent,
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    color: LearnColors.subtleText,
                    size: 18,
                  ),
                ],
              ),
              const Spacer(),
              Text(
                course.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LearnColors.mainText,
                  fontSize: 14,
                  height: 1.25,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                course.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LearnColors.mutedText,
                  fontSize: 9.6,
                  height: 1.4,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Icon(
                    Icons.play_lesson_outlined,
                    color: course.accent,
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    course.totalLessons > 0
                        ? '${course.totalLessons} lessons'
                        : 'View course',
                    style: TextStyle(
                      color: course.accent,
                      fontSize: 9.3,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseOverviewCard extends StatelessWidget {
  final LearnCourse course;

  const _CourseOverviewCard({
    required this.course,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            course.accent.withOpacity(.17),
            LearnColors.blue.withOpacity(.09),
          ],
        ),
        border: Border.all(
          color: course.accent.withOpacity(.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 53,
            height: 53,
            decoration: BoxDecoration(
              color: course.accent.withOpacity(.14),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              course.icon,
              color: course.accent,
              size: 27,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Text(
              course.description,
              style: const TextStyle(
                color: LearnColors.secondaryText,
                fontSize: 11.3,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DifficultyTitle extends StatelessWidget {
  final LearnDifficulty difficulty;
  final int unitCount;

  const _DifficultyTitle({
    required this.difficulty,
    required this.unitCount,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _difficultyColor(difficulty.label);

    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: accent.withOpacity(.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(
            _difficultyIcon(difficulty.label),
            color: accent,
            size: 18,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            difficulty.label,
            style: const TextStyle(
              color: LearnColors.mainText,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Text(
          '$unitCount units',
          style: const TextStyle(
            color: LearnColors.mutedText,
            fontSize: 9.5,
          ),
        ),
      ],
    );
  }
}

class _UnitCard extends StatelessWidget {
  final CourseUnit unit;
  final LearnCourse course;
  final VoidCallback onTap;

  const _UnitCard({
    required this.unit,
    required this.course,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final difficultyAccent =
        _difficultyColor(unit.difficulty);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: _learnCardDecoration(),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      difficultyAccent.withOpacity(.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  '${unit.order}',
                  style: TextStyle(
                    color: difficultyAccent,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.title,
                      style: const TextStyle(
                        color: LearnColors.mainText,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (unit.description.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        unit.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: LearnColors.mutedText,
                          fontSize: 10,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: 7),
                    Text(
                      unit.difficulty,
                      style: TextStyle(
                        color: difficultyAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: LearnColors.subtleText,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnitProgressCard extends StatelessWidget {
  final CourseUnit unit;
  final int completedLessons;
  final int totalLessons;
  final Color accent;

  const _UnitProgressCard({
    required this.unit,
    required this.completedLessons,
    required this.totalLessons,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final progress = totalLessons == 0
        ? 0.0
        : completedLessons / totalLessons;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(.17),
            LearnColors.blue.withOpacity(.08),
          ],
        ),
        border: Border.all(
          color: accent.withOpacity(.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  unit.description.isEmpty
                      ? 'Complete every lesson to unlock the next unit.'
                      : unit.description,
                  style: const TextStyle(
                    color: LearnColors.secondaryText,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$completedLessons/$totalLessons',
                style: TextStyle(
                  color: accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: LearnColors.border,
              valueColor:
                  AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  final CourseLesson lesson;
  final int index;
  final Color accent;
  final bool completed;
  final int? quizScore;
  final bool locked;
  final VoidCallback onTap;

  const _LessonCard({
    required this.lesson,
    required this.index,
    required this.accent,
    required this.completed,
    required this.quizScore,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: completed
                ? LearnColors.success.withOpacity(.09)
                : LearnColors.surface.withOpacity(.93),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: completed
                  ? LearnColors.success.withOpacity(.28)
                  : Colors.white.withOpacity(.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 47,
                height: 47,
                decoration: BoxDecoration(
                  color: locked
                      ? LearnColors.border.withOpacity(.7)
                      : accent.withOpacity(.13),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  locked
                      ? Icons.lock_outline_rounded
                      : completed
                          ? Icons.check_rounded
                          : _lessonTypeIcon(
                              lesson.lessonType,
                            ),
                  color: locked
                      ? LearnColors.mutedText
                      : completed
                          ? LearnColors.success
                          : accent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${index + 1}. ${lesson.title}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: completed
                                  ? LearnColors.success
                                  : LearnColors.mainText,
                              fontSize: 12.7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (lesson.isPremium)
                          const Icon(
                            Icons.workspace_premium_rounded,
                            color: Color(0xFFF59E0B),
                            size: 16,
                          ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      lesson.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: LearnColors.mutedText,
                        fontSize: 9.8,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          color: LearnColors.subtleText,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${lesson.durationMinutes} min',
                          style: const TextStyle(
                            color: LearnColors.subtleText,
                            fontSize: 8.8,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.bolt_rounded,
                          color: accent,
                          size: 14,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${lesson.xp} XP',
                          style: TextStyle(
                            color: accent,
                            fontSize: 8.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (quizScore != null) ...[
                          const Spacer(),
                          Text(
                            '$quizScore%',
                            style: const TextStyle(
                              color: LearnColors.success,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: LearnColors.subtleText,
                size: 15,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonOverview extends StatelessWidget {
  final CourseLesson lesson;
  final Color accent;

  const _LessonOverview({
    required this.lesson,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            accent.withOpacity(.17),
            LearnColors.violet.withOpacity(.08),
          ],
        ),
        border: Border.all(
          color: accent.withOpacity(.18),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            lesson.description,
            style: const TextStyle(
              color: LearnColors.secondaryText,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LessonBadge(
                icon: Icons.schedule_rounded,
                text: '${lesson.durationMinutes} min',
                accent: accent,
              ),
              _LessonBadge(
                icon: Icons.bolt_rounded,
                text: '${lesson.xp} XP',
                accent: accent,
              ),
              _LessonBadge(
                icon: _difficultyIcon(
                  lesson.difficulty,
                ),
                text: lesson.difficulty,
                accent:
                    _difficultyColor(lesson.difficulty),
              ),
              _LessonBadge(
                icon: _lessonTypeIcon(
                  lesson.lessonType,
                ),
                text: lesson.lessonType.toUpperCase(),
                accent: accent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LessonBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accent;

  const _LessonBadge({
    required this.icon,
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: accent.withOpacity(.1),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: accent,
              fontSize: 8.8,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaLessonCard extends StatelessWidget {
  final String? thumbnailUrl;
  final String? videoUrl;
  final String lessonType;
  final Color accent;

  const _MediaLessonCard({
    required this.thumbnailUrl,
    required this.videoUrl,
    required this.lessonType,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 205,
      decoration: BoxDecoration(
        color: LearnColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Colors.white.withOpacity(.07),
        ),
        image: thumbnailUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(thumbnailUrl!),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withOpacity(.35),
                  BlendMode.darken,
                ),
              ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (thumbnailUrl == null)
            Icon(
              lessonType.toLowerCase() == 'video'
                  ? Icons.video_library_outlined
                  : Icons.play_lesson_outlined,
              color: accent.withOpacity(.55),
              size: 70,
            ),
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LearnColors.gradient,
              boxShadow: [
                BoxShadow(
                  color: LearnColors.cyan.withOpacity(.25),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              videoUrl == null
                  ? Icons.image_outlined
                  : Icons.play_arrow_rounded,
              color: Colors.white,
              size: 31,
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 13,
            child: Text(
              videoUrl == null
                  ? 'Lesson visual'
                  : 'Video resource ready • Connect your preferred video player package',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TextLessonCard extends StatelessWidget {
  final String content;

  const _TextLessonCard({
    required this.content,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _learnCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.article_outlined,
                color: LearnColors.cyan,
                size: 21,
              ),
              SizedBox(width: 8),
              Text(
                'Lesson',
                style: TextStyle(
                  color: LearnColors.mainText,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          SelectableText(
            content,
            style: const TextStyle(
              color: LearnColors.secondaryText,
              fontSize: 12.4,
              height: 1.65,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  final LessonExample example;
  final Color accent;

  const _ExampleCard({
    required this.example,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: _learnCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            example.title,
            style: TextStyle(
              color: accent,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            example.text,
            style: const TextStyle(
              color: LearnColors.secondaryText,
              fontSize: 11.3,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractiveQuestionCard extends StatelessWidget {
  final int number;
  final LessonQuestion question;
  final String? selectedAnswer;
  final bool revealAnswer;
  final Color accent;
  final ValueChanged<String> onSelected;

  const _InteractiveQuestionCard({
    required this.number,
    required this.question,
    required this.selectedAnswer,
    required this.revealAnswer,
    required this.accent,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isCorrect =
        selectedAnswer == question.correctAnswer;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _learnCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: accent.withOpacity(.14),
                ),
                child: Text(
                  '$number',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(
                    color: LearnColors.mainText,
                    fontSize: 12.3,
                    height: 1.45,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ...question.options.map((option) {
            final selected = selectedAnswer == option;
            final showCorrect =
                revealAnswer &&
                    option == question.correctAnswer;
            final showWrong =
                revealAnswer && selected && !showCorrect;

            Color borderColor =
                Colors.white.withOpacity(.06);
            Color fillColor =
                LearnColors.background.withOpacity(.35);
            Color textColor =
                LearnColors.secondaryText;

            if (selected) {
              borderColor = accent.withOpacity(.6);
              fillColor = accent.withOpacity(.12);
              textColor = accent;
            }

            if (showCorrect) {
              borderColor =
                  LearnColors.success.withOpacity(.6);
              fillColor =
                  LearnColors.success.withOpacity(.1);
              textColor = LearnColors.success;
            }

            if (showWrong) {
              borderColor = Colors.redAccent.withOpacity(.6);
              fillColor =
                  Colors.redAccent.withOpacity(.1);
              textColor = Colors.redAccent;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onSelected(option),
                  borderRadius:
                      BorderRadius.circular(14),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: fillColor,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: borderColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            option,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11.2,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),
                        ),
                        if (selected ||
                            showCorrect ||
                            showWrong)
                          Icon(
                            showCorrect
                                ? Icons.check_circle_rounded
                                : showWrong
                                    ? Icons.cancel_rounded
                                    : Icons
                                        .radio_button_checked_rounded,
                            color: textColor,
                            size: 18,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
          if (revealAnswer &&
              selectedAnswer != null) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isCorrect
                        ? LearnColors.success
                        : Colors.redAccent)
                    .withOpacity(.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                question.explanation.isEmpty
                    ? isCorrect
                        ? 'Correct answer.'
                        : 'Correct answer: ${question.correctAnswer}'
                    : question.explanation,
                style: TextStyle(
                  color: isCorrect
                      ? LearnColors.success
                      : LearnColors.secondaryText,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CompletionMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _CompletionMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 15,
      ),
      decoration: BoxDecoration(
        color: accent.withOpacity(.1),
        borderRadius: BorderRadius.circular(17),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: LearnColors.mutedText,
              fontSize: 9.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InnerHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;

  const _InnerHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 18, 13),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(
              backgroundColor: LearnColors.surface,
              foregroundColor: LearnColors.mainText,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withOpacity(.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LearnColors.mainText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LearnColors.mutedText,
                    fontSize: 10,
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

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: LearnColors.mainText,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: LearnColors.mutedText,
            fontSize: 10.5,
          ),
        ),
      ],
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _GradientButton({
    required this.title,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: LearnColors.gradient,
          boxShadow: [
            BoxShadow(
              color: LearnColors.blue.withOpacity(.25),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 23,
                  height: 23,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.3,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, size: 20),
                  ],
                ),
        ),
      ),
    );
  }
}

class _EmptyCoursesState extends StatelessWidget {
  const _EmptyCoursesState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _InlineEmpty(
        icon: Icons.auto_stories_outlined,
        title: 'No published courses',
        subtitle:
            'Add documents to the learn_courses collection.',
      ),
    );
  }
}

class _InlineEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InlineEmpty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: LearnColors.subtleText,
            size: 47,
          ),
          const SizedBox(height: 15),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: LearnColors.mainText,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: LearnColors.mutedText,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.redAccent,
            fontSize: 13,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}

class _LearnLoadingState extends StatelessWidget {
  const _LearnLoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        color: LearnColors.cyan,
      ),
    );
  }
}

class _LearnErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _LearnErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              color: Colors.redAccent,
              size: 47,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: LearnColors.mainText,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LearnBackground extends StatelessWidget {
  const _LearnBackground();

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
            ),
          ),
        ),
        const Positioned(
          top: -150,
          right: -120,
          child: _Glow(
            size: 340,
            color: Color(0x2B2563EB),
          ),
        ),
        const Positioned(
          top: 380,
          left: -160,
          child: _Glow(
            size: 320,
            color: Color(0x1706B6D4),
          ),
        ),
        const Positioned(
          bottom: -180,
          right: -150,
          child: _Glow(
            size: 390,
            color: Color(0x178B5CF6),
          ),
        ),
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  final double size;
  final Color color;

  const _Glow({
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0),
            ],
          ),
        ),
      ),
    );
  }
}

class LearnColors {
  static const background = Color(0xFF07111F);
  static const surface = Color(0xFF101C2E);
  static const surfaceLight = Color(0xFF182A40);
  static const mainText = Color(0xFFF8FAFC);
  static const secondaryText = Color(0xFFCBD5E1);
  static const mutedText = Color(0xFF94A3B8);
  static const subtleText = Color(0xFF64748B);
  static const border = Color(0xFF26364A);
  static const blue = Color(0xFF2563EB);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF8B5CF6);
  static const success = Color(0xFF34D399);

  static const gradient = LinearGradient(
    colors: [
      Color(0xFF2563EB),
      Color(0xFF06B6D4),
      Color(0xFF7C3AED),
    ],
  );
}

BoxDecoration _learnCardDecoration() {
  return BoxDecoration(
    color: LearnColors.surface.withOpacity(.92),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(
      color: Colors.white.withOpacity(.065),
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(.14),
        blurRadius: 17,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

Map<String, List<CourseUnit>> _groupUnitsByDifficulty(
  List<CourseUnit> units,
) {
  final result = <String, List<CourseUnit>>{};

  for (final difficulty in LearnDifficulty.values) {
    result[difficulty.label] = [];
  }

  for (final unit in units) {
    result.putIfAbsent(unit.difficulty, () => []);
    result[unit.difficulty]!.add(unit);
  }

  return result;
}

IconData _iconFromName(String value) {
  switch (value.toLowerCase()) {
    case 'listening':
    case 'headphones':
      return Icons.headphones_rounded;
    case 'reading':
    case 'book':
      return Icons.menu_book_rounded;
    case 'writing':
    case 'edit':
      return Icons.edit_note_rounded;
    case 'speaking':
    case 'mic':
      return Icons.mic_rounded;
    case 'grammar':
      return Icons.spellcheck_rounded;
    case 'vocabulary':
      return Icons.translate_rounded;
    case 'exam strategies':
    case 'strategy':
      return Icons.psychology_alt_rounded;
    default:
      return Icons.auto_stories_rounded;
  }
}

IconData _lessonTypeIcon(String type) {
  switch (type.toLowerCase()) {
    case 'video':
      return Icons.play_circle_outline_rounded;
    case 'mixed':
      return Icons.dashboard_customize_outlined;
    case 'audio':
      return Icons.headphones_rounded;
    default:
      return Icons.article_outlined;
  }
}

IconData _difficultyIcon(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'foundation':
      return Icons.foundation_rounded;
    case 'intermediate':
      return Icons.trending_up_rounded;
    case 'upper intermediate':
      return Icons.stairs_rounded;
    case 'advanced':
      return Icons.rocket_launch_outlined;
    case 'expert':
      return Icons.workspace_premium_outlined;
    default:
      return Icons.school_outlined;
  }
}

Color _difficultyColor(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'foundation':
      return const Color(0xFF22D3EE);
    case 'intermediate':
      return const Color(0xFF60A5FA);
    case 'upper intermediate':
      return const Color(0xFF8B5CF6);
    case 'advanced':
      return const Color(0xFFF59E0B);
    case 'expert':
      return const Color(0xFF34D399);
    default:
      return LearnColors.cyan;
  }
}

Color _colorFromHex(String value) {
  var hex = value
      .replaceAll('#', '')
      .replaceAll('0x', '')
      .trim();

  if (hex.length == 6) {
    hex = 'FF$hex';
  }

  return Color(
    int.tryParse(hex, radix: 16) ?? 0xFF22D3EE,
  );
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }

  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }

  return <String, dynamic>{};
}

List<dynamic> _asList(dynamic value) {
  return value is List ? value : const [];
}

int _asInt(
  dynamic value, {
  int fallback = 0,
}) {
  if (value is num) {
    return value.toInt();
  }

  return int.tryParse(value?.toString() ?? '') ??
      fallback;
}

String? _nullableString(dynamic value) {
  final text = value?.toString().trim();

  if (text == null ||
      text.isEmpty ||
      text.toLowerCase() == 'null') {
    return null;
  }

  return text;
}
