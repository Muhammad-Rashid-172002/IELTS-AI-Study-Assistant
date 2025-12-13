import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gemini/flutter_gemini.dart';
import 'package:fyproject/controller/firebase_services/firebase_services.dart';
import 'package:fyproject/resources/routes/routes.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_instance/src/extension_instance.dart';
import 'package:get/get_navigation/src/root/get_material_app.dart';

import 'config/keys.dart';
import 'controller/feedback_controller/feedback_controller.dart';
import 'controller/math_controller/math_controller.dart';
import 'controller/mcq_controller/mcq_controller.dart';
import 'controller/summarizer_controller/summarizer_controller.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Ignore duplicate app error during hot restart
    if (e.toString().contains("duplicate-app")) {
      print("🔥 Firebase already initialized — skipping.");
    } else {
      rethrow;
    }
  }

  // My API is Expired
  Gemini.init(apiKey: AppKeys.geminiApiKey);

  // Register all controllers
  Get.put(SummarizerController(), permanent: true);
  Get.put(MCQController(), permanent: true);
  Get.put(MathController(), permanent: true);
  Get.put(FeedbackController(), permanent: true);
  Get.put(FirebaseServices(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IELTS AI Study',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      getPages: AppRoutes.appRoutes(),
    );
  }
}
