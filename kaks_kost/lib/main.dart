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
    print('DEBUG: _getInitialRoute dipanggil'); // Debug print
    final user = FirebaseAuth.instance.currentUser;
    print('DEBUG: user dari FirebaseAuth: $user'); // Debug print
    if (user == null) {
      print('DEBUG: User adalah null, mengembalikan /login'); // Debug print
      return '/login';
    }

    print('DEBUG: User tidak null, UID: ${user.uid}'); // Debug print

    try {
      print('DEBUG: Mencoba mendapatkan dokumen Firestore untuk user: ${user.uid}'); // Debug print
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      print('DEBUG: Dokumen Firestore berhasil diambil. Exists: ${doc.exists}'); // Debug print
      final data = doc.data();
      print('DEBUG: Data dokumen: $data'); // Debug print
      final hasBinding = data != null && data['kamar_id'] != null;
      print('DEBUG: hasBinding: $hasBinding'); // Debug print
      return hasBinding ? '/dashboard' : '/binding';
    } catch (e) {
      print("🔥 Error saat membaca Firestore: $e"); // Debug print
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

        return MaterialApp(
          title: 'Kost Security App',
          theme: ThemeData.light(), // Tetap pakai tema sederhana
          debugShowCheckedModeBanner: false,
          initialRoute: initialRoute,
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
      },
    );
  }
}
