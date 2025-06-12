// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import '../service/auth_service.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String errorMessage = '';
  bool loading = false;

 void login() async {
  setState(() => loading = true);
  print("📥 Login attempt for: ${emailController.text}");
  final user = await AuthService().signIn(
    emailController.text.trim(),
    passwordController.text.trim(),
  );
  setState(() => loading = false);

  if (user != null) {
    
    print("✅ Login success. UID: ${user.uid}");
    Navigator.pushReplacementNamed(context, '/binding');
  } else {
    print("❌ Login failed.");
    setState(() => errorMessage = 'Login gagal. Periksa email dan password.');
  }
}

  // Di dalam class _LoginScreenState di file lib/screens/login_screen.dart
@override
Widget build(BuildContext context) {
  print('📍 LoginScreen dibangun (VERSI SANGAT SEDERHANA)');
  return const Scaffold(
    body: Center(
      child: Text('Ini adalah Login Screen tes'),
    ),
  );
}
}
