// lib/service/mqtt_service.dart

import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  // Konfigurasi broker MQTT (SESUAI DENGAN KODE ESP32 ANDA UNTUK MQ2 TEST)
  final String broker =
      'f1e0e15e.ala.asia-southeast1.emqxsl.com'; // Host EMQX Cloud Anda
  final int port = 8883; // Port SSL/TLS Anda
  final String username = 'rafo'; // <<< Username yang diperbarui
  final String password = 'rafo12345678'; // <<< Password yang diperbarui

  final String clientIdentifier = 'flutter_kost_app_${Uuid().v4()}';

  MqttServerClient? _client;

  final _statusController = StreamController<String>.broadcast();
  final _messageController = StreamController<Map<String, String>>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<Map<String, String>> get messageStream => _messageController.stream;

  Future<void> connect(String kamarId) async {
    // kamarId masih diteruskan untuk konsistensi
    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      print('✅ MQTT client sudah terhubung. (Dari connect())');
      _statusController.add('✅ Terhubung ke broker');
      return;
    }

    _client = MqttServerClient(broker, clientIdentifier);
    _client!.port = port;
    _client!.secure = true; // Tetap true karena EMQX Cloud pakai SSL/TLS
    _client!.logging(on: true);
    _client!.keepAlivePeriod = 20;
    _client!.onDisconnected = onDisconnected;
    _client!.onConnected = onConnected;
    _client!.onSubscribed = onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .keepAliveFor(20)
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atLeastOnce);

    _client!.connectionMessage = connMess;

    print(
        'DEBUG MQTT: Memulai koneksi ke $broker:$port dengan Client ID: $clientIdentifier (EMQX Cloud SSL)');
    try {
      await _client!.connect();
      print('DEBUG MQTT: client.connect() selesai.');
    } catch (e) {
      print('❌ Gagal koneksi (catch block): $e');
      _client?.disconnect();
      _statusController.add('❌ Koneksi gagal');
      _client = null;
      return;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ Koneksi MQTT berhasil (status connected).');
      _statusController.add('✅ Terhubung ke broker');
    } else {
      print(
          '❌ Gagal koneksi (status tidak connected), status: ${_client!.connectionStatus}');
      _statusController.add('❌ Status tidak terhubung');
      _client?.disconnect();
      _client = null;
      return;
    }

    // Subscribe hanya ke topik MQ2 untuk pengujian ini
    subscribe("esp32/mq2"); // <<< Subscribe ke topik MQ2
    // subscribe('kamar/+/notif'); // Komentari untuk fokus pada MQ2
    // subscribe(kamarId + "/telemetry/temperature"); // Komentari untuk fokus pada MQ2
    // subscribe(kamarId + "/telemetry/humidity");    // Komentari untuk fokus pada MQ2

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return;
      final recMess = c[0].payload as MqttPublishMessage;
      final message =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      print('📥 Pesan dari $topic: $message');

      _messageController.add({'topic': topic, 'message': message});

      // Untuk pengujian ini, logika notifikasi/suhu/kelembaban lain akan dihandle di DashboardPage
    });
  }

  void subscribe(String topic) {
    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      print('📡 Subscribe ke topik: $topic');
    } else {
      print('⚠️ Tidak dapat subscribe, MQTT client tidak terhubung.');
    }
  }

  void publish(String topic, String message) {
    if (_client != null &&
        _client!.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
      print('📤 Publish ke $topic: $message');
    } else {
      print('⚠️ Tidak dapat publish, MQTT client tidak terhubung.');
    }
  }

  void onDisconnected() {
    print('🔌 Terputus dari broker (callback)');
    _statusController.add('🔌 Terputus');
    _client = null;
  }

  void onConnected() {
    print('🔗 Terhubung ke broker (callback)');
    _statusController.add('🔗 Terhubung');
  }

  void onSubscribed(String topic) {
    print('📶 Berhasil subscribe ke $topic (callback)');
  }

  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
      _statusController.add('🔌 Manual disconnect');
      _client = null;
    }
  }
}
