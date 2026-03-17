// // lib/services/user_service.dart
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
//
// class UserService {
//   final FirebaseAuth _auth = FirebaseAuth.instance;
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//
//   /// ✅ Get current logged-in user
//   User? get currentUser => _auth.currentUser;
//
//   /// ✅ Fetch user data from Firestore
//   Future<Map<String, dynamic>?> getUserData() async {
//     final user = _auth.currentUser;
//     if (user == null) return null;
//
//     final doc = await _firestore.collection('users').doc(user.uid).get();
//     return doc.data();
//   }
//
//   /// ✅ Save or update user data in Firestore
//   Future<void> updateUserData({
//     required String name,
//     required String email,
//     required String phone,
//   }) async {
//     final user = _auth.currentUser;
//     if (user == null) return;
//
//     // Update Firestore
//     await _firestore.collection('users').doc(user.uid).update({
//       'name': name.trim(),
//       'email': email.trim(),
//       'phone': phone.trim(),
//       'updatedAt': FieldValue.serverTimestamp(),
//     });
//
//     // Update FirebaseAuth profile
//     await user.updateDisplayName(name.trim());
//   }
//
//   /// ✅ Logout user
//   Future<void> signOut() async {
//     await _auth.signOut();
//   }
// }