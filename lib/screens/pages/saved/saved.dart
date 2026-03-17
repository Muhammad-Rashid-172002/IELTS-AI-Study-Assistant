// import 'package:flutter/material.dart';
//
// import '../../../resources/bottom_navigation_bar/botton_navigation.dart';
//
//
// class Saved extends StatefulWidget {
//   const Saved({super.key});
//
//   @override
//   State<Saved> createState() => _SavedState();
// }
//
// class _SavedState extends State<Saved> {
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Saved'),
//       ),
//       bottomNavigationBar: BottomNavigation(index: 2,),
//       body: Column(
//         children: [
//
//         ],
//       ),
//     );
//   }
// }

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../controller/firebase_services/firebase_services.dart';
import '../../../resources/bottom_navigation_bar/botton_navigation.dart';

class Saved extends StatelessWidget {
  Saved({super.key});

  final FirebaseServices fs = Get.find<FirebaseServices>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Saved Items")),
      bottomNavigationBar: const BottomNavigation(index: 2),

      body: StreamBuilder<QuerySnapshot>(
        stream: fs.getSavedItems(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No saved items yet",
                style: TextStyle(fontSize: 18),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _savedItemCard(
                id: doc.id,
                type: data["type"],
                title: data["title"],
                content: data["content"],
              );
            },
          );
        },
      ),
    );
  }
  Widget _savedItemCard({
    required String id,
    required String type,
    required String title,
    required dynamic content,
  }) {
    IconData icon;
    Color color;

    switch (type) {
      case "summary":
        icon = Icons.description;
        color = Colors.blue;
        break;
      case "mcq":
        icon = Icons.quiz_outlined;
        color = Colors.green;
        break;
      case "math":
        icon = Icons.calculate_outlined;
        color = Colors.purple;
        break;
      default:
        icon = Icons.save;
        color = Colors.grey;
    }

    // SAFE PREVIEW
    final preview = content.toString();
    final safePreview = preview.length > 120
        ? preview.substring(0, 120) + "..."
        : preview;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: color, size: 26),
                    const SizedBox(width: 10),
                    Text(
                      title.length > 30 ? "${title.substring(0, 30)}..." : title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),

                GestureDetector(
                  onTap: () => fs.deleteItem(id),
                  child: const Icon(Icons.delete, color: Colors.red, size: 22),
                )
              ],
            ),

            const SizedBox(height: 14),

            Text(
              safePreview,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

}
