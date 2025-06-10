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
      if (mounted) {
         Navigator.pushReplacementNamed(context, '/login');
      }
      return;
    }

    // Pembersihan dan validasi input yang lebih kuat
    String deviceId = deviceIdController.text.trim();
    // Hapus spasi berlebih dan karakter non-alphanumeric yang tidak diizinkan di awal/akhir
    // Kecuali underscore atau hyphen jika Anda mengizinkannya
    deviceId = deviceId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-]+'), ''); // Contoh: hanya izinkan huruf, angka, underscore, hyphen
    // deviceId = deviceId.toLowerCase(); // Opsional: paksa menjadi huruf kecil untuk konsistensi

    print("🔗 Mulai binding ke device ID (setelah pembersihan): '$deviceId'"); // DEBUG: Periksa nilai deviceId setelah dibersihkan

    if (deviceId.isEmpty) {
      setState(() => errorMessage = 'ID Kamar tidak boleh kosong atau mengandung karakter yang tidak valid.');
      print("⚠️ Device ID kosong atau tidak valid setelah pembersihan, binding dibatalkan.");
      return;
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
      setState(() => errorMessage = 'Gagal menghubungkan perangkat. Error: ${e.toString()}');
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    print('📍 BindingScreen dibangun');
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
                hintText: 'Contoh: kamar1, ruang_A', // Tambahkan hint
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
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
