

import 'package:fyproject/services/ai_service.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';



class MathController extends GetxController {
  var result = "".obs;
  var isLoading = false.obs;

  final ai = AIService();

  Future<void> solve(String query) async {
    if (isLoading.value) return;

    isLoading.value = true;
    result.value = "";

    try {
      final output = await ai.solveMath(query);
      result.value = output;

      // ⭐ UPDATE FIRESTORE PROGRESS ⭐
      await FirebaseFirestore.instance
          .collection("users")
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        "progress.solved": FieldValue.increment(1),
      });

    } catch (e) {
      result.value = "❌ Error: ${e.toString()}";
    } finally {
      isLoading.value = false;
    }
  }
}
