// firebase Services

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';


class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn.standard().signIn();
      if (googleUser == null) return null; // user canceled

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential =
          await _auth.signInWithCredential(credential);

      return userCredential.user;
    } catch (e) {
      print("Google Login Error: $e");
      return null;
    }
  }
}
