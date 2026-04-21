import 'package:fyproject/services/ai_service.dart';
import 'package:get/get.dart';

class IELTSController extends GetxController {
  final AIService api = AIService();

  // 🔄 Loading state
  var isLoading = false.obs;

  // 📊 Outputs
  var writingFeedback = "".obs;
  var speakingFeedback = "".obs;
  var readingHelp = "".obs;
  var listeningHelp = "".obs;
  var vocabularyHelp = "".obs;
  var bandScore = "".obs;
  var vocabWords = [].obs;
  var currentIndex = 0.obs;

  // ==========================
  // ✍️ WRITING TASK FEEDBACK
  // ==========================
  Future<void> getWritingFeedback(String text, String taskType) async {
    isLoading.value = true;

    try {
      final prompt =
          """
You are an IELTS examiner. Evaluate this IELTS Writing $taskType response.

Give:
- Band score
- Task Achievement
- Coherence & Cohesion
- Lexical Resource
- Grammar
- सुधार (improvement suggestions)

Text:
$text
""";

      writingFeedback.value = await api.feedback(prompt, "writing");
    } catch (e) {
      writingFeedback.value = "⚠️ Error: Server busy. Please try again.";
    }

    isLoading.value = false;
  }

  // ==========================
  // 🎤 SPEAKING FEEDBACK
  // ==========================
  Future<void> getSpeakingFeedback(String speechText) async {
    isLoading.value = true;

    try {
      final prompt =
          """
You are an IELTS Speaking examiner.

Evaluate this response:
- Fluency & Coherence
- Vocabulary
- Grammar
- Pronunciation (assume)
- Band score
- Suggestions

Speech:
$speechText
""";

      speakingFeedback.value = await api.feedback(prompt, "speaking");
    } catch (e) {
      speakingFeedback.value = "⚠️ Speaking evaluation failed. Try again.";
    }

    isLoading.value = false;
  }

  // ==========================
  // 📖 READING HELP
  // ==========================
  Future<void> getReadingHelp(String passage, String question) async {
    isLoading.value = true;

    try {
      final prompt =
          """
You are an IELTS Reading tutor.

Passage:
$passage

Question:
$question

Explain:
- Correct answer
- Why it is correct
- Strategy to solve similar questions
""";

      readingHelp.value = await api.feedback(prompt, "reading");
    } catch (e) {
      readingHelp.value = "⚠️ Reading help not available.";
    }

    isLoading.value = false;
  }

  // ==========================
  // 🎧 LISTENING HELP
  // ==========================
  Future<void> getListeningHelp(String transcript, String question) async {
    isLoading.value = true;

    try {
      final prompt =
          """
You are an IELTS Listening tutor.

Transcript:
$transcript

Question:
$question

Provide:
- Correct answer
- Explanation
- Listening tips
""";

      listeningHelp.value = await api.feedback(prompt, "listening");
    } catch (e) {
      listeningHelp.value = "⚠️ Listening help failed.";
    }

    isLoading.value = false;
  }

  // ==========================
  // 📚 VOCABULARY BUILDER
  // ==========================
  Future<void> getVocabulary(String text) async {
    isLoading.value = true;

    try {
      final prompt =
          """
Extract advanced IELTS vocabulary from this text.

Give:
- Word
- Meaning
- Example sentence

Text:
$text
""";

      vocabularyHelp.value = await api.feedback(prompt, "vocabulary");
    } catch (e) {
      vocabularyHelp.value = "⚠️ Vocabulary service unavailable.";
    }

    isLoading.value = false;
  }

  // ==========================
  // 📈 BAND SCORE ESTIMATION
  // ==========================
  Future<void> estimateBand(String text) async {
    isLoading.value = true;

    try {
      final prompt =
          """
Estimate IELTS band score for this writing.

Give:
- Overall band
- Strengths
- Weaknesses

Text:
$text
""";

      bandScore.value = await api.feedback(prompt, "band");
    } catch (e) {
      bandScore.value = "⚠️ Could not estimate band score.";
    }

    isLoading.value = false;
  }
}
