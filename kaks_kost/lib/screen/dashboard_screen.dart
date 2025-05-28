import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:kaks_kost/service/firestore_service.dart';
import 'package:kaks_kost/service/mqtt_service.dart';

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
  bool isLampuOn = false;
  bool isPintuTerkunci = true;

  @override
  void initState() {
    super.initState();
    setupMQTT();
  }

  Future<void> setupMQTT() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    kamarId = await FirestoreService().getKamarUser(user.uid);

    if (kamarId != null) {
      mqttService.connect();
      mqttService.statusStream.listen((status) {
        setState(() => mqttStatus = status);
      });

      mqttService.messageStream.listen((message) {
        setState(() {
          if (message == 'asap_terdeteksi') {
            lastNotif = '🚨 Asap terdeteksi!';
          } else if (message == 'gerakan_terdeteksi') {
            lastNotif = '🔔 Gerakan terdeteksi!';
          } else {
            lastNotif = message;
          }
        });
      });
    } else {
      setState(() {
        mqttStatus = '❌ Belum bind ke kamar.';
      });
    }
  }

  void kontrolLampu() {
    if (kamarId == null) return;
    final topic = '$kamarId/lampu';
    final command = isLampuOn ? 'off' : 'on';
    mqttService.publish(topic, command);
    setState(() => isLampuOn = !isLampuOn);
  }

  void kontrolPintu() {
    if (kamarId == null) return;
    final topic = '$kamarId/pintu';
    final command = isPintuTerkunci ? 'unlock' : 'lock';
    mqttService.publish(topic, command);
    setState(() => isPintuTerkunci = !isPintuTerkunci);
  }

  void logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
      print('📍 LoginScreen dibangun');
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
                  Text('Notifikasi: $lastNotif', style: const TextStyle(fontSize: 16)),
                  const Divider(),
                  const Text('Kontrol Perangkat:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: kontrolPintu,
                          child: Text(isPintuTerkunci ? 'Buka Pintu' : 'Kunci Pintu'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: kontrolLampu,
                          child: Text(isLampuOn ? 'Matikan Lampu' : 'Nyalakan Lampu'),
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
