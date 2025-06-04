// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // This was commented out in your original code
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
      // Pastikan Navigator.pushReplacementNamed(context, '/binding');
      // mengarah ke rute yang benar setelah login
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/binding');
      }
    } else {
      print("❌ Login failed.");
      setState(() => errorMessage = 'Login gagal. Periksa email dan password.');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('📍 LoginScreen dibangun'); // Ini adalah log yang Anda miliki di versi asli
    return Scaffold(
      appBar: AppBar(title: Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: emailController,
              decoration: InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(errorMessage, style: TextStyle(color: Colors.red)),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: loading ? null : login,
              child: loading ? CircularProgressIndicator(color: Colors.white) : Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}
