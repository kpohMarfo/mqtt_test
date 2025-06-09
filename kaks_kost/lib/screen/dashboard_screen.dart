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
  // String lastNotif = '-'; // <<< Dihilangkan dari UI

  int? mq2Value;
  bool mq2AlertSent = false; // Untuk nilai MQ2 (>= 3000)

  bool pirAlertSent = false; // Untuk deteksi gerakan PIR
  bool gasAlertSent = false; // Untuk deteksi asap dari notif (kamar/+/notif)

  bool isLampuOn = false;

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
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
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
            'DEBUG Dashboard: Pesan Diterima - Topik: $topic, Pesan: $message',
          );
          print('DEBUG Dashboard: Kamar ID Pengguna Saat Ini: $kamarId');

          // --- Client-Side Filtering & Authorization ---
          bool isTopicRelevant =
              topic.startsWith('$kamarId/') ||
              topic.startsWith('kamar/$kamarId/') ||
              topic == 'esp32/mq2' ||
              topic == '$kamarId/status/lampu';

          if (isTopicRelevant) {
            print('DEBUG Dashboard: Topik relevan untuk kamar ini.');

            // Handle pesan MQ2
            if (topic == 'esp32/mq2') {
              setState(() {
                try {
                  mq2Value = int.parse(message);

                  if (mq2Value! >= 3000) {
                    if (!mq2AlertSent) {
                      mq2AlertSent = true;
                      _showLocalNotification(
                        '🚨 Peringatan Gas!',
                        'Deteksi gas berbahaya. Nilai MQ2: ${mq2Value}.',
                      );
                    }
                  } else {
                    mq2AlertSent = false;
                  }
                } catch (e) {
                  print("Error parsing MQ2 value: $e");
                  mq2Value = null;
                  mq2AlertSent = false;
                }
              });
            }
            // Handle notifikasi umum dari kamar ini (asap, gerakan)
            else if (topic == 'kamar/$kamarId/notif') {
              setState(() {
                if (message == 'asap_terdeteksi') {
                  if (!gasAlertSent) {
                    _showLocalNotification(
                      '🚨 Peringatan Asap!',
                      'Asap terdeteksi di kamar Anda!',
                    );
                    gasAlertSent = true;
                  }
                } else if (message.contains('gerakan_terdeteksi')) {
                  if (!pirAlertSent) {
                    _showLocalNotification(
                      '🔔 Peringatan Gerakan!',
                      'Gerakan terdeteksi di kamar Anda!',
                    );
                    pirAlertSent = true;
                  }
                } else {
                  if (message == "asap_aman") {
                    gasAlertSent = false;
                  }
                  if (message == "gerakan_aman") {
                    pirAlertSent = false;
                  }
                }
              });
            }
            // Handle status lampu
            else if (topic == '$kamarId/status/lampu') {
              setState(() {
                isLampuOn = (message == 'on');
              });
            }
          } else {
            print(
              'DEBUG Dashboard: Pesan dari kamar lain atau topik tidak relevan: $topic. Kamar ID pengguna: $kamarId',
            );
          }
        }
      });
    } else {
      if (mounted) {
        setState(() => mqttStatus = '❌ Belum bind ke kamar.');
        Navigator.pushReplacementNamed(context, '/binding');
      }
    }
  }

  void kontrolLampu() {
    if (kamarId == null) return;
    final topic = '$kamarId/lampu';
    final command = isLampuOn ? 'off' : 'on';
    mqttService.publish(topic, command);
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
      body:
          kamarId == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- Informasi Status (Tetap) ---
                    Text(
                      'Status MQTT: $mqttStatus',
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),

                    // --- Header "A total of X devices" (Contoh) ---
                    Text(
                      'A total of 3 devices',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kamar C8', // Atau nama kamar yang relevan
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- KARTU SENSOR BERSEBELAHAN (PIR Kiri Merah, MQ2 Kanan Biru/Ungu) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- KARTU STATUS SENSOR PIR (Kiri, Merah) ---
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 6.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 8,
                            // Warna kartu PIR: merah jika alert, default merah
                            color:
                                pirAlertSent
                                    ? Colors.red.shade600
                                    : Colors.red.shade400,
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Icon(
                                      pirAlertSent
                                          ? Icons.warning_rounded
                                          : Icons.person_search_rounded,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    'Deteksi Gerakan',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    pirAlertSent ? 'Terdeteksi!' : 'Aman',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // --- KARTU NILAI SENSOR MQ2 (Kanan, Biru/Ungu) ---
                        Expanded(
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 6.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            elevation: 8,
                            // Warna kartu MQ2: merah jika mq2AlertSent, default biru/ungu
                            color:
                                mq2AlertSent
                                    ? Colors.red.shade600
                                    : Colors
                                        .deepPurple
                                        .shade400, // <<< Perbaikan di sini
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Align(
                                    alignment: Alignment.topRight,
                                    child: Icon(
                                      mq2AlertSent
                                          ? Icons.warning_rounded
                                          : Icons
                                              .gas_meter_rounded, // <<< Perbaikan di sini
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    'Nilai Gas MQ2',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${mq2Value?.toString() ?? '-'}',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  Text(
                                    'ADC Value',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // --- AKHIR KARTU SENSOR BERSEBELAHAN ---

                    // --- KARTU KONTROL LAMPU (Gaya Mirip) ---
                    Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6.0,
                        vertical: 8.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                      elevation: 8,
                      color:
                          isLampuOn
                              ? Colors.deepOrange.shade400
                              : Colors.blueGrey.shade400,
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isLampuOn
                                      ? Icons.lightbulb_rounded
                                      : Icons.lightbulb_outline_rounded,
                                  size: 40,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Lampu Pintar',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 15),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Switch(
                                value: isLampuOn,
                                onChanged: (bool value) {
                                  kontrolLampu();
                                },
                                activeColor: Colors.white,
                                inactiveThumbColor: Colors.grey.shade300,
                                inactiveTrackColor: Colors.white54,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              isLampuOn ? 'Menyala' : 'Mati',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // --- AKHIR KARTU KONTROL LAMPU ---

                    // --- KONTROL PERANGKAT LAIN (Nonaktif) ---
                    const SizedBox(height: 10),
                    const Text(
                      'Fitur kontrol lain akan ditambahkan di sini.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
    );
  }
}
