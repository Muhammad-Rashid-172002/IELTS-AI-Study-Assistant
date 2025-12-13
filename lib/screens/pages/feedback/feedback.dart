// import 'package:flutter/material.dart';
//
//
// class Feedback extends StatefulWidget {
//   const Feedback({super.key});
//
//   @override
//   State<Feedback> createState() => _FeedbackState();
// }
//
// class _FeedbackState extends State<Feedback> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('FeedBack'),
//       ),
//       body: Column(
//         children: [
//
//         ],
//       ),
//     );
//   }
// }



import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';

import '../../../controller/feedback_controller/feedback_controller.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final TextEditingController _textController = TextEditingController();
  int _charCount = 0;
  final feedbackController = Get.put(FeedbackController());

  String _selectedCategory = "Writing";

  @override
  void initState() {
    super.initState();
    _textController.addListener(() {
      setState(() {
        _charCount = _textController.text.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),

      appBar: _buildAppBar(),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoBanner(),

            const SizedBox(height: 20),

            _categorySelector(),

            const SizedBox(height: 20),

            _inputCard(),

            const SizedBox(height: 26),

            _submitButton(),

            const SizedBox(height: 30),

            // FEEDBACK RESULT (placeholder)
          //  _feedbackResultBox(),
            _feedbackResultCard(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // TOP APP BAR
  // ------------------------------------------------------------
  AppBar _buildAppBar() {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      toolbarHeight: 72,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF3FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.arrow_back,
                  size: 22, color: Colors.black87),
            ),
          ),

          const SizedBox(width: 14),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.feedback,
                color: Colors.blueAccent, size: 22),
          ),

          const SizedBox(width: 12),

          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "AI Study Feedback",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black),
              ),
              Text(
                "Personalized guidance",
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // INFO BANNER
  // ------------------------------------------------------------
  Widget _infoBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDDEBFF), Color(0xFFE9F3FF)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: const Border(
          left: BorderSide(color: Colors.blueAccent, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.blueAccent, size: 22),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              "Tell us about your study progress or paste a writing sample. "
                  "Our AI will analyze and give you constructive feedback.",
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // CATEGORY SELECTOR
  // ------------------------------------------------------------
  Widget _categorySelector() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Feedback Category",
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
          const SizedBox(height: 12),

          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedCategory,
              items: ["Writing", "Speaking", "Grammar", "Reading"]
                  .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600)),
              ))
                  .toList(),
              onChanged: (value) =>
                  setState(() => _selectedCategory = value!),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // INPUT TEXT CARD
  // ------------------------------------------------------------
  Widget _inputCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // TITLE + COUNTER
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Your Text",
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87),
              ),
              Text("${_charCount} / 1000",
                  style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600)),
            ],
          ),

          const SizedBox(height: 14),

          // TEXT FIELD
          Container(
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black12),
            ),
            child: TextField(
              controller: _textController,
              maxLines: null,
              maxLength: 1000,
              decoration: const InputDecoration(
                counterText: "",
                hintText: "Describe your study progress or paste a sample...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------
  // SUBMIT BUTTON
  // ------------------------------------------------------------
  Widget _submitButton() {
    return Obx(() {
      return Container(
        height: 54,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF4A79F6), Color(0xFF8FB2FF)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextButton.icon(
          // onPressed: feedbackController.isLoading.value
          //     ? null
          //     : () {
          //   if (_textController.text.trim().isEmpty) {
          //     Get.snackbar(
          //       "Error",
          //       "Please enter some text.",
          //       backgroundColor: Colors.red,
          //       colorText: Colors.white,
          //     );
          //     return;
          //   }
          //
          //   feedbackController.generateFeedback(
          //     _textController.text.trim(),
          //   );
          // },
          onPressed: feedbackController.isLoading.value
              ? null
              : () {
            if (_textController.text.trim().isEmpty) {
              Get.snackbar("Error", "Please enter some text.",
                  backgroundColor: Colors.red, colorText: Colors.white);
              return;
            }

            feedbackController.generateFeedback(
              _textController.text.trim(),
              _selectedCategory,   // ⭐ category passed here
            );
          },
          icon: feedbackController.isLoading.value
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          )
              : const Icon(Icons.analytics, color: Colors.white),
          label: Text(
            feedbackController.isLoading.value
                ? "Analyzing..."
                : "Get AI Feedback",
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    });
  }

  Widget _feedbackResultCard() {
    return Obx(() {
      if (feedbackController.feedback.isEmpty) {
        return const SizedBox();
      }

      return Container(
        margin: const EdgeInsets.only(top: 20),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            const Text(
              "AI Feedback",
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),

            const SizedBox(height: 12),

            // FEEDBACK TEXT
            Container(
              constraints: const BoxConstraints(
                minHeight: 100,
                maxHeight: 300,
              ),
              child: SingleChildScrollView(
                child: Text(
                  feedbackController.feedback.value,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      );
    });
  }



  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.06),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }
}
