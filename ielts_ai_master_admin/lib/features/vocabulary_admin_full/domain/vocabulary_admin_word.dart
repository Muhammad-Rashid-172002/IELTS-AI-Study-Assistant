import 'package:cloud_firestore/cloud_firestore.dart';

class VocabularyAdminWord {
  final String id;
  final String word;
  final String meaning;
  final String translation;
  final String pronunciation;
  final String ipa;
  final String partOfSpeech;
  final String exampleSentence;
  final List<String> synonyms;
  final List<String> antonyms;
  final List<String> collocations;
  final String topic;
  final String category;
  final String band;
  final String difficulty;
  final String commonMistake;
  final String spellingTip;
  final String usageNote;
  final List<String> wordFamily;
  final String register;
  final List<String> modules;
  final String status;
  final bool isPublished;
  final double qualityScore;
  final int savedCount;
  final int learnedCount;
  final int masteredCount;
  final int reviewCount;
  final double averageAccuracy;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const VocabularyAdminWord({
    required this.id,
    required this.word,
    required this.meaning,
    required this.translation,
    required this.pronunciation,
    required this.ipa,
    required this.partOfSpeech,
    required this.exampleSentence,
    required this.synonyms,
    required this.antonyms,
    required this.collocations,
    required this.topic,
    required this.category,
    required this.band,
    required this.difficulty,
    required this.commonMistake,
    required this.spellingTip,
    required this.usageNote,
    required this.wordFamily,
    required this.register,
    required this.modules,
    required this.status,
    required this.isPublished,
    required this.qualityScore,
    required this.savedCount,
    required this.learnedCount,
    required this.masteredCount,
    required this.reviewCount,
    required this.averageAccuracy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VocabularyAdminWord.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};

    return VocabularyAdminWord(
      id: doc.id,
      word: (data['word'] ?? '').toString(),
      meaning: (data['meaning'] ?? '').toString(),
      translation: (data['translation'] ?? '').toString(),
      pronunciation: (data['pronunciation'] ?? '').toString(),
      ipa: (data['ipa'] ?? '').toString(),
      partOfSpeech: (data['partOfSpeech'] ?? '').toString(),
      exampleSentence: (data['exampleSentence'] ?? '').toString(),
      synonyms: _strings(data['synonyms']),
      antonyms: _strings(data['antonyms']),
      collocations: _strings(data['collocations']),
      topic: (data['topic'] ?? 'General IELTS').toString(),
      category: (data['category'] ?? 'academic').toString(),
      band: (data['band'] ?? 'Band 7').toString(),
      difficulty: (data['difficulty'] ?? 'Intermediate').toString(),
      commonMistake: (data['commonMistake'] ?? '').toString(),
      spellingTip: (data['spellingTip'] ?? '').toString(),
      usageNote: (data['usageNote'] ?? '').toString(),
      wordFamily: _strings(data['wordFamily']),
      register: (data['register'] ?? 'neutral').toString(),
      modules: _strings(data['modules']),
      status: (data['status'] ?? 'draft').toString(),
      isPublished: data['isPublished'] == true,
      qualityScore: _double(data['qualityScore']),
      savedCount: _int(data['savedCount']),
      learnedCount: _int(data['learnedCount']),
      masteredCount: _int(data['masteredCount']),
      reviewCount: _int(data['reviewCount']),
      averageAccuracy: _double(data['averageAccuracy']),
      createdAt: _date(data['createdAt']),
      updatedAt: _date(data['updatedAt']),
    );
  }

  String get categoryLabel => switch (category) {
        'academic' => 'Academic Vocabulary',
        'topic' => 'Topic Vocabulary',
        'band_5' => 'Band 5 Words',
        'band_6' => 'Band 6 Words',
        'band_7' => 'Band 7 Words',
        'band_8_9' => 'Band 8–9 Words',
        'collocations' => 'Collocations',
        'phrasal_verbs' => 'Phrasal Verbs',
        'synonyms' => 'Synonyms',
        'spelling' => 'Spelling Mistakes',
        _ => category,
      };

  Map<String, dynamic> toFirestore() {
    return {
      'word': word.trim(),
      'normalizedWord': word.trim().toLowerCase(),
      'meaning': meaning.trim(),
      'translation': translation.trim(),
      'pronunciation': pronunciation.trim(),
      'ipa': ipa.trim(),
      'partOfSpeech': partOfSpeech.trim(),
      'exampleSentence': exampleSentence.trim(),
      'synonyms': synonyms,
      'antonyms': antonyms,
      'collocations': collocations,
      'topic': topic.trim(),
      'category': category,
      'band': band,
      'difficulty': difficulty,
      'commonMistake': commonMistake.trim(),
      'spellingTip': spellingTip.trim(),
      'usageNote': usageNote.trim(),
      'wordFamily': wordFamily,
      'register': register,
      'modules': modules,
    };
  }

  static List<String> _strings(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static int _int(dynamic value) {
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static DateTime? _date(dynamic value) {
    return value is Timestamp ? value.toDate() : null;
  }
}
