// lib/service/mqtt_service.dart

// import 'dart:io';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  // Singleton pattern
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  // Konfigurasi broker MQTT
  final String broker = 'c7fcebd6fd734d00acf71e1b3f69157a.s1.eu.hivemq.cloud';
  final int port = 8883;
  final String username = 'rafo26';
  final String password = 'R@fo12345';
  final String clientIdentifier = 'flutter_kost_app';
  
  // Mengubah 'late' menjadi nullable dan diinisialisasi dengan null.
  // Ini lebih aman karena tidak ada jaminan 'client' akan diinisialisasi
  // sebelum diakses di beberapa skenario, terutama dengan singleton.
  MqttServerClient? _client; 

  // StreamControllers untuk status koneksi dan pesan masuk
  final _statusController = StreamController<String>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  // Getters untuk stream
  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get messageStream => _messageController.stream;

  /// Metode untuk menghubungkan ke broker MQTT
  Future<void> connect() async {
    // Jika client sudah ada dan terhubung, tidak perlu koneksi ulang
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      print('✅ MQTT client sudah terhubung.');
      _statusController.add('✅ Terhubung ke broker');
      return;
    }

    // Inisialisasi client MQTT
    _client = MqttServerClient(broker, clientIdentifier);
    _client!.port = port;
    _client!.secure = true; // Menggunakan koneksi aman (SSL/TLS)
    _client!.logging(on: true); // Aktifkan logging
    _client!.keepAlivePeriod = 20; // Periode keep-alive dalam detik
    
    // Menetapkan callback untuk event koneksi
    _client!.onDisconnected = onDisconnected;
    _client!.onConnected = onConnected;
    _client!.onSubscribed = onSubscribed;

    // Membuat pesan koneksi
    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean() // Mulai sesi baru setiap kali
        .keepAliveFor(20)
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMess;

    try {
      // Mencoba terhubung ke broker
      await _client!.connect();
    } catch (e) {
      print('❌ Gagal koneksi: $e');
      _client?.disconnect(); // Gunakan null-aware operator
      _statusController.add('❌ Koneksi gagal');
      _client = null; // Set client menjadi null jika gagal
      return;
    }

    // Memeriksa status koneksi setelah mencoba terhubung
    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ Koneksi MQTT berhasil');
      _statusController.add('✅ Terhubung ke broker');
    } else {
      print('❌ Gagal koneksi, status: ${_client!.connectionStatus}');
      _statusController.add('❌ Status tidak terhubung');
      _client?.disconnect(); // Gunakan null-aware operator
      _client = null; // Set client menjadi null jika gagal
      return;
    }

    // Subscribe ke topik notifikasi umum
    subscribe('kamar/+/notif');

    // Listener untuk pesan masuk
    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return; // Tambahkan null check untuk 'c'
      final recMess = c[0].payload as MqttPublishMessage;
      final message =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      print('📥 Pesan dari $topic: $message');

      _messageController.add(message); // Kirim pesan ke stream untuk UI

      // Logika khusus untuk notifikasi
      if (topic.contains('notif')) {
        if (message == 'asap_terdeteksi') {
          print('🚨 Asap terdeteksi!');
        } else if (message == 'gerakan_terdeteksi') {
          print('🔔 Gerakan terdeteksi!');
        }
      }
    });
  }

  /// Metode untuk subscribe ke topik MQTT
  void subscribe(String topic) {
    // Pastikan client tidak null dan terhubung sebelum subscribe
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      print('📡 Subscribe ke topik: $topic');
    } else {
      print('⚠️ Tidak dapat subscribe, MQTT client tidak terhubung.');
    }
  }

  /// Metode untuk publish pesan ke topik MQTT
  void publish(String topic, String message) {
    // Pastikan client tidak null dan terhubung sebelum publish
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      // builder.payload! aman di sini karena builder.addString pasti mengembalikan payload
      _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!); 
      print('📤 Publish ke $topic: $message');
    } else {
      print('⚠️ Tidak dapat publish, MQTT client tidak terhubung.');
    }
  }

  /// Callback saat koneksi terputus
  void onDisconnected() {
    print('🔌 Terputus dari broker');
    _statusController.add('🔌 Terputus');
    _client = null; // Set client menjadi null saat terputus
  }

  /// Callback saat koneksi berhasil
  void onConnected() {
    print('🔗 Terhubung ke broker');
    _statusController.add('🔗 Terhubung');
  }

  /// Callback saat berhasil subscribe
  void onSubscribed(String topic) {
    print('📶 Berhasil subscribe ke $topic');
  }

  /// Metode untuk memutuskan koneksi secara manual
  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
      _statusController.add('🔌 Manual disconnect');
      _client = null; // Set client menjadi null saat disconnect manual
    }
  }
}
