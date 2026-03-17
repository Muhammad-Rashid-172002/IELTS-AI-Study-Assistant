import 'package:get/get.dart';
import 'package:fyproject/services/ai_service.dart';

class FeedbackController extends GetxController {

  final AIService api = AIService();

  var isLoading = false.obs;
  var feedback = "".obs;

  /// Generate AI response
  Future<void> generateFeedback(String text, String category) async {

    if(text.trim().isEmpty){
      feedback.value = "Please enter some text.";
      return;
    }

    try {

      isLoading.value = true;

      final result = await api.feedback(text, category);

      feedback.value = result;

    } catch (e) {

      feedback.value =
      "AI service is busy right now. Please try again later.";

    } finally {

      isLoading.value = false;

    }
  }

  /// Clear previous result
  void clearFeedback(){
    feedback.value = "";
  }
}