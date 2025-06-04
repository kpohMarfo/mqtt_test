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
      // Mungkin arahkan kembali ke login jika tidak ada user
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    final deviceId = deviceIdController.text.trim();
    print("🔗 Mulai binding ke device ID: '$deviceId'"); // DEBUG: Periksa nilai deviceId

    if (deviceId.isEmpty) {
      setState(() => errorMessage = 'Device ID tidak boleh kosong.');
      print("⚠️ Device ID kosong, binding dibatalkan."); // DEBUG: Log jika kosong
      return; // Sangat penting: keluar dari fungsi jika kosong
    }

    setState(() {
      loading = true;
      errorMessage = '';
    });

    try {
      await FirestoreService().bindUserKeKamar(deviceId);
      print("✅ Binding sukses ke $deviceId");
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/dashboard');
      }
    } catch (e) {
      print("❌ Gagal binding: $e");
      setState(() => errorMessage = 'Gagal menghubungkan perangkat. Error: ${e.toString()}'); // Tampilkan error lebih detail
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('📍 BindingScreen dibangun'); // Perbaiki log ini
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)), // Tambahkan border agar lebih jelas
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
