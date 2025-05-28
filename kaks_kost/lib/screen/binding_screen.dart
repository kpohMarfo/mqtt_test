// lib/screens/binding_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../service/firestore_service.dart';

class BindingScreen extends StatefulWidget {
  @override
  _BindingScreenState createState() => _BindingScreenState();
}

class _BindingScreenState extends State<BindingScreen> {
  final TextEditingController deviceIdController = TextEditingController();
  String errorMessage = '';
  bool loading = false;

  Future<void> handleBinding() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print("❌ Tidak ada user yang login");
    return;
  }

  final deviceId = deviceIdController.text.trim();
  print("🔗 Mulai binding ke device ID: $deviceId");

  if (deviceId.isEmpty) {
    setState(() => errorMessage = 'Device ID tidak boleh kosong.');
    return;
  }

  setState(() {
    loading = true;
    errorMessage = '';
  });

  try {
    await FirestoreService().bindUserKeKamar(deviceId);
    print("✅ Binding sukses ke $deviceId");
    Navigator.pushReplacementNamed(context, '/dashboard');
  } catch (e) {
    print("❌ Gagal binding: $e");
    setState(() => errorMessage = 'Gagal menghubungkan perangkat.');
  } finally {
    setState(() => loading = false);
  }
}

  @override
  Widget build(BuildContext context) {
      print('📍 LoginScreen dibangun');
    return Scaffold(
      appBar: AppBar(title: Text('Hubungkan Kamar')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: deviceIdController,
              decoration: InputDecoration(
                labelText: 'Masukkan ID Kamar / Device',
              ),
            ),
            SizedBox(height: 20),
            if (errorMessage.isNotEmpty)
              Text(errorMessage, style: TextStyle(color: Colors.red)),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: loading ? null : handleBinding,
              child: loading ? CircularProgressIndicator(color: Colors.white) : Text('Hubungkan'),
            ),
          ],
        ),
      ),
    );
  }
}
