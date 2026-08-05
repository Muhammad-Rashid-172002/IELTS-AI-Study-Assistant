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
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  Gemini.init(apiKey: AppKeys.geminiApiKey);
  Get.put(IELTSController(), permanent: true);
  Get.put(FirebaseServices(), permanent: true);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IELTS Master',
      theme: ThemeData(
        //colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      getPages: AppRoutes.appRoutes(),
    );
  }
}

//app
// 25:92:FF:18:7C:04:01:14:C8:8B:4E:1E:18:87:DE:B7:92:3E:58:EC
// 47:27:74:6C:C5:63:C2:5B:40:8B:E7:91:DD:3A:72:9B:13:DB:61:AC:CD:DB:DF:68:ED:BC:EB:7B:79:DA:FC:4C
