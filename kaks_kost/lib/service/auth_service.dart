import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Login menggunakan email dan password
  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } catch (e) {
      print("Login gagal: $e");
      return null;
    }
  }

  /// Logout user saat ini
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// User yang sedang login
  User? get currentUser => _auth.currentUser;

  /// Cek apakah sudah login
  bool get isLoggedIn => _auth.currentUser != null;
}
