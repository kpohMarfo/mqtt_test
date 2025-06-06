// lib/screen/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kaks_kost/service/firestore_service.dart';
import 'package:kaks_kost/service/mqtt_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class DashboardPage extends StatefulWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final mqttService = MQTTService();
  String? kamarId;
  String mqttStatus = 'Menghubungkan...';
  String lastNotif = '-';

  int? mq2Value;
  bool mq2AlertSent = false;

  // Variabel untuk suhu/kelembaban dikomentari
  // double? temperature;
  // double? humidity;

  bool isLampuOn = false; // <<< Diaktifkan kembali
  // bool isPintuTerkunci = true; // Kontrol pintu dinonaktifkan
  bool pirAlertSent = false;
  bool gasAlertSent = false;

  @override
  void initState() {
    super.initState();
    _fetchKamarIdAndSetupMQTT();
  }

  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'alert_channel',
      'Peringatan Keamanan Kost',
      channelDescription: 'Notifikasi penting dari sistem keamanan kost',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformChannelSpecifics,
      payload: 'security_alert_payload',
    );
  }

  Future<void> _fetchKamarIdAndSetupMQTT() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    kamarId = await FirestoreService().getKamarUser(user.uid);

    print('DEBUG Dashboard: kamarId dari Firestore: $kamarId');

    if (kamarId != null) {
      mqttService.connect(kamarId!);
      mqttService.statusStream.listen((status) {
        if (mounted) {
          setState(() => mqttStatus = status);
        }
      });

      mqttService.messageStream.listen((data) {
        if (mounted) {
          final topic = data['topic'] ?? '';
          final message = data['message'] ?? '';

          print(
              'DEBUG Dashboard: Pesan Diterima - Topik: $topic, Pesan: $message');
          print('DEBUG Dashboard: Kamar ID Pengguna Saat Ini: $kamarId');

          // --- Client-Side Filtering & Authorization ---
          bool isTopicRelevant = topic.startsWith('$kamarId/') ||
              topic.startsWith('kamar/$kamarId/') ||
              topic == 'esp32/mq2' ||
              topic == '$kamarId/status/lampu'; // <<< Topik lampu relevan

          if (isTopicRelevant) {
            print('DEBUG Dashboard: Topik relevan untuk kamar ini.');

            // Handle pesan MQ2
            if (topic == 'esp32/mq2') {
              setState(() {
                try {
                  mq2Value = int.parse(message);

                  if (mq2Value! >= 3000) {
                    if (!mq2AlertSent) {
                      lastNotif =
                          '🚨 Peringatan! Gas Terdeteksi (${mq2Value})!';
                      mq2AlertSent = true;
                      _showLocalNotification('Peringatan Gas!',
                          'Deteksi gas berbahaya. Nilai MQ2: ${mq2Value}.');
                    }
                  } else {
                    if (mq2AlertSent) {
                      lastNotif = '✅ Area aman dari gas.';
                      mq2AlertSent = false;
                    } else if (lastNotif == '-') {
                      lastNotif = 'Tidak ada notifikasi baru.';
                    }
                  }
                } catch (e) {
                  print("Error parsing MQ2 value: $e");
                  mq2Value = null;
                  lastNotif = 'Error membaca nilai gas.';
                }
              });
            }
            // Handle notifikasi umum dari kamar ini (asap, gerakan)
            else if (topic == 'kamar/$kamarId/notif') {
              setState(() {
                if (message == 'asap_terdeteksi') {
                  lastNotif = '🚨 Asap terdeteksi!';
                  if (!gasAlertSent) {
                    _showLocalNotification(
                        'Peringatan Asap!', 'Asap terdeteksi di kamar Anda!');
                    gasAlertSent = true;
                  }
                } else if (message.contains('gerakan_terdeteksi')) {
                  lastNotif = '🔔 Gerakan terdeteksi!';
                  if (!pirAlertSent) {
                    _showLocalNotification('Peringatan Gerakan!',
                        'Gerakan terdeteksi di kamar Anda!');
                    pirAlertSent = true;
                  }
                } else {
                  if (message == "asap_aman") {
                    gasAlertSent = false;
                    lastNotif = '✅ Area aman dari asap.';
                  }
                  if (message == "gerakan_aman") {
                    pirAlertSent = false;
                    lastNotif = '✅ Area aman dari gerakan.';
                  }
                }
              });
            }
            // Handle status lampu
            else if (topic == '$kamarId/status/lampu') {
              // <<< Logika status lampu
              setState(() {
                isLampuOn =
                    (message == 'on'); // Update state lampu berdasarkan pesan
              });
            }
            // Topik lain yang tidak digunakan di setup debugging ini dikomentari
            // else if (topic == '$kamarId/telemetry/temperature') { /* ... */ }
            // else if (topic == '$kamarId/telemetry/humidity') { /* ... */ }
            // else if (topic == '$kamarId/status/pintu') { /* ... */ }
          } else {
            print(
                'DEBUG Dashboard: Pesan dari kamar lain atau topik tidak relevan: $topic. Kamar ID pengguna: $kamarId');
          }
        }
      });
    } else {
      if (mounted) {
        setState(() {
          mqttStatus = '❌ Belum bind ke kamar.';
        });
        Navigator.pushReplacementNamed(context, '/binding');
      }
    }
  }

  void kontrolLampu() {
    // <<< Fungsi kontrol lampu
    if (kamarId == null) return;
    final topic = '$kamarId/lampu'; // Topik kontrol lampu
    final command = isLampuOn ? 'off' : 'on';
    mqttService.publish(topic, command); // Kirim perintah ke ESP32
    // setState(() => isLampuOn = !isLampuOn); // Update UI segera setelah kirim perintah (opsional, bisa tunggu balasan status dari ESP32)
  }

  // Fungsi kontrol pintu dikomentari untuk setup debugging ini
  // void kontrolPintu() { /* ... */ }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    print('📍 DashboardPage dibangun');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Keamanan'),
        actions: [
          IconButton(onPressed: logout, icon: const Icon(Icons.logout)),
        ],
      ),
      body: kamarId == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Status MQTT: $mqttStatus'),
                  const SizedBox(height: 10),
                  Text('Notifikasi: $lastNotif',
                      style: TextStyle(
                          fontSize: 16,
                          color: (mq2AlertSent || pirAlertSent || gasAlertSent)
                              ? Colors.red
                              : Colors.black)),
                  const Divider(),
                  Text('Nilai Gas MQ2: ${mq2Value?.toString() ?? '-'}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  // Display suhu/kelembaban dikomentari
                  // Text('Suhu: ${temperature?.toStringAsFixed(1) ?? '-'} °C', style: const TextStyle(fontSize: 16)),
                  // Text('Kelembaban: ${humidity?.toStringAsFixed(1) ?? '-'} %', style: const TextStyle(fontSize: 16)),
                  const Divider(),
                  const Text('Kontrol Perangkat:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    // <<< Baris kontrol lampu diaktifkan
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: null, // Kontrol pintu dinonaktifkan
                          child: const Text('Kontrol Pintu (Nonaktif)'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: kontrolLampu, // <<< Diaktifkan
                          child: Text(
                              isLampuOn ? 'Matikan Lampu' : 'Nyalakan Lampu'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
