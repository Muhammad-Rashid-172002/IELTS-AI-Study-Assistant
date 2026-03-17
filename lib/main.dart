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

void main()async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  //My Api is Expired
  Gemini.init(apiKey: AppKeys.geminiApiKey);  // <--- USE YOUR KEY SAFELY
  // Register all controllers globally
  Get.put(SummarizerController(), permanent: true);
  Get.put(MCQController(), permanent: true);
  Get.put(MathController(), permanent: true);
  Get.put(FeedbackController(), permanent: true);
  Get.put(FirebaseServices(),permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        //colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
    getPages: AppRoutes.appRoutes(),
    );
  }
}

