import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'screen/login_screen.dart';
import 'screen/binding_screen.dart';
import 'screen/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String> _getInitialRoute() async {
    print('DEBUG: _getInitialRoute dipanggil');
    final user = FirebaseAuth.instance.currentUser;
    print('DEBUG: user dari FirebaseAuth: $user');
    if (user == null) {
      print('DEBUG: User adalah null, mengembalikan /login');
      return '/login';
    }

    print('DEBUG: User tidak null, UID: ${user.uid}');

    try {
      print('DEBUG: Mencoba mendapatkan dokumen Firestore untuk user: ${user.uid}');
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      print('DEBUG: Dokumen Firestore berhasil diambil. Exists: ${doc.exists}');
      final data = doc.data();
      print('DEBUG: Data dokumen: $data');
      final hasBinding = data != null && data['kamar_id'] != null;
      print('DEBUG: hasBinding: $hasBinding');
      return hasBinding ? '/dashboard' : '/binding';
    } catch (e) {
      print("🔥 Error saat membaca Firestore: $e");
      return '/login';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _getInitialRoute(),
      builder: (context, snapshot) {
        print('📦 snapshot connectionState: ${snapshot.connectionState}');
        print('📦 snapshot hasData: ${snapshot.hasData}');
        print('📦 snapshot data: ${snapshot.data}');

        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final initialRoute = snapshot.data ?? '/login';
        print('📦 Initial route to use: $initialRoute');

        // Perubahan utama di sini:
        // Jika initialRoute adalah '/login', kita langsung set home ke LoginScreen.
        // Jika tidak, kita gunakan Navigator.pushReplacementNamed setelah MaterialApp dibangun.
        if (initialRoute == '/login') {
          return MaterialApp(
            title: 'Kost Security App',
            theme: ThemeData.light(),
            debugShowCheckedModeBanner: false,
            home: LoginScreen(), // Langsung set home ke LoginScreen
            routes: {
              // Routes lain tetap ada, tapi '/login' tidak perlu di sini
              // karena sudah ditangani oleh 'home'
              '/binding': (context) {
                print('🔁 Navigating to BindingScreen');
                return BindingScreen();
              },
              '/dashboard': (context) {
                print('🔁 Navigating to DashboardPage');
                return DashboardPage();
              },
            },
          );
        } else {
          // Untuk rute selain '/login', kita perlu Navigator untuk pindah
          return MaterialApp(
            title: 'Kost Security App',
            theme: ThemeData.light(),
            debugShowCheckedModeBanner: false,
            // initialRoute tidak digunakan di sini karena kita akan pushReplacement
            home: Builder( // Gunakan Builder untuk mendapatkan BuildContext yang valid
              builder: (BuildContext innerContext) {
                // Pastikan pushReplacementNamed dipanggil setelah frame pertama dibangun
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacementNamed(innerContext, initialRoute);
                });
                // Tampilkan CircularProgressIndicator sementara navigasi terjadi
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              },
            ),
            routes: {
              '/login': (context) {
                print('🔁 Navigating to LoginScreen');
                return LoginScreen();
              },
              '/binding': (context) {
                print('🔁 Navigating to BindingScreen');
                return BindingScreen();
              },
              '/dashboard': (context) {
                print('🔁 Navigating to DashboardPage');
                return DashboardPage();
              },
            },
          );
        }
      },
    );
  }
}
