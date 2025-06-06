import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'; // Import ini

import 'screen/login_screen.dart';
import 'screen/binding_screen.dart';
import 'screen/dashboard_screen.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin(); // Global instance

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // --- Inisialisasi Notifikasi Lokal ---
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); // Icon notifikasi

  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);

  await flutterLocalNotificationsPlugin.initialize(initializationSettings,
      onDidReceiveNotificationResponse:
          (NotificationResponse notificationResponse) async {
    // Handle tap notifikasi jika aplikasi berjalan (foreground)
    // atau jika notifikasi diketuk dari latar belakang/ditutup
    print('Notifikasi diketuk!');
    if (notificationResponse.payload != null) {
      debugPrint('payload notifikasi: ${notificationResponse.payload}');
      // Anda bisa menambahkan logika navigasi di sini berdasarkan payload
    }
  });
  // --- Akhir Inisialisasi Notifikasi Lokal ---

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<String> _getInitialRoute() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return '/login';

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      final hasBinding = data != null && data['kamar_id'] != null;
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

        if (initialRoute == '/login') {
          return MaterialApp(
            title: 'Kost Security App',
            theme: ThemeData.light(),
            debugShowCheckedModeBanner: false,
            home: LoginScreen(),
            routes: {
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
          return MaterialApp(
            title: 'Kost Security App',
            theme: ThemeData.light(),
            debugShowCheckedModeBanner: false,
            home: Builder(
              builder: (BuildContext innerContext) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  Navigator.pushReplacementNamed(innerContext, initialRoute);
                });
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
