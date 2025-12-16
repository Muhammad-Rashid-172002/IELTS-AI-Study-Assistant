


import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
// import 'package:intl/intl.dart';

import '../../resources/routes/routes_names.dart';

class FirebaseServices extends GetxController {
  final FirebaseAuth auth = FirebaseAuth.instance;
  User? get user => auth.currentUser;

  // Reactive user data
  final RxMap<String, dynamic> userData = <String, dynamic>{}.obs;

  // Loading states
  final loadingLoginL = false.obs;
  final loadingGoogleL = false.obs;
  final loadingRegistration = false.obs;

  // Password visibility
  final isPasswordVisibleR = false.obs;
  final isPasswordVisibleRE = false.obs;
  final isPasswordVisibleL = false.obs;

  void togglePasswordVisibility() => isPasswordVisibleR.toggle();
  void toggleConfirmPasswordVisibility() => isPasswordVisibleRE.toggle();
  void togglePasswordVisibilityL() => isPasswordVisibleL.toggle();

  // Phone validation
  var phoneValid = false.obs;
  void setPhoneValid(bool value) => phoneValid.value = value;

  // Firestore listener
  StreamSubscription<DocumentSnapshot>? _userListener;


  // REGISTRATION

  Future<void> registration({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    loadingRegistration.value = true;

    try {
      UserCredential userCredential =
      await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = userCredential.user;

      if (user != null) {
        await user.updateDisplayName(fullName);
        await saveUserToFirestore(user, fullName: fullName, phone: phone);

        // Load AND sync real-time
        await loadUserProfile();

        Get.snackbar(
          "Success",
          "Registration Completed",
          backgroundColor: Colors.green,
          colorText: Colors.white,
        );

        Get.offAllNamed(RoutesName.home);
      }
    } catch (e) {
      Get.snackbar("Error", e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      loadingRegistration.value = false;
    }
  }

  // LOGIN (EMAIL/PASSWORD)

  Future<void> login({
    required String email,
    required String password,
  }) async {
    loadingLoginL.value = true;

    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);

      await loadUserProfile();

      Get.snackbar(
        "Success",
        "Login Completed",
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );

      Get.offAllNamed(RoutesName.home);
    } catch (e) {
      Get.snackbar("Error", e.toString(),
          backgroundColor: Colors.red, colorText: Colors.white);
    } finally {
      loadingLoginL.value = false;
    }
  }



  // --------------------------------------------------------
  // GOOGLE LOGIN
  // --------------------------------------------------------
  Future<User?> loginWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn(scopes: ['email']);
      await googleSignIn.signOut();

      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
      await auth.signInWithCredential(credential);

      final user = userCredential.user;

      if (user != null) {
        await saveUserToFirestore(user, fullName: user.displayName);
        await loadUserProfile();
      }

      Get.offAllNamed(RoutesName.home);
      return user;
    } catch (e) {
      Get.snackbar("Error", e.toString());
      return null;
    }
  }

  // --------------------------------------------------------
  // SAVE USER TO FIRESTORE (WITH INITIAL PROGRESS)
  // --------------------------------------------------------
  Future<void> saveUserToFirestore(
      User user, {
        String? fullName,
        String? phone,
      }) async {
    final ref =
    FirebaseFirestore.instance.collection('users').doc(user.uid);

    final snapshot = await ref.get();

    if (!snapshot.exists) {
      await ref.set({
        'uid': user.uid,
        'name': fullName ?? user.displayName ?? '',
        'email': user.email ?? '',
        'phone': phone ?? user.phoneNumber ?? '',
        'profileImage': user.photoURL ?? '',
        'createdAt': FieldValue.serverTimestamp(),
        'lastReset': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'lastActive': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'streak': 1,
        'longestStreak': 1,


        // Progress fields
        'progress': {
          'summaries': 0,
          'questions': 0,
          'solved': 0,
        },
      });
    } else {
      await ref.update({
        'name': fullName ?? user.displayName ?? '',
        'phone': phone ?? user.phoneNumber ?? '',
        'email': user.email ?? '',
        'profileImage': user.photoURL ?? '',
      });
    }
  }

  Future<void> updateStreak() async {
    if (user == null) return;

    final uid = user!.uid;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final ref = FirebaseFirestore.instance.collection("users").doc(uid);
    final doc = await ref.get();

    if (!doc.exists) return;

    final data = doc.data()!;
    final lastActive = data['lastActive'] ?? today;
    int streak = data['streak'] ?? 1;
    int longestStreak = data['longestStreak'] ?? 1;

    // --- CASE 1: SAME DAY → do nothing
    if (lastActive == today) return;

    // --- CASE 2: YESTERDAY → streak +1
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yKey = DateFormat('yyyy-MM-dd').format(yesterday);

    if (lastActive == yKey) {
      streak += 1;
      if (streak > longestStreak) longestStreak = streak;
    } else {
      // --- CASE 3: Missed a day → streak resets
      streak = 1;
    }

    await ref.update({
      "lastActive": today,
      "streak": streak,
      "longestStreak": longestStreak,
    });

    // update local reactive memory
    userData['streak'] = streak;
    userData['longestStreak'] = longestStreak;
    userData['lastActive'] = today;
    userData.refresh();
  }

  Future<void> loadUserProfile() async {
    if (user == null) {
      print("❌ loadUserProfile(): user == null");
      return;
    }

    print("🔄 loadUserProfile(): START for UID = ${user!.uid}");

    _userListener?.cancel();

    _userListener = FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .snapshots()
        .listen((doc) async {
      print("📥 loadUserProfile(): Firestore snapshot received");

      if (doc.exists) {
        final data = doc.data()!;
        print("📌 Firestore user data => $data");

        // Update RxMap
        userData.assignAll(data);
        userData.refresh();
        print("✅ userData updated => ${userData}");

        await updateStreak();

        final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final lastReset = data['lastReset'] ?? today;

        print("📅 lastReset = $lastReset | today = $today");

        if (!data.containsKey('lastReset')) {
          print("⚠️ lastReset missing → writing to Firestore");
          await FirebaseFirestore.instance
              .collection("users")
              .doc(user!.uid)
              .update({"lastReset": today});
        }

        if (lastReset != today) {
          print("🔄 Progress reset triggered");
          await resetProgress();
        }
      } else {
        print("❌ loadUserProfile(): doc DOES NOT exist");
      }
    });
  }


  Future<void> ensureProgressExists() async {
    if (user == null) return;

    final ref = FirebaseFirestore.instance.collection("users").doc(user!.uid);
    final doc = await ref.get();

    if (doc.exists) {
      final data = doc.data()!;
      if (!data.containsKey("progress")) {
        await ref.update({
          "progress": {
            "summaries": 0,
            "questions": 0,
            "solved": 0,
          }
        });
      }
    }
  }

  Future<void> resetProgress() async {
    if (user == null) return;

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await FirebaseFirestore.instance.collection("users").doc(user!.uid).update({
      "progress": {"summaries": 0, "questions": 0, "solved": 0},
      "lastReset": today,
    });
  }

  Future<Map<String, dynamic>> getTodayProgress() async {
    if (user == null) return {};

    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('daily_progress')
        .doc(today)
        .get();

    return doc.exists ? doc.data()! : {
      "summaries": 0,
      "questions": 0,
      "solved": 0,
    };
  }


  // --------------------------------------------------------
  // UPDATE USER PROFILE
  // --------------------------------------------------------
  Future<void> updateFirestoreProfile({
    required String name,
    required String phone,
  }) async {
    if (user == null) return;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(user!.uid)
        .update({
      "name": name,
      "phone": phone,
    });

    await user!.updateDisplayName(name);
  }


// LOGOUT

  Future<void> signOut() async {
    try {
      await auth.signOut();
      userData.clear(); // Clear cached user data
    } catch (e) {
      Get.snackbar(
        "Error",
        "Failed to logout",
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  
  // UPDATE DAILY PROGRESS (TIMESTAMP)

  Future<void> updateDailyProgress({
    required int summaries,
    required int questions,
    required int solved,
  }) async {
    if (user == null) {
      print("❌ updateDailyProgress(): user == null");
      return;
    }

    print("🚀 updateDailyProgress() called: S:$summaries Q:$questions M:$solved");

    final uid = user!.uid;

    final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
    print("📅 todayKey = $todayKey");

    final dailyRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('daily_progress')
        .doc(todayKey);

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    await ensureProgressExists();

    await FirebaseFirestore.instance.runTransaction((txn) async {
      print("🔁 Firestore transaction started...");

      final dailySnap = await txn.get(dailyRef);

      if (!dailySnap.exists) {
        print("🆕 Creating new daily progress document");
        txn.set(dailyRef, {
          "summaries": summaries,
          "questions": questions,
          "solved": solved,
          "date": Timestamp.now(),
        });
      } else {
        print("📈 Updating existing daily progress document");
        txn.update(dailyRef, {
          "summaries": FieldValue.increment(summaries),
          "questions": FieldValue.increment(questions),
          "solved": FieldValue.increment(solved),
        });
      }
      print("🔐 updateDailyProgress(): user = ${user?.uid}");

      print("📌 Incrementing MAIN progress counters...");
      txn.update(userRef, {
        "progress.summaries": FieldValue.increment(summaries),
        "progress.questions": FieldValue.increment(questions),
        "progress.solved": FieldValue.increment(solved),
      });
    });

    print("✅ updateDailyProgress(): SUCCESS");

    await updateStreak();
  }




  Future<List<Map<String, dynamic>>> getWeeklyProgress() async {
    if (user == null) return [];

    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 6));

    final query = await FirebaseFirestore.instance
        .collection('users')
        .doc(user!.uid)
        .collection('daily_progress')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(weekAgo))
        .orderBy('date')
        .get();

    return query.docs.map((e) => e.data()).toList();
  }


  //------------------------
  //SAVED SYSTEM
  //------------------------

  Future<void> saveItem({
    required String type,
    required String title,
    required dynamic content,
  }) async {
    final uid = user!.uid;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("saved_items")
        .add({
      "type": type,
      "title": title,
      "content": content,
      "timestamp": FieldValue.serverTimestamp(),
    });
  }
  Future<void> deleteItem(String docId) async {
    final uid = user!.uid;

    await FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("saved_items")
        .doc(docId)
        .delete();
  }
  Stream<QuerySnapshot> getSavedItems() {
    final uid = user!.uid;

    return FirebaseFirestore.instance
        .collection("users")
        .doc(uid)
        .collection("saved_items")
        .orderBy("timestamp", descending: true)
        .snapshots();
  }




  // --------------------------------------------------------
  // CLEANUP LISTENER
  // --------------------------------------------------------
  @override
  void onClose() {
    _userListener?.cancel();
    super.onClose();
  }
}
