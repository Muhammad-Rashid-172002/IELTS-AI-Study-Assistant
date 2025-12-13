


import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/ai_service.dart';

class MCQController extends GetxController {
  final AIService api = AIService();

  var isLoading = false.obs;
  var question = "".obs;
  var options = <String>[].obs;
  var answer = "".obs;

  Future<void> generateMCQ(String text, String difficulty, String focus) async {
    isLoading.value = true;

    try {
      final data = await api.generateMCQ(text, difficulty, focus);

      question.value = data["question"];
      options.value = List<String>.from(data["options"]);
      answer.value = data["answer"];

      // ⭐ UPDATE USER PROGRESS (questions +1)
      await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({"progress.questions": FieldValue.increment(1)});

    } catch (e) {
      question.value = "Error generating MCQ.";
      options.value = [];
      answer.value = "";
    } finally {
      isLoading.value = false;
    }
  }
}
