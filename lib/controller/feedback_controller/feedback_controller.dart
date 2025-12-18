import 'package:fyproject/services/ai_service.dart';
import 'package:get/get.dart';

//import '../../services/ai_service.dart';
//
//
// class FeedbackController extends GetxController {
//   final AIService api = AIService();
//
//   var isLoading = false.obs;
//   var feedback = "".obs;
//
//   Future<void> generateFeedback(String text) async {
//     isLoading.value = true;
//     feedback.value = await api.feedback(text);
//     isLoading.value = false;
//   }
// }

// class FeedbackController extends GetxController {
//   final AIService api = AIService();
//
//   var isLoading = false.obs;
//   var feedback = "".obs;
//
//   Future<void> generateFeedback(String text, String category) async {
//     isLoading.value = true;
//     feedback.value = await api.feedback(text, category);
//     isLoading.value = false;
//   }
// }
// import 'package:get/get.dart';
// import '../../services/ai_service.dart';

class FeedbackController extends GetxController {
  final AIService api = AIService();

  var isLoading = false.obs;
  var feedback = "".obs;

  Future<void> generateFeedback(String text, String category) async {
    isLoading.value = true;

    try {
      feedback.value = await api.feedback(text, category);
    } catch (e) {
      feedback.value =
      "⚠ Gemini is busy or rate limited. Please try again in a moment.";
    }

    isLoading.value = false;
  }
}
