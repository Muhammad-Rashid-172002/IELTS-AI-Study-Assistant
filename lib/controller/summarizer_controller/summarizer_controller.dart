//
//
// import 'dart:io';
// import 'package:get/get.dart';
// import '../../services/ai_service.dart';  // adjust your path
//
// class SummarizerController extends GetxController {
//   final AIService api = AIService();
//
//   var isLoading = false.obs;
//   var result = "".obs;
//
//   /// -------------------------------------------------------
//   /// SUMMARIZE TEXT
//   /// -------------------------------------------------------
//   Future<void> summarize(String text, String length, bool bullets) async {
//     if (text.trim().isEmpty) {
//       result.value = "⚠️ Please enter some text to summarize.";
//       return;
//     }
//
//     try {
//       isLoading.value = true;
//       result.value = ""; // clear old result
//
//       final summary = await api.summarizeText(
//         text.trim(),
//         length: length,
//         bullets: bullets,
//       );
//
//       result.value = summary.isEmpty
//           ? "⚠️ No summary was generated. Try again."
//           : summary;
//
//     } catch (e) {
//       result.value = "❌ Error: $e";
//     } finally {
//       isLoading.value = false;
//     }
//   }
//
//   /// -------------------------------------------------------
//   /// SUMMARIZE IMAGE TEXT
//   /// -------------------------------------------------------
//   Future<void> summarizeImage(File imageFile) async {
//     try {
//       isLoading.value = true;
//       result.value = ""; // clear old result
//
//       final summary = await api.summarizeImage(imageFile);
//
//       result.value = summary.isEmpty
//           ? "⚠️ Could not extract or summarize text from the image."
//           : summary;
//
//     } catch (e) {
//       result.value = "❌ Image summarization failed: $e";
//     } finally {
//       isLoading.value = false;
//     }
//   }
// }
//



import 'dart:io';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:get/get_state_manager/src/simple/get_controllers.dart';
import '../../services/ai_service.dart';
import '../firebase_services/firebase_services.dart';


class SummarizerController extends GetxController {
  final AIService api = AIService();

  var isLoading = false.obs;
  var result = "".obs;

  /// -------------------------------------------------------
  /// SUMMARIZE TEXT (WITH FULL DEBUG LOGS)
  /// -------------------------------------------------------

  Future<void> summarize(String text, String length, bool bullets) async {
    print("🎯 summarize() STARTED");
    print("📌 text length: ${text.length}");

    try {
      isLoading.value = true;

      result.value = "";

      // ❌ Gemini may fail here, but that's fine
      final summary = await api.summarizeText(text, length: length, bullets: bullets);

      result.value = summary.isEmpty ? "⚠️ No summary generated." : summary;

      print("🟢 Gemini summary created");
    }
    catch (e) {
      print("❌ summarize ERROR: $e");
      result.value = "❌ Error: $e";
    }
    finally {
      print("🔥 Calling updateDailyProgress()");
      final fs = Get.find<FirebaseServices>();

      await fs.updateDailyProgress(
        summaries: 1,
        questions: 0,
        solved: 0,
      );

      print("🟢 updateDailyProgress finished");

      // Update local GetX map so UI changes instantly
      if (fs.userData["progress"] != null) {
        fs.userData["progress"]["summaries"] =
            (fs.userData["progress"]["summaries"] ?? 0) + 1;
        fs.userData.refresh();
        print("✨ Local UI progress updated");
      }

      isLoading.value = false;
      print("🔚 summarize() FINISHED");
    }
  }

  /// -------------------------------------------------------
  /// SUMMARIZE IMAGE TEXT (WITH FULL DEBUG LOGS)
  /// -------------------------------------------------------
  Future<void> summarizeImage(File imageFile) async {
    print("🖼️ summarizeImage() STARTED");
    print("📸 image path: ${imageFile.path}");

    try {
      isLoading.value = true;
      result.value = "";

      print("⚙️ Calling Gemini summarizeImage()...");
      final summary = await api.summarizeImage(imageFile);
      print("📥 Gemini image response received!");
      print("📜 Summary length: ${summary.length}");

      result.value = summary.isEmpty
          ? "⚠️ Could not extract or summarize text from the image."
          : summary;

      final fs = Get.find<FirebaseServices>();
      print("🔥 Updating progress (summaries +1)...");
      await fs.updateDailyProgress(
        summaries: 1,
        questions: 0,
        solved: 0,
      );

      print("🎉 summarizeImage() COMPLETED SUCCESSFULLY");

    } catch (e) {
      print("❌ summarizeImage() ERROR: $e");
      result.value = "❌ Image summarization failed: $e";

    } finally {
      isLoading.value = false;
      print("🔚 summarizeImage() FINISHED (loading=false)");
    }
  }
}

