import 'dart:io';
import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MQTTService {
  static final MQTTService _instance = MQTTService._internal();
  factory MQTTService() => _instance;
  MQTTService._internal();

  final String broker = 'c7fcebd6fd734d00acf71e1b3f69157a.s1.eu.hivemq.cloud';
  final int port = 8883;
  final String username = 'rafo26';
  final String password = 'R@fo12345';
  final String clientIdentifier = 'flutter_kost_app';
  late MqttServerClient client;

  final _statusController = StreamController<String>.broadcast();
  final _messageController = StreamController<String>.broadcast();

  Stream<String> get statusStream => _statusController.stream;
  Stream<String> get messageStream => _messageController.stream;

  Future<void> connect() async {
    client = MqttServerClient(broker, clientIdentifier);
    client.port = port;
    client.secure = true;
    client.logging(on: true);
    client.keepAlivePeriod = 20;
    client.onDisconnected = onDisconnected;
    client.onConnected = onConnected;
    client.onSubscribed = onSubscribed;

    final connMess = MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean()
        .keepAliveFor(20)
        .authenticateAs(username, password)
        .withWillQos(MqttQos.atLeastOnce);

    client.connectionMessage = connMess;

    try {
      await client.connect();
    } catch (e) {
      print('❌ Gagal koneksi: $e');
      client.disconnect();
      _statusController.add('❌ Koneksi gagal');
      return;
    }

    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      print('✅ Koneksi MQTT berhasil');
      _statusController.add('✅ Terhubung ke broker');
    } else {
      print('❌ Gagal koneksi, status: ${client.connectionStatus}');
      _statusController.add('❌ Status tidak terhubung');
      client.disconnect();
      return;
    }

    // Subscribe ke topik notifikasi
    subscribe('kamar/+/notif');

    // Listener pesan masuk
    client.updates!.listen((List<MqttReceivedMessage<MqttMessage?>>? c) {
      final recMess = c![0].payload as MqttPublishMessage;
      final message =
          MqttPublishPayload.bytesToStringAsString(recMess.payload.message);
      final topic = c[0].topic;

      print('📥 Pesan dari $topic: $message');

      _messageController.add(message); // Dikirim ke UI

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
    if (client.connectionStatus!.state == MqttConnectionState.connected) {
      client.subscribe(topic, MqttQos.atMostOnce);
      print('📡 Subscribe ke topik: $topic');
    }
  }

  void publish(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
    print('📤 Publish ke $topic: $message');
  }

  void onDisconnected() {
    print('🔌 Terputus dari broker');
    _statusController.add('🔌 Terputus');
  }

  void onConnected() {
    print('🔗 Terhubung ke broker');
    _statusController.add('🔗 Terhubung');
  }

  void onSubscribed(String topic) {
    print('📶 Berhasil subscribe ke $topic');
  }

  void disconnect() {
    client.disconnect();
    _statusController.add('🔌 Manual disconnect');
  }
}
