// lib/service/mqtt_service.dart

import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:uuid/uuid.dart'; // Import uuid package

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  final String broker = 'c7fcebd6fd734d00acf71e1b3f69157a.s1.eu.hivemq.cloud';
  final int port = 8883;
  final String username = 'rafo26';
  final String password = 'R@fo12345';
  // final String clientIdentifier = 'flutter_kost_app'; // Original
  final String clientIdentifier = 'flutter_kost_app_${Uuid().v4()}'; // <<< Perubahan di sini: Client ID unik
  
  MqttServerClient? _client; 

  final _statusController = StreamController<String>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get messageStream => _messageController.stream;

  Future<void> connect() async {
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      print('✅ MQTT client sudah terhubung. (Dari connect())');
      _statusController.add('✅ Terhubung ke broker');
      return;
    }

    _client = MqttServerClient(broker, clientIdentifier);
    _client!.port = port;
    _client!.secure = true;
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

    print('DEBUG MQTT: Memulai koneksi ke $broker:$port dengan Client ID: $clientIdentifier'); // DEBUG
    try {
      await _client!.connect();
      print('DEBUG MQTT: client.connect() selesai.'); // DEBUG
    } catch (e) {
      print('❌ Gagal koneksi (catch block): $e'); // DEBUG
      _client?.disconnect();
      _statusController.add('❌ Koneksi gagal');
      _client = null;
      return;
    }

    if (_client!.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ Koneksi MQTT berhasil (status connected).'); // DEBUG
      _statusController.add('✅ Terhubung ke broker');
    } else {
      print('❌ Gagal koneksi (status tidak connected), status: ${_client!.connectionStatus}'); // DEBUG
      _statusController.add('❌ Status tidak terhubung');
      _client?.disconnect();
      _client = null;
      return;
    }

    subscribe('kamar/+/notif');

    _client!.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      if (c == null || c.isEmpty) return;
      final recMess = c[0].payload as MqttPublishMessage;
      final message =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      print('📥 Pesan dari $topic: $message');

      _messageController.add(message);

      if (topic.contains('notif')) {
        if (message == 'asap_terdeteksi') {
          print('🚨 Asap terdeteksi!');
        } else if (message == 'gerakan_terdeteksi') {
          print('🔔 Gerakan terdeteksi!');
        }
      }
    });
  }

  void subscribe(String topic) {
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      _client!.subscribe(topic, MqttQos.atMostOnce);
      print('📡 Subscribe ke topik: $topic');
    } else {
      print('⚠️ Tidak dapat subscribe, MQTT client tidak terhubung.');
    }
  }

  void publish(String topic, String message) {
    if (_client != null && _client!.connectionStatus?.state == MqttConnectionState.connected) {
      final builder = MqttClientPayloadBuilder();
      builder.addString(message);
      _client!.publishMessage(topic, MqttQos.atMostOnce, builder.payload!); 
      print('📤 Publish ke $topic: $message');
    } else {
      print('⚠️ Tidak dapat publish, MQTT client tidak terhubung.');
    }
  }

  void onDisconnected() {
    print('🔌 Terputus dari broker (callback)'); // DEBUG
    _statusController.add('🔌 Terputus');
    _client = null;
  }

  void onConnected() {
    print('🔗 Terhubung ke broker (callback)'); // DEBUG
    _statusController.add('🔗 Terhubung');
  }

  void onSubscribed(String topic) {
    print('📶 Berhasil subscribe ke $topic (callback)'); // DEBUG
  }

  void disconnect() {
    if (_client != null) {
      _client!.disconnect();
      _statusController.add('🔌 Manual disconnect');
      _client = null;
    }
  }
}
