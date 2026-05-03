// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:get/get.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_tts/flutter_tts.dart';
// import 'package:fyproject/controller/feedback_controller/feedback_controller.dart';

// class Vocabularybuilder extends StatefulWidget {
//   const Vocabularybuilder({super.key});

//   @override
//   State<Vocabularybuilder> createState() => _VocabularybuilderState();
// }

// class _VocabularybuilderState extends State<Vocabularybuilder> {
//   final TextEditingController topicController = TextEditingController();
//   final IELTSController ieltsController = Get.find<IELTSController>();

//   final FlutterTts flutterTts = FlutterTts();

//   List vocabList = [];
//   Set<String> bookmarkedWords = {};

//   String selectedLevel = "Band 7+";
//   bool isLoading = false;

//   final List<String> levels = [
//     "Band 6+",
//     "Band 7+",
//     "Band 8+",
//     "Band 9"
//   ];

//   // ================= GENERATE =================
//   Future<void> generateVocabulary() async {
//     final topic = topicController.text.trim();

//     if (topic.isEmpty) {
//       Get.snackbar("Error", "Enter topic first");
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final prompt = """
// Return ONLY JSON:

// {
//  "words":[
//   {
//    "word":"example",
//    "meaning":"definition",
//    "example":"sentence",
//    "synonym":"similar word"
//   }
//  ]
// }

// Generate 12 IELTS vocabulary words.
// Topic: $topic
// Level: $selectedLevel
// """;

//       final result =
//           await ieltsController.api.feedback(prompt, "vocabulary");

//       final decoded = jsonDecode(result);

//       vocabList = decoded["words"] ?? [];

//       await saveHistory(topic);

//       setState(() {});
//     } catch (e) {
//       Get.snackbar("Error", "AI parsing failed");
//     }

//     setState(() => isLoading = false);
//   }

//   // ================= WORD DETAIL AI =================
//   Future<Map<String, dynamic>> fetchWordDetail(String word) async {
//     final prompt = """
// Return ONLY JSON:

// {
//  "word":"$word",
//  "meaning":"",
//  "urdu":"",
//  "synonyms":[],
//  "antonyms":[],
//  "examples":[],
//  "pronunciation":""
// }

// Explain the word '$word' for IELTS student.
// """;

//     final result =
//         await ieltsController.api.feedback(prompt, "vocabulary");

//     return jsonDecode(result);
//   }

//   // ================= BOTTOM SHEET =================
//   void showWordDetail(String word) {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) {
//         return FutureBuilder(
//           future: fetchWordDetail(word),
//           builder: (context, snapshot) {
//             return Container(
//               height: MediaQuery.of(context).size.height * 0.75,
//               padding: const EdgeInsets.all(16),
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius:
//                     BorderRadius.vertical(top: Radius.circular(20)),
//               ),
//               child: snapshot.connectionState == ConnectionState.waiting
//                   ? const Center(child: CircularProgressIndicator())
//                   : snapshot.hasError
//                       ? const Center(child: Text("Error loading"))
//                       : _detailContent(snapshot.data!),
//             );
//           },
//         );
//       },
//     );
//   }

//   Widget _detailContent(Map data) {
//     return ListView(
//       children: [
//         Text(
//           data["word"],
//           style: const TextStyle(
//               fontSize: 22, fontWeight: FontWeight.bold),
//         ),

//         const SizedBox(height: 6),
//         Text("🔊 ${data["pronunciation"]}"),

//         const Divider(),

//         Text("Meaning: ${data["meaning"]}"),
//         Text("Urdu: ${data["urdu"]}"),

//         const SizedBox(height: 10),

//         Text("Synonyms: ${data["synonyms"].join(", ")}"),
//         Text("Antonyms: ${data["antonyms"].join(", ")}"),

//         const SizedBox(height: 10),

//         const Text("Examples:",
//             style: TextStyle(fontWeight: FontWeight.bold)),

//         ...List.generate(
//           data["examples"].length,
//           (i) => Text("• ${data["examples"][i]}"),
//         ),
//       ],
//     );
//   }

//   // ================= TTS =================
//   Future speak(String word) async {
//     await flutterTts.setLanguage("en-US");
//     await flutterTts.setPitch(1);
//     await flutterTts.speak(word);
//   }

//   // ================= BOOKMARK =================
//   Future<void> toggleBookmark(Map item) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     final word = item["word"];

//     final ref = FirebaseFirestore.instance
//         .collection("users")
//         .doc(user.uid)
//         .collection("bookmarks")
//         .doc(word);

//     if (bookmarkedWords.contains(word)) {
//       await ref.delete();
//       bookmarkedWords.remove(word);
//     } else {
//     await ref.set(Map<String, dynamic>.from(item));
//       bookmarkedWords.add(word);
//     }

//     setState(() {});
//   }

//   // ================= SAVE HISTORY =================
//   Future<void> saveHistory(String topic) async {
//     final user = FirebaseAuth.instance.currentUser;
//     if (user == null) return;

//     await FirebaseFirestore.instance
//         .collection("users")
//         .doc(user.uid)
//         .collection("vocabulary_history")
//         .add({
//       "topic": topic,
//       "level": selectedLevel,
//       "words": vocabList,
//       "createdAt": FieldValue.serverTimestamp(),
//     });
//   }

//   @override
//   void dispose() {
//     topicController.dispose();
//     super.dispose();
//   }

//   // ================= UI =================
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF4F7FB),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         title: const Text("AI Vocabulary Builder"),
//       ),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           children: [
//             _topicInput(),
//             const SizedBox(height: 16),
//             _levelDropdown(),
//             const SizedBox(height: 16),
//             _generateButton(),
//             const SizedBox(height: 20),
//             _resultList(),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _topicInput() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: _card(),
//       child: TextField(
//         controller: topicController,
//         decoration: const InputDecoration(
//           hintText: "Enter IELTS Topic",
//           border: OutlineInputBorder(),
//         ),
//       ),
//     );
//   }

//   Widget _levelDropdown() {
//     return Container(
//       padding: const EdgeInsets.all(16),
//       decoration: _card(),
//       child: DropdownButtonFormField(
//         value: selectedLevel,
//         items: levels
//             .map((e) => DropdownMenuItem(value: e, child: Text(e)))
//             .toList(),
//         onChanged: (val) {
//           setState(() => selectedLevel = val!);
//         },
//       ),
//     );
//   }

//   Widget _generateButton() {
//     return SizedBox(
//       width: double.infinity,
//       child: ElevatedButton(
//         onPressed: isLoading ? null : generateVocabulary,
//         child: isLoading
//             ? const CircularProgressIndicator(color: Colors.white)
//             : const Text("Generate Vocabulary"),
//       ),
//     );
//   }

//   Widget _resultList() {
//     if (vocabList.isEmpty) return const SizedBox();

//     return Column(
//       children: List.generate(vocabList.length, (i) {
//         final item = vocabList[i];
//         final word = item["word"];

//         return GestureDetector(
//           onTap: () => showWordDetail(word), // 🔥 AI DETAIL
//           child: Container(
//             margin: const EdgeInsets.only(bottom: 12),
//             padding: const EdgeInsets.all(16),
//             decoration: _card(),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Row(
//                   mainAxisAlignment:
//                       MainAxisAlignment.spaceBetween,
//                   children: [
//                     Text(
//                       word ?? "",
//                       style: const TextStyle(
//                           fontSize: 16,
//                           fontWeight: FontWeight.bold),
//                     ),
//                     Row(
//                       children: [
//                         IconButton(
//                           icon: const Icon(Icons.volume_up),
//                           onPressed: () => speak(word),
//                         ),
//                         IconButton(
//                           icon: Icon(
//                             bookmarkedWords.contains(word)
//                                 ? Icons.bookmark
//                                 : Icons.bookmark_border,
//                             color: Colors.blue,
//                           ),
//                           onPressed: () => toggleBookmark(item),
//                         ),
//                       ],
//                     )
//                   ],
//                 ),
//                 const SizedBox(height: 6),
//                 Text("Meaning: ${item["meaning"]}"),
//                 Text("Example: ${item["example"]}"),
//                 Text("Synonym: ${item["synonym"]}"),
//               ],
//             ),
//           ),
//         );
//       }),
//     );
//   }

//   BoxDecoration _card() {
//     return BoxDecoration(
//       color: Colors.white,
//       borderRadius: BorderRadius.circular(14),
//       boxShadow: [
//         BoxShadow(
//           color: Colors.black.withOpacity(0.05),
//           blurRadius: 10,
//         )
//       ],
//     );
//   }
// }