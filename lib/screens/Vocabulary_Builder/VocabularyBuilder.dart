import 'package:flutter/material.dart';
import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';
import 'package:get/get.dart';


class Vocabularybuilder extends StatefulWidget {
  const Vocabularybuilder({super.key});

  @override
  State<Vocabularybuilder> createState() => _VocabularybuilderState();
}

class _VocabularybuilderState extends State<Vocabularybuilder> {
  final TextEditingController topicController = TextEditingController();

  final IELTSController ieltsController =
      Get.put(IELTSController());

  String selectedLevel = "Band 7+";

  final levels = [
    "Band 6+",
    "Band 7+",
    "Band 8+",
    "Band 9"
  ];

  // =====================================================
  // GENERATE REAL AI VOCABULARY
  // =====================================================
  Future<void> generateVocabulary() async {
    if (topicController.text.trim().isEmpty) {
      Get.snackbar(
        "Error",
        "Enter a topic first",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    ieltsController.isLoading.value = true;

    try {
      final prompt = """
You are an IELTS Vocabulary Expert.

Generate advanced IELTS $selectedLevel vocabulary words for topic:
${topicController.text}

Requirements:
- Generate 12 advanced vocabulary words
- For each word give:
1. Word
2. Meaning
3. IELTS Example Sentence
4. Synonym

Format exactly like:

1. Word: Sustainable
Meaning: able to continue over time
Example: Sustainable energy is important for future generations.
Synonym: Renewable

2. Word: Innovation
Meaning: new idea or method
Example: Technological innovation improves productivity.
Synonym: Advancement
""";

      final result = await ieltsController.api.feedback(
        prompt,
        "vocabulary",
      );

      ieltsController.vocabularyHelp.value = result;
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to generate vocabulary",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }

    ieltsController.isLoading.value = false;
  }

  // =====================================================
  // UI
  // =====================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: _appBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _infoBanner(),
            const SizedBox(height: 20),
            _topicInput(),
            const SizedBox(height: 20),
            _bandSelector(),
            const SizedBox(height: 20),
            _generateButton(),
            const SizedBox(height: 20),
            _resultCard(),
          ],
        ),
      ),
    );
  }

  // =====================================================
  // APP BAR
  // =====================================================
  AppBar _appBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FA),
                borderRadius:
                    BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  Colors.green.withOpacity(0.15),
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                "AI Vocabulary Builder",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              Text(
                "Real IELTS Smart Vocabulary",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  // =====================================================
  // INFO BANNER
  // =====================================================
  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFFE8F8EF),
            Color(0xFFF1FCF6),
          ],
        ),
        borderRadius:
            BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(
            color: Colors.green,
            width: 4,
          ),
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.lightbulb_outline,
            color: Colors.green,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Enter any IELTS topic and AI will generate real advanced vocabulary with meanings, examples, and synonyms.",
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
              ),
            ),
          )
        ],
      ),
    );
  }

  // =====================================================
  // TOPIC INPUT
  // =====================================================
  Widget _topicInput() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            "IELTS Topic",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: topicController,
            decoration:
                const InputDecoration(
              hintText:
                  "Example: Education, Environment, Technology",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // BAND SELECTOR
  // =====================================================
  Widget _bandSelector() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _card(),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            "Vocabulary Level",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedLevel,
              isExpanded: true,
              items: levels.map((e) {
                return DropdownMenuItem(
                  value: e,
                  child: Text(e),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLevel = value!;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // GENERATE BUTTON
  // =====================================================
  Widget _generateButton() {
    return Obx(() {
      return Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF2ECC9A),
              Color(0xFF7FECC2),
            ],
          ),
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: TextButton.icon(
          onPressed:
              ieltsController.isLoading.value
                  ? null
                  : generateVocabulary,
          icon: ieltsController
                  .isLoading.value
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(
                  Icons.auto_awesome,
                  color: Colors.white,
                ),
          label: Text(
            ieltsController.isLoading.value
                ? "Generating..."
                : "Generate Vocabulary",
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    });
  }

  // =====================================================
  // RESULT CARD
  // =====================================================
  Widget _resultCard() {
    return Obx(() {
      if (ieltsController
          .vocabularyHelp.value.isEmpty) {
        return const SizedBox();
      }

      return Container(
        padding: const EdgeInsets.all(18),
        decoration: _card(),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              "AI Generated Vocabulary",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ieltsController
                  .vocabularyHelp.value,
              style: const TextStyle(
                fontSize: 15,
                height: 1.6,
              ),
            ),
          ],
        ),
      );
    });
  }

  // =====================================================
  // CARD STYLE
  // =====================================================
  BoxDecoration _card() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius:
          BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color:
              Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        )
      ],
    );
  }
}