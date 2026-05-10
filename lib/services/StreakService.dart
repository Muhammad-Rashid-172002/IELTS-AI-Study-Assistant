import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class StreakService {
  static Future<void> updateUserStreak() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(uid);

    final doc = await userRef.get();

    if (!doc.exists) return;

    final data = doc.data()!;

    int currentStreak = data['streak'] ?? 0;

    Timestamp? lastActiveTimestamp = data['lastActive'];

    DateTime today = DateTime.now();

    /// Remove time
    DateTime currentDate =
        DateTime(today.year, today.month, today.day);

    if (lastActiveTimestamp == null) {
      /// First time login
      await userRef.update({
        'streak': 0,
        'lastActive': Timestamp.fromDate(currentDate),
      });

      return;
    }

    DateTime lastActive = lastActiveTimestamp.toDate();

    DateTime lastDate =
        DateTime(lastActive.year, lastActive.month, lastActive.day);

    int difference = currentDate.difference(lastDate).inDays;

    if (difference == 0) {
      /// Already opened today
      return;
    } else if (difference == 1) {
      /// Continue streak
      currentStreak += 0;
    } else {
      /// Missed days → reset
      currentStreak = 1;
    }

    await userRef.update({
      'streak': currentStreak,
      'lastActive': Timestamp.fromDate(currentDate),
    });
  }
}