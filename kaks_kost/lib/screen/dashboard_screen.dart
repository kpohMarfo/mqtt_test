import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kaks_kost/service/firestore_service.dart';
import 'package:kaks_kost/service/mqtt_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Definisikan instance plugin notifikasi lokal yang sama dengan di main.dart
// Pastikan nama variabelnya sama dengan yang di main.dart
// Jika variabel ini dideklarasikan di main.dart, Anda mungkin perlu memastikan
// ia diakses dengan benar (misalnya, sebagai global atau diteruskan).
// Jika ada error 'undefined_identifier' di sini, hapus 'extern'.
// flutterLocalNotificationsPlugin dideklarasikan sebagai global di main.dart,
// jadi ini seharusnya bisa diakses.
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

  @override
  void initState() {
    super.initState();
    _fetchKamarIdAndSetupMQTT();
  }

  // Fungsi untuk menampilkan notifikasi lokal
  Future<void> _showLocalNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'mq2_alert_channel', // ID channel notifikasi unik
      'Peringatan Gas MQ2', // Nama channel notifikasi yang terlihat pengguna
      channelDescription:
          'Notifikasi untuk deteksi gas berbahaya dari sensor MQ2', // Deskripsi channel
      importance: Importance.max, // Pentingnya notifikasi (muncul di atas)
      priority: Priority.high, // Prioritas notifikasi
      showWhen: false,
    );
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin.show(
      0, // ID notifikasi (unik untuk setiap notifikasi)
      title, // Judul notifikasi
      body, // Isi notifikasi
      platformChannelSpecifics,
      payload: 'mq2_alert_payload', // Payload opsional
    );
  }

  Future<void> _fetchKamarIdAndSetupMQTT() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    kamarId = await FirestoreService().getKamarUser(user.uid);

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

          if (topic == 'esp32/mq2') {
            setState(() {
              try {
                mq2Value = int.parse(message);

                if (mq2Value! >= 3000) {
                  if (!mq2AlertSent) {
                    lastNotif = '🚨 Peringatan! Gas Terdeteksi (${mq2Value})!';
                    mq2AlertSent = true;
                    // Tampilkan notifikasi lokal
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
                          color: mq2AlertSent ? Colors.red : Colors.black)),
                  const Divider(),
                  Text('Nilai Gas MQ2: ${mq2Value?.toString() ?? '-'}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const Divider(),
                  const Text('Kontrol Perangkat:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  const Text(
                      'Tombol kontrol sementara dinonaktifkan untuk pengujian MQ2.',
                      style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
    );
  }
}
