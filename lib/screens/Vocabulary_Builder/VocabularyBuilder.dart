import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fyproject/offline/offline_content_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fyproject/screens/content_queue_service.dart';
import 'package:fyproject/resources/components/learner_state_view.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen> {
  final _repo = VocabularyRepository();
  final _search = TextEditingController();

  String _category = 'all';
  String _query = '';

  static const categories = [
    VCategory('Academic vocabulary', 'academic', Icons.school_outlined),
    VCategory('Topic vocabulary', 'topic', Icons.category_outlined),
    VCategory('Band 5 words', 'band_5', Icons.filter_5_outlined),
    VCategory('Band 6 words', 'band_6', Icons.filter_6_outlined),
    VCategory('Band 7 words', 'band_7', Icons.filter_7_outlined),
    VCategory('Band 8–9 words', 'band_8_9', Icons.workspace_premium_outlined),
    VCategory('Collocations', 'collocations', Icons.hub_outlined),
    VCategory('Phrasal verbs', 'phrasal_verbs', Icons.alt_route_rounded),
    VCategory('Synonyms', 'synonyms', Icons.compare_arrows_rounded),
    VCategory('Spelling mistakes', 'spelling', Icons.spellcheck_rounded),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColors.bg,
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _header()),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                    child: _ProgressCard(
                      userId: FirebaseAuth.instance.currentUser?.uid,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: _Title(
                    title: 'Learning System',
                    subtitle: 'Review, practise and master IELTS vocabulary',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final tool = VTool.values[index];
                      return _ToolCard(
                        tool: tool,
                        onTap: () => _openTool(tool),
                      );
                    }, childCount: VTool.values.length),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 11,
                          crossAxisSpacing: 11,
                          mainAxisExtent: 140,
                        ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: _Title(
                    title: 'Vocabulary Categories',
                    subtitle: 'Choose a band, word type or IELTS topic',
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 112,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      itemCount: categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 9),
                      itemBuilder: (context, index) {
                        final item = categories[index];
                        final selected = _category == item.value;
                        return _CategoryCard(
                          item: item,
                          selected: selected,
                          onTap: () {
                            setState(() {
                              _category = selected ? 'all' : item.value;
                            });
                          },
                        );
                      },
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 22, 18, 11),
                    child: Row(
                      children: [
                        const Expanded(
                          child: _SectionLabel(
                            title: 'Vocabulary Cards',
                            subtitle: 'Tap a word to see full details',
                          ),
                        ),
                        if (_category != 'all')
                          TextButton(
                            onPressed: () => setState(() => _category = 'all'),
                            child: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: StreamBuilder<List<VWord>>(
                    stream: _repo.watchWords(category: _category),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return LearnerStateView.error(
                          title: 'Vocabulary could not be refreshed',
                          message:
                              'Your saved words and mastery progress are safe. Check your connection and try again.',
                          icon: Icons.translate_rounded,
                          onAction: () => setState(() {}),
                        );
                      }
                      if (!snapshot.hasData) {
                        return const LearnerStateView.loading(
                          title: 'Curating your vocabulary',
                          message:
                              'Finding the best next words for your band and learning history.',
                          icon: Icons.translate_rounded,
                        );
                      }

                      final words = snapshot.data!.where((word) {
                        if (_query.isEmpty) return true;
                        return word.searchText.contains(_query);
                      }).toList();

                      if (words.isEmpty) {
                        return const _StateView(
                          icon: Icons.search_off_rounded,
                          title: 'No new vocabulary available',
                          subtitle:
                              'Completed words are hidden. New words will appear when the administrator publishes them.',
                        );
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 110),
                        itemCount: words.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final word = words[index];
                          return _WordCard(
                            word: word,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VocabularyWordScreen(
                                  word: word,
                                  cyclePoolKey: _category == 'all'
                                      ? 'all'
                                      : 'category_${_safeVocabularyCycleKey(_category)}',
                                ),
                              ),
                            ),
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

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
      child: Column(
        children: [
          const Row(
            children: [
              _GradientIcon(icon: Icons.translate_rounded),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vocabulary',
                      style: TextStyle(
                        color: VColors.text,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Build precise vocabulary for every IELTS module',
                      style: TextStyle(color: VColors.muted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          TextField(
            controller: _search,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            style: const TextStyle(color: VColors.text),
            decoration: const InputDecoration(
              hintText: 'Search word, meaning, topic or synonym...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ],
      ),
    );
  }

  void _openTool(VTool tool) {
    final page = switch (tool) {
      VTool.flashcards => const FlashcardsScreen(),
      VTool.daily => const DailyWordsScreen(),
      VTool.quiz => const VocabularyQuizScreen(),
      VTool.spelling => const SpellingQuizScreen(),
      VTool.match => const MatchWordsScreen(),
      VTool.sentence => const SentenceCompletionScreen(),
      VTool.learned => const WordCollectionScreen(
        title: 'Learned Words',
        filter: 'learned',
      ),
      VTool.mastered => const WordCollectionScreen(
        title: 'Mastered Words',
        filter: 'mastered',
      ),
      VTool.saved => const WordCollectionScreen(
        title: 'Saved Words',
        filter: 'saved',
      ),
    };

    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }
}

class VocabularyWordScreen extends StatefulWidget {
  final VWord word;
  final String cyclePoolKey;

  const VocabularyWordScreen({
    super.key,
    required this.word,
    this.cyclePoolKey = 'all',
  });

  @override
  State<VocabularyWordScreen> createState() => _VocabularyWordScreenState();
}

class _VocabularyWordScreenState extends State<VocabularyWordScreen> {
  final _tts = FlutterTts();
  final _repo = VocabularyRepository();
  bool _speaking = false;

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak() async {
    if (_speaking) {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
      return;
    }

    await _tts.setLanguage('en-GB');
    await _tts.setSpeechRate(.42);
    if (mounted) setState(() => _speaking = true);
    await _tts.speak(widget.word.word);
    if (mounted) setState(() => _speaking = false);
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: VColors.bg,
      appBar: AppBar(
        backgroundColor: VColors.bg,
        title: const Text('Vocabulary Card'),
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 35),
            children: [
              Container(
                padding: const EdgeInsets.all(21),
                decoration: heroDecoration(),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.word.word,
                            style: const TextStyle(
                              color: VColors.text,
                              fontSize: 29,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        IconButton.filled(
                          onPressed: _speak,
                          icon: Icon(
                            _speaking
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          widget.word.pronunciation,
                          style: const TextStyle(
                            color: VColors.cyan,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        _Badge(widget.word.partOfSpeech),
                        const SizedBox(width: 7),
                        _Badge(widget.word.band),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _Detail('Meaning', Icons.menu_book_outlined, widget.word.meaning),
              if (widget.word.translation.isNotEmpty) ...[
                const SizedBox(height: 12),
                _Detail(
                  'Translation',
                  Icons.translate_rounded,
                  widget.word.translation,
                ),
              ],
              const SizedBox(height: 12),
              _Detail(
                'Example Sentence',
                Icons.format_quote_rounded,
                widget.word.example,
              ),
              const SizedBox(height: 12),
              _TagSection(
                title: 'Synonyms',
                icon: Icons.compare_arrows_rounded,
                items: widget.word.synonyms,
              ),
              const SizedBox(height: 12),
              _TagSection(
                title: 'Collocations',
                icon: Icons.hub_outlined,
                items: widget.word.collocations,
              ),
              const SizedBox(height: 12),
              _Detail('IELTS Topic', Icons.topic_outlined, widget.word.topic),
              if (uid != null) ...[
                const SizedBox(height: 16),
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid)
                      .collection('vocabulary_progress')
                      .doc(widget.word.id)
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data() ?? {};
                    final saved = data['isSaved'] == true;
                    final status = (data['status'] ?? 'new').toString();

                    return Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                _repo.toggleSaved(uid, widget.word, !saved),
                            icon: Icon(
                              saved
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_border_rounded,
                            ),
                            label: Text(saved ? 'Saved Word' : 'Save Word'),
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _repo.markStatus(
                                  uid,
                                  widget.word,
                                  'learned',
                                  7,
                                  cyclePoolKey: widget.cyclePoolKey,
                                ),
                                icon: Icon(
                                  status == 'learned'
                                      ? Icons.check_circle_rounded
                                      : Icons.check_circle_outline_rounded,
                                ),
                                label: const Text('Learned'),
                              ),
                            ),
                            const SizedBox(width: 9),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _repo.markStatus(
                                  uid,
                                  widget.word,
                                  'mastered',
                                  30,
                                  cyclePoolKey: widget.cyclePoolKey,
                                ),
                                icon: Icon(
                                  status == 'mastered'
                                      ? Icons.workspace_premium_rounded
                                      : Icons.workspace_premium_outlined,
                                ),
                                label: const Text('Mastered'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final _repo = VocabularyRepository();

  List<VWord> words = [];
  int index = 0;
  bool loading = true;
  bool showAnswer = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    words = await _repo.loadReviewWords();
    if (mounted) setState(() => loading = false);
  }

  Future<void> _rate(int rating) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null && words.isNotEmpty) {
      await _repo.review(uid, words[index], rating);
    }

    if (!mounted) return;
    setState(() {
      showAnswer = false;
      index = index + 1 < words.length ? index + 1 : 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: 'Flashcards',
      child: loading
          ? const _VocabularyLoadingView()
          : words.isEmpty
          ? const _StateView(
              icon: Icons.style_outlined,
              title: 'No review words',
              subtitle: 'Save or learn some words first.',
            )
          : Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '${index + 1}/${words.length}',
                        style: const TextStyle(color: VColors.muted),
                      ),
                      const Spacer(),
                      const _Badge('SPACED REPETITION'),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => showAnswer = !showAnswer),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: heroDecoration(),
                        child: showAnswer
                            ? ListView(
                                children: [
                                  Text(
                                    words[index].word,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: VColors.text,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  _MiniPanel('Meaning', words[index].meaning),
                                  _MiniPanel('Example', words[index].example),
                                  _MiniPanel(
                                    'Synonyms',
                                    words[index].synonyms.join(', '),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    words[index].word,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: VColors.text,
                                      fontSize: 34,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 9),
                                  Text(
                                    words[index].pronunciation,
                                    style: const TextStyle(
                                      color: VColors.cyan,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  const Text(
                                    'Tap to show the answer',
                                    style: TextStyle(color: VColors.muted),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (showAnswer)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rate(1),
                            child: const Text('Again'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _rate(3),
                            child: const Text('Good'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: () => _rate(5),
                            child: const Text('Easy'),
                          ),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => setState(() => showAnswer = true),
                        child: const Text('Show Answer'),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class DailyWordsScreen extends StatelessWidget {
  const DailyWordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: 'Daily Words',
      child: FutureBuilder<List<VWord>>(
        future: VocabularyRepository().loadWords(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const _VocabularyLoadingView();
          }

          final all = snapshot.data!;
          if (all.isEmpty) {
            return const _StateView(
              icon: Icons.today_outlined,
              title: 'No daily words',
              subtitle: 'Publish vocabulary words from admin.',
            );
          }

          final seed = DateTime.now()
              .difference(DateTime(DateTime.now().year, 1, 1))
              .inDays;
          final count = math.min(5, all.length);
          final words = List.generate(
            count,
            (index) => all[(seed + index) % all.length],
          );

          return ListView.separated(
            padding: const EdgeInsets.all(18),
            itemCount: words.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final word = words[index];
              return _WordCard(
                word: word,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VocabularyWordScreen(word: word),
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

class VocabularyQuizScreen extends StatelessWidget {
  const VocabularyQuizScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MultipleChoicePractice(
      title: 'Vocabulary Quiz',
      mode: PracticeMode.meaning,
    );
  }
}

class SentenceCompletionScreen extends StatelessWidget {
  const SentenceCompletionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _MultipleChoicePractice(
      title: 'Sentence Completion',
      mode: PracticeMode.sentence,
    );
  }
}

enum PracticeMode { meaning, sentence }

class _MultipleChoicePractice extends StatefulWidget {
  final String title;
  final PracticeMode mode;

  const _MultipleChoicePractice({required this.title, required this.mode});

  @override
  State<_MultipleChoicePractice> createState() =>
      _MultipleChoicePracticeState();
}

class _MultipleChoicePracticeState extends State<_MultipleChoicePractice> {
  List<VWord> words = [];
  int index = 0;
  int score = 0;
  bool loading = true;
  String? selected;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await VocabularyRepository().loadWords();
    loaded.shuffle();

    if (mounted) {
      setState(() {
        words = loaded.take(12).toList();
        loading = false;
      });
    }
  }

  List<String> get options {
    if (words.length < 4) return [];
    final current = words[index];
    final source = widget.mode == PracticeMode.meaning
        ? words.map((word) => word.meaning).toList()
        : words.map((word) => word.word).toList();

    final correct = widget.mode == PracticeMode.meaning
        ? current.meaning
        : current.word;

    source.remove(correct);
    source.shuffle();
    return [correct, ...source.take(3)]..shuffle();
  }

  String get prompt {
    final current = words[index];
    if (widget.mode == PracticeMode.meaning) {
      return current.word;
    }

    final pattern = RegExp(RegExp.escape(current.word), caseSensitive: false);
    return current.example.replaceAll(pattern, '________');
  }

  String get correctAnswer => widget.mode == PracticeMode.meaning
      ? words[index].meaning
      : words[index].word;

  void _answer(String value) {
    if (selected != null) return;

    setState(() {
      selected = value;
      if (value == correctAnswer) score++;
    });

    Timer(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      if (index + 1 < words.length) {
        setState(() {
          index++;
          selected = null;
        });
      } else {
        _finish();
      }
    });
  }

  void _finish() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: VColors.surface,
        title: const Text(
          'Practice Complete',
          style: TextStyle(color: VColors.text),
        ),
        content: Text(
          'You scored $score out of ${words.length}.',
          style: const TextStyle(color: VColors.secondary),
        ),
        actions: [
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: widget.title,
      child: loading
          ? const _VocabularyLoadingView()
          : words.length < 4
          ? const _StateView(
              icon: Icons.quiz_outlined,
              title: 'Not enough words',
              subtitle: 'At least four published words are required.',
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Text(
                      '${index + 1}/${words.length}',
                      style: const TextStyle(color: VColors.muted),
                    ),
                    const Spacer(),
                    _Badge('Score $score'),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: heroDecoration(),
                  child: Text(
                    prompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: VColors.text,
                      fontSize: 22,
                      height: 1.55,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                ...options.map((option) {
                  final correct = option == correctAnswer;
                  final active = option == selected;
                  var border = VColors.border;
                  var background = VColors.surface;

                  if (selected != null && correct) {
                    border = VColors.green;
                    background = VColors.green.withOpacity(.1);
                  } else if (active && !correct) {
                    border = Colors.redAccent;
                    background = Colors.redAccent.withOpacity(.1);
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: InkWell(
                      onTap: () => _answer(option),
                      borderRadius: BorderRadius.circular(15),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: background,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: border),
                        ),
                        child: Text(
                          option,
                          style: const TextStyle(
                            color: VColors.text,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}

class SpellingQuizScreen extends StatefulWidget {
  const SpellingQuizScreen({super.key});

  @override
  State<SpellingQuizScreen> createState() => _SpellingQuizScreenState();
}

class _SpellingQuizScreenState extends State<SpellingQuizScreen> {
  final tts = FlutterTts();
  final answer = TextEditingController();

  List<VWord> words = [];
  int index = 0;
  int score = 0;
  bool loading = true;
  String? feedback;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    tts.stop();
    answer.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    words = await VocabularyRepository().loadWords();
    words.shuffle();
    words = words.take(10).toList();

    if (mounted) setState(() => loading = false);
    if (words.isNotEmpty) _play();
  }

  Future<void> _play() async {
    await tts.setLanguage('en-GB');
    await tts.setSpeechRate(.38);
    await tts.speak(words[index].word);
  }

  void _check() {
    final correct =
        answer.text.trim().toLowerCase() == words[index].word.toLowerCase();

    setState(() {
      if (correct) score++;
      feedback = correct ? 'Correct' : 'Correct: ${words[index].word}';
    });

    Timer(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      if (index + 1 < words.length) {
        setState(() {
          index++;
          answer.clear();
          feedback = null;
        });
        _play();
      } else {
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: 'Listening Spelling Quiz',
      child: loading
          ? const _VocabularyLoadingView()
          : words.isEmpty
          ? const _StateView(
              icon: Icons.hearing_outlined,
              title: 'No words available',
              subtitle: 'Publish vocabulary words first.',
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Row(
                  children: [
                    Text(
                      '${index + 1}/${words.length}',
                      style: const TextStyle(color: VColors.muted),
                    ),
                    const Spacer(),
                    _Badge('Score $score'),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: heroDecoration(),
                  child: Column(
                    children: [
                      const Text(
                        'Listen and type the word',
                        style: TextStyle(color: VColors.secondary),
                      ),
                      const SizedBox(height: 18),
                      IconButton.filled(
                        onPressed: _play,
                        iconSize: 34,
                        icon: const Icon(Icons.volume_up_rounded),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        words[index].meaning,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: VColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: answer,
                  onSubmitted: (_) => _check(),
                  decoration: const InputDecoration(
                    labelText: 'Type the spelling',
                    prefixIcon: Icon(Icons.spellcheck_rounded),
                  ),
                ),
                if (feedback != null) ...[
                  const SizedBox(height: 11),
                  Text(
                    feedback!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: feedback == 'Correct'
                          ? VColors.green
                          : VColors.warning,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: feedback == null ? _check : null,
                  child: const Text('Check Spelling'),
                ),
              ],
            ),
    );
  }
}

class MatchWordsScreen extends StatefulWidget {
  const MatchWordsScreen({super.key});

  @override
  State<MatchWordsScreen> createState() => _MatchWordsScreenState();
}

class _MatchWordsScreenState extends State<MatchWordsScreen> {
  List<VWord> words = [];
  List<String> meanings = [];
  final matched = <String>{};

  String? selectedWord;
  String? selectedMeaning;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final loaded = await VocabularyRepository().loadWords();
    loaded.shuffle();
    words = loaded.take(6).toList();
    meanings = words.map((e) => e.meaning).toList()..shuffle();

    if (mounted) setState(() => loading = false);
  }

  void _check() {
    if (selectedWord == null || selectedMeaning == null) return;

    final word = words.firstWhere((item) => item.id == selectedWord);

    if (word.meaning == selectedMeaning) {
      setState(() {
        matched.add(word.id);
        selectedWord = null;
        selectedMeaning = null;
      });
    } else {
      setState(() {
        selectedWord = null;
        selectedMeaning = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ToolScaffold(
      title: 'Match Words',
      child: loading
          ? const _VocabularyLoadingView()
          : words.isEmpty
          ? const _StateView(
              icon: Icons.compare_arrows_rounded,
              title: 'No words available',
              subtitle: 'Publish vocabulary words first.',
            )
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                const _SectionLabel(
                  title: 'Match words with meanings',
                  subtitle: 'Select one item from each side',
                ),
                const SizedBox(height: 15),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: words.map((word) {
                          return _MatchTile(
                            text: word.word,
                            selected: selectedWord == word.id,
                            matched: matched.contains(word.id),
                            onTap: matched.contains(word.id)
                                ? null
                                : () {
                                    setState(() {
                                      selectedWord = word.id;
                                    });
                                    _check();
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        children: meanings.map((meaning) {
                          final isMatched = words.any(
                            (word) =>
                                word.meaning == meaning &&
                                matched.contains(word.id),
                          );
                          return _MatchTile(
                            text: meaning,
                            selected: selectedMeaning == meaning,
                            matched: isMatched,
                            onTap: isMatched
                                ? null
                                : () {
                                    setState(() {
                                      selectedMeaning = meaning;
                                    });
                                    _check();
                                  },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class WordCollectionScreen extends StatelessWidget {
  final String title;
  final String filter;

  const WordCollectionScreen({
    super.key,
    required this.title,
    required this.filter,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return _ToolScaffold(
      title: title,
      child: uid == null
          ? const _StateView(
              icon: Icons.lock_outline_rounded,
              title: 'Sign in required',
              subtitle: 'Sign in to view your vocabulary collection.',
            )
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .collection('vocabulary_progress')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const _VocabularyLoadingView();
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data();
                  return filter == 'saved'
                      ? data['isSaved'] == true
                      : data['status'] == filter;
                }).toList();

                if (docs.isEmpty) {
                  return _StateView(
                    icon: Icons.bookmark_border_rounded,
                    title: 'No $title',
                    subtitle: 'Marked words will appear here.',
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(18),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final map = data['wordData'] is Map
                        ? Map<String, dynamic>.from(data['wordData'])
                        : <String, dynamic>{};
                    final word = VWord.fromMap(map, id: docs[index].id);

                    return _WordCard(
                      word: word,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VocabularyWordScreen(word: word),
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

String _safeVocabularyCycleKey(String value) {
  final cleaned = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return cleaned.isEmpty ? 'all' : cleaned;
}

int _asIntV(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

List<String> _stringListV(dynamic value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList();
}

class VocabularyRepository {
  final FirebaseFirestore db = FirebaseFirestore.instance;

  Stream<List<VWord>> watchWords({required String category}) {
    Query<Map<String, dynamic>> query = db
        .collection('vocabulary_words')
        .where('status', isEqualTo: 'published');

    if (category != 'all') {
      query = query.where('category', isEqualTo: category);
    }

    return query.snapshots().asyncMap((snapshot) async {
      final orderedDocs = ContentQueueService().sortPublished(snapshot.docs);
      if (orderedDocs.isEmpty) return <VWord>[];

      final uid = FirebaseAuth.instance.currentUser?.uid;

      // Signed-out/offline users can still see the first published word.
      if (uid == null || !OfflineContentService.instance.isOnline) {
        return <VWord>[VWord.fromDocument(orderedDocs.first)];
      }

      final poolKey = category == 'all'
          ? 'all'
          : 'category_${_safeVocabularyCycleKey(category)}';

      final cycleRef = db
          .collection('users')
          .doc(uid)
          .collection('vocabulary_cycles')
          .doc(poolKey);

      try {
        var cycleSnapshot = await cycleRef.get();
        var cycleData = cycleSnapshot.data() ?? const <String, dynamic>{};

        // First-time migration: preserve old "completed" behavior by seeding
        // Cycle 1 from the existing completed vocabulary IDs.
        if (!cycleSnapshot.exists) {
          final oldCompleted = await ContentQueueService()
              .completedVocabularyIds();

          final availableIds = orderedDocs.map((doc) => doc.id).toSet();
          final migrated = oldCompleted.where(availableIds.contains).toSet();

          await cycleRef.set({
            'poolKey': poolKey,
            'category': category,
            'cycleNumber': 1,
            'completedWordIds': migrated.toList(),
            'completedCount': migrated.length,
            'totalWordsAtLastLoad': orderedDocs.length,
            'progressPercent': orderedDocs.isEmpty
                ? 0
                : ((migrated.length / orderedDocs.length) * 100).round().clamp(
                    0,
                    100,
                  ),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          cycleSnapshot = await cycleRef.get();
          cycleData = cycleSnapshot.data() ?? const <String, dynamic>{};
        }

        var cycleNumber = _asIntV(cycleData['cycleNumber'], fallback: 1);

        var completedIds = _stringListV(cycleData['completedWordIds']).toSet();

        final availableIds = orderedDocs.map((doc) => doc.id).toSet();
        completedIds = completedIds.intersection(availableIds);

        var unseenDocs = orderedDocs
            .where((doc) => !completedIds.contains(doc.id))
            .toList();

        // No unseen vocabulary remains: start the next cycle from word 1.
        // Vocabulary progress/history is not deleted.
        if (unseenDocs.isEmpty) {
          cycleNumber += 1;
          completedIds = <String>{};
          unseenDocs = [...orderedDocs];

          await cycleRef.set({
            'cycleNumber': cycleNumber,
            'completedWordIds': <String>[],
            'completedCount': 0,
            'progressPercent': 0,
            'cycleCompleted': false,
            'cycleStartedAt': FieldValue.serverTimestamp(),
            'lastCycleResetAt': FieldValue.serverTimestamp(),
            'totalWordsAtLastLoad': orderedDocs.length,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }

        final selected = unseenDocs.first;

        await cycleRef.set({
          'poolKey': poolKey,
          'category': category,
          'cycleNumber': cycleNumber,
          'currentWordId': selected.id,
          'completedCount': completedIds.length,
          'totalWordsAtLastLoad': orderedDocs.length,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        return <VWord>[VWord.fromDocument(selected)];
      } catch (error, stackTrace) {
        debugPrint('Vocabulary cycle selection failed: $error');
        debugPrintStack(stackTrace: stackTrace);

        return <VWord>[VWord.fromDocument(orderedDocs.first)];
      }
    });
  }

  Future<List<VWord>> loadWords() async {
    final offline = OfflineContentService.instance;
    try {
      final snapshot = await db
          .collection('vocabulary_words')
          .where('status', isEqualTo: 'published')
          .limit(300)
          .get();
      await offline.cacheMany(
        module: 'vocabulary',
        items: snapshot.docs.map((doc) => MapEntry(doc.id, doc.data())),
      );
      return snapshot.docs.map(VWord.fromDocument).toList();
    } catch (_) {
      return offline
          .cachedContent('vocabulary')
          .map(
            (data) =>
                VWord.fromMap(data, id: data['_offlineId']?.toString() ?? ''),
          )
          .where((word) => word.word.isNotEmpty)
          .toList();
    }
  }

  Future<List<VWord>> loadReviewWords() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      final words = await loadWords();
      words.shuffle();
      return words.take(20).toList();
    }

    final progress = await db
        .collection('users')
        .doc(uid)
        .collection('vocabulary_progress')
        .get();

    final now = DateTime.now();
    final due = progress.docs
        .where((doc) {
          final value = doc.data()['nextReviewAt'];
          return value is! Timestamp || value.toDate().isBefore(now);
        })
        .map((doc) {
          final data = doc.data()['wordData'];
          return VWord.fromMap(
            data is Map ? Map<String, dynamic>.from(data) : {},
            id: doc.id,
          );
        })
        .where((word) => word.word.isNotEmpty)
        .toList();

    if (due.isNotEmpty) return due;

    final words = await loadWords();
    words.shuffle();
    return words.take(20).toList();
  }

  Future<void> toggleSaved(String uid, VWord word, bool save) {
    return _progress(uid, word).set({
      'wordId': word.id,
      'wordData': word.toMap(),
      'isSaved': save,
      'status': save ? 'saved' : 'new',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markStatus(
    String uid,
    VWord word,
    String status,
    int days, {
    String cyclePoolKey = 'all',
  }) async {
    await _progress(uid, word).set({
      'wordId': word.id,
      'wordData': word.toMap(),
      'status': status,
      'reviewCount': FieldValue.increment(1),
      'lastReviewedAt': FieldValue.serverTimestamp(),
      'nextReviewAt': Timestamp.fromDate(
        DateTime.now().add(Duration(days: days)),
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (status == 'learned' || status == 'mastered') {
      await _recordVocabularyCycleCompletion(
        uid: uid,
        word: word,
        poolKey: cyclePoolKey,
      );

      // Also keep the category-specific cycle aligned when the user learned
      // the word from the "All" pool.
      final categoryKey = 'category_${_safeVocabularyCycleKey(word.category)}';

      if (categoryKey != cyclePoolKey) {
        await _recordVocabularyCycleCompletion(
          uid: uid,
          word: word,
          poolKey: categoryKey,
        );
      }
    }
  }

  Future<void> _recordVocabularyCycleCompletion({
    required String uid,
    required VWord word,
    required String poolKey,
  }) async {
    if (!OfflineContentService.instance.isOnline) return;

    final ref = db
        .collection('users')
        .doc(uid)
        .collection('vocabulary_cycles')
        .doc(poolKey);

    try {
      await db
          .runTransaction((transaction) async {
            final snapshot = await transaction.get(ref);
            final data = snapshot.data() ?? const <String, dynamic>{};

            final completedIds = _stringListV(data['completedWordIds']).toSet();
            completedIds.add(word.id);

            final total = math.max(
              1,
              _asIntV(
                data['totalWordsAtLastLoad'],
                fallback: completedIds.length,
              ),
            );

            final completedCount = math.min(completedIds.length, total);
            final progressPercent = ((completedCount / total) * 100)
                .round()
                .clamp(0, 100);

            transaction.set(ref, {
              'poolKey': poolKey,
              'category': poolKey == 'all' ? 'all' : word.category,
              'cycleNumber': _asIntV(data['cycleNumber'], fallback: 1),
              'completedWordIds': completedIds.toList(),
              'completedCount': completedCount,
              'totalWordsAtLastLoad': total,
              'progressPercent': progressPercent,
              'currentWordId': FieldValue.delete(),
              'lastCompletedWordId': word.id,
              'lastCompletedWord': word.word,
              'cycleCompleted': completedCount >= total,
              'lastCompletedAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          })
          .timeout(const Duration(seconds: 15));
    } catch (error, stackTrace) {
      debugPrint('Vocabulary cycle completion failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> review(String uid, VWord word, int rating) async {
    final ref = _progress(uid, word);
    final old = await ref.get();
    final data = old.data() ?? {};
    final previous = _int(data['intervalDays'], 1);

    final next = rating <= 1
        ? 1
        : rating <= 3
        ? math.max(2, previous * 2)
        : math.max(7, previous * 3);

    await ref.set({
      'wordId': word.id,
      'wordData': word.toMap(),
      'status': next >= 30 ? 'mastered' : 'learned',
      'intervalDays': next,
      'lastRating': rating,
      'reviewCount': FieldValue.increment(1),
      'lastReviewedAt': FieldValue.serverTimestamp(),
      'nextReviewAt': Timestamp.fromDate(
        DateTime.now().add(Duration(days: next)),
      ),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _recordVocabularyCycleCompletion(
      uid: uid,
      word: word,
      poolKey: 'all',
    );

    await _recordVocabularyCycleCompletion(
      uid: uid,
      word: word,
      poolKey: 'category_${_safeVocabularyCycleKey(word.category)}',
    );
  }

  DocumentReference<Map<String, dynamic>> _progress(String uid, VWord word) {
    return db
        .collection('users')
        .doc(uid)
        .collection('vocabulary_progress')
        .doc(word.id);
  }

  int _int(dynamic value, int fallback) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}

class VWord {
  final String id;
  final String word;
  final String meaning;
  final String translation;
  final String pronunciation;
  final String partOfSpeech;
  final String example;
  final List<String> synonyms;
  final List<String> collocations;
  final String topic;
  final String category;
  final String band;

  const VWord({
    required this.id,
    required this.word,
    required this.meaning,
    required this.translation,
    required this.pronunciation,
    required this.partOfSpeech,
    required this.example,
    required this.synonyms,
    required this.collocations,
    required this.topic,
    required this.category,
    required this.band,
  });

  factory VWord.fromDocument(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    return VWord.fromMap(doc.data(), id: doc.id);
  }

  factory VWord.fromMap(Map<String, dynamic> data, {String id = ''}) {
    return VWord(
      id: id,
      word: (data['word'] ?? '').toString(),
      meaning: (data['meaning'] ?? '').toString(),
      translation: (data['translation'] ?? '').toString(),
      pronunciation: (data['pronunciation'] ?? '').toString(),
      partOfSpeech: (data['partOfSpeech'] ?? 'Unknown').toString(),
      example: (data['exampleSentence'] ?? '').toString(),
      synonyms: _strings(data['synonyms']),
      collocations: _strings(data['collocations']),
      topic: (data['topic'] ?? 'General').toString(),
      category: (data['category'] ?? 'academic').toString(),
      band: (data['band'] ?? '').toString(),
    );
  }

  String get searchText => [
    word,
    meaning,
    translation,
    pronunciation,
    partOfSpeech,
    example,
    topic,
    category,
    band,
    ...synonyms,
    ...collocations,
  ].join(' ').toLowerCase();

  Map<String, dynamic> toMap() => {
    'word': word,
    'meaning': meaning,
    'translation': translation,
    'pronunciation': pronunciation,
    'partOfSpeech': partOfSpeech,
    'exampleSentence': example,
    'synonyms': synonyms,
    'collocations': collocations,
    'topic': topic,
    'category': category,
    'band': band,
  };

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value.map((e) => e.toString()).toList();
  }
}

class VCategory {
  final String title;
  final String value;
  final IconData icon;

  const VCategory(this.title, this.value, this.icon);
}

enum VTool {
  flashcards('Flashcards', 'Spaced repetition review', Icons.style_outlined),
  daily('Daily Words', 'Learn five words every day', Icons.today_outlined),
  quiz('Vocabulary Quiz', 'Choose the correct meaning', Icons.quiz_outlined),
  spelling('Spelling Quiz', 'Listen and type words', Icons.hearing_outlined),
  match(
    'Match Words',
    'Connect words and meanings',
    Icons.compare_arrows_rounded,
  ),
  sentence(
    'Sentence Completion',
    'Choose the correct word',
    Icons.short_text_rounded,
  ),
  learned(
    'Learned Words',
    'Words currently in progress',
    Icons.check_circle_outline_rounded,
  ),
  mastered(
    'Mastered Words',
    'Vocabulary you know well',
    Icons.workspace_premium_outlined,
  ),
  saved(
    'Saved Words',
    'Your personal word list',
    Icons.bookmark_border_rounded,
  );

  final String title;
  final String subtitle;
  final IconData icon;

  const VTool(this.title, this.subtitle, this.icon);
}

// UI helpers

class _ProgressCard extends StatelessWidget {
  final String? userId;

  const _ProgressCard({required this.userId});

  @override
  Widget build(BuildContext context) {
    if (userId == null) return const _ProgressValues(0, 0, 0, 0);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('vocabulary_progress')
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final saved = docs.where((d) => d.data()['isSaved'] == true).length;
        final learned = docs
            .where((d) => d.data()['status'] == 'learned')
            .length;
        final mastered = docs
            .where((d) => d.data()['status'] == 'mastered')
            .length;
        final now = DateTime.now();
        final due = docs.where((d) {
          final value = d.data()['nextReviewAt'];
          return value is Timestamp && value.toDate().isBefore(now);
        }).length;

        return _ProgressValues(saved, learned, mastered, due);
      },
    );
  }
}

class _ProgressValues extends StatelessWidget {
  final int saved;
  final int learned;
  final int mastered;
  final int due;

  const _ProgressValues(this.saved, this.learned, this.mastered, this.due);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: heroDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Vocabulary Journey',
            style: TextStyle(
              color: VColors.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Review words at the right time and move them toward mastery.',
            style: TextStyle(color: VColors.secondary, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _metric('$due', 'Due Today', VColors.warning),
              _metric('$saved', 'Saved', VColors.cyan),
              _metric('$learned', 'Learned', VColors.violet),
              _metric('$mastered', 'Mastered', VColors.green),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metric(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: VColors.muted, fontSize: 8.8),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final VTool tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CardButton(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(tool.icon, color: VColors.cyan, size: 25),
          const SizedBox(height: 14),
          Text(
            tool.title,
            style: const TextStyle(
              color: VColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tool.subtitle,
            maxLines: 2,
            style: const TextStyle(color: VColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final VCategory item;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? VColors.primary.withOpacity(.16)
                : VColors.surface,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: selected ? VColors.primary : VColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.icon, color: selected ? VColors.cyan : VColors.muted),
              const Spacer(),
              Text(
                item.title,
                maxLines: 2,
                style: const TextStyle(
                  color: VColors.text,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WordCard extends StatelessWidget {
  final VWord word;
  final VoidCallback onTap;

  const _WordCard({required this.word, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _CardButton(
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: VColors.cyan.withOpacity(.12),
            child: Text(
              word.word.isEmpty ? '?' : word.word[0].toUpperCase(),
              style: const TextStyle(
                color: VColors.cyan,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        word.word,
                        style: const TextStyle(
                          color: VColors.text,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _Badge(word.band),
                  ],
                ),
                Text(
                  word.pronunciation,
                  style: const TextStyle(color: VColors.cyan, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  word.meaning,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: VColors.secondary,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [_Tag(word.partOfSpeech), _Tag(word.topic)],
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_ios_rounded,
            color: VColors.muted,
            size: 15,
          ),
        ],
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  final String title;
  final IconData icon;
  final String body;

  const _Detail(this.title, this.icon, this.body);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: VColors.cyan),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: VColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Text(
            body.isEmpty ? 'No data available.' : body,
            style: const TextStyle(color: VColors.secondary, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;

  const _TagSection({
    required this.title,
    required this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: VColors.cyan),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: VColors.text,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: items.isEmpty
                ? [const _Tag('No items')]
                : items.map(_Tag.new).toList(),
          ),
        ],
      ),
    );
  }
}

class _MatchTile extends StatelessWidget {
  final String text;
  final bool selected;
  final bool matched;
  final VoidCallback? onTap;

  const _MatchTile({
    required this.text,
    required this.selected,
    required this.matched,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = matched
        ? VColors.green
        : selected
        ? VColors.cyan
        : VColors.border;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: matched
                ? VColors.green.withOpacity(.08)
                : selected
                ? VColors.cyan.withOpacity(.08)
                : VColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: matched ? VColors.green : VColors.text,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPanel extends StatelessWidget {
  final String title;
  final String body;

  const _MiniPanel(this.title, this.body);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VColors.bg.withOpacity(.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: VColors.text,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(color: VColors.secondary, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _ToolScaffold extends StatelessWidget {
  final String title;
  final Widget child;

  const _ToolScaffold({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColors.bg,
      appBar: AppBar(backgroundColor: VColors.bg, title: Text(title)),
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          child,
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String title;
  final String subtitle;

  const _Title({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 23, 18, 11),
      child: _SectionLabel(title: title, subtitle: subtitle),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionLabel({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: VColors.text,
            fontSize: 16,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: const TextStyle(color: VColors.muted, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _StateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _StateView({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        margin: const EdgeInsets.all(22),
        padding: const EdgeInsets.all(24),
        decoration: panelDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: VColors.cyan, size: 48),
            const SizedBox(height: 13),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VColors.text,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 7),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VColors.muted, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _VocabularyLoadingView extends StatelessWidget {
  const _VocabularyLoadingView();

  @override
  Widget build(BuildContext context) {
    return const LearnerStateView.loading(
      eyebrow: 'BUILDING YOUR SESSION',
      title: 'Preparing the next words',
      message:
          'Using your current set and mastery history to create a focused practice round.',
      icon: Icons.auto_awesome_rounded,
    );
  }
}

class _CardButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const _CardButton({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: panelDecoration(),
          child: child,
        ),
      ),
    );
  }
}

class _GradientIcon extends StatelessWidget {
  final IconData icon;

  const _GradientIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [VColors.cyan, VColors.primary, VColors.violet],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Icon(icon, color: Colors.white),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;

  const _Badge(this.text);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: VColors.cyan.withOpacity(.1),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: VColors.cyan.withOpacity(.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: VColors.cyan,
          fontSize: 8.7,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String text;

  const _Tag(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: VColors.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VColors.border),
      ),
      child: Text(
        text,
        style: const TextStyle(color: VColors.muted, fontSize: 8.7),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [VColors.bg, Color(0xFF0D172B), VColors.bg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

abstract final class VColors {
  static const bg = Color(0xFF08111F);
  static const surface = Color(0xFF111C2E);
  static const border = Color(0xFF22324A);
  static const primary = Color(0xFF2563EB);
  static const cyan = Color(0xFF06B6D4);
  static const violet = Color(0xFF8B5CF6);
  static const green = Color(0xFF22C55E);
  static const warning = Color(0xFFF59E0B);
  static const text = Color(0xFFF8FAFC);
  static const secondary = Color(0xFFCBD5E1);
  static const muted = Color(0xFF94A3B8);
}

BoxDecoration panelDecoration() => BoxDecoration(
  color: VColors.surface.withOpacity(.94),
  borderRadius: BorderRadius.circular(18),
  border: Border.all(color: VColors.border),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(.12),
      blurRadius: 18,
      offset: const Offset(0, 8),
    ),
  ],
);

BoxDecoration heroDecoration() => BoxDecoration(
  gradient: LinearGradient(
    colors: [
      VColors.surface,
      VColors.cyan.withOpacity(.09),
      VColors.violet.withOpacity(.08),
    ],
  ),
  borderRadius: BorderRadius.circular(22),
  border: Border.all(color: VColors.cyan.withOpacity(.22)),
);
