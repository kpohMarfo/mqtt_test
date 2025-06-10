#include <WiFi.h>
#include <WiFiClientSecure.h> // Diperlukan untuk koneksi MQTT dengan SSL/TLS (port 8883)
#include <PubSubClient.h>     // Pustaka MQTT Client untuk ESP32

// Konfigurasi WiFi Anda
const char* ssid = "PT YOTTA BERKAH MULIA 4G";        // Ganti dengan SSID WiFi Anda
const char* password = "4P2EbZnL";    // Ganti dengan Password WiFi Anda

// Konfigurasi Broker MQTT (EMQX Cloud Anda)
const char* mqtt_server = "f1e0e15e.ala.asia-southeast1.emqxsl.com"; // Host EMQX Cloud Anda
const int mqtt_port = 8883;                                                  // Port MQTT SSL/TLS EMQX Cloud Anda
const char* mqtt_username = "kamar1";                                          // Username MQTT Anda (untuk ESP32)
const char* mqtt_password = "kamar1";                                       // Password MQTT Anda (untuk ESP32)

// ID Kamar untuk perangkat ini 
#define MY_KAMAR_ID "kamar1" 

// Pin sensor MQ2
const int mq2Pin = 34; // Sesuaikan dengan pin MQ2 Anda

// PIN PIR (Deteksi Gerakan)
const int pirPin = 26; // PIN PIR Disesuaikan ke 26

// PIN RELAY LAMPU
#define RELAY_LAMP 19 // <<< PIN RELAY LAMPU Disesuaikan ke 19

// Client WiFi dan MQTT
WiFiClientSecure espClient; 
PubSubClient client(espClient); 

// Waktu terakhir publikasi data MQ2
unsigned long lastMQ2PublishTime = 0;
const unsigned long MQ2_PUBLISH_INTERVAL = 3000; // Publikasi setiap 3 detik

// Waktu terakhir untuk upaya koneksi ulang MQTT
unsigned long lastReconnectAttempt = 0;

// Status untuk notifikasi
bool pirAlertSent = false;
bool gasAlertSent = false; 

// Status kontrol lampu
bool lampState = false; // <<< Status lampu

// CA Certificate yang Anda berikan (SEKARANG DIGUNAKAN)
const char* ca_cert = R"EOF(
-----BEGIN CERTIFICATE-----
MIIDrzCCApegAwIBAgIQCDvgVpBCRrGhdWrJWZHHSjANBgkqhkiG9w0BAQUFADBh
MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
d3cuZGlnaWNlcnQuY29tMSAwHgYDVQQDExdEaWdpQ2VydCBHbG9iYWwgUm9vdCBD
QTAeFw0wNjExMTAwMDAwMDBaFw0zMTExMTAwMDAwMDBaMGExCzAJBgNVBAYTAlVT
MRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNVBAsTEHd3dy5kaWdpY2VydC5j
b20xIDAeBgNVBAMTF0RpZ2lDZXJ0IEdsb2JhbCBSb290IENBMIIBIjANBgkqhkiG
9w0BAQEFAAOCAQ8AMIIBCgKCAQEA4jvhEXLeqKTTo1eqUKKPC3eQyaKl7hLOllsB
CSDMAZOnTjC3U/dDxGkAV53ijSLdhwZAAIEJzs4bg7/fzTtxRuLWZscFs3YnFo97
nh6Vfe63SKMI2tavegw5BmV/Sl0fvBf4q77uKNd0f3p4mVmFaG5cIzJLv07A6Fpt
43C/dxC//AH2hdmoRBBYMql1GNXRor5H4idq9Joz+EkIYIvUX7Q6hL+hqkpMfT7P
T19sdl6gSzeRntwi5m3OFBqOasv+zbMUZBfHWymeMr/y7vrTC0LUq7dBMtoM1O/4
gdW7jVg/tRvoSSiicNoxBN33shbyTApOB6jtSj1etX+jkMOvJwIDAQABo2MwYTAO
BgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQUA95QNVbR
TLtm8KPiGxvDl7I90VUwHwYDVR0jBBgwFoAUA95QNVbRTLtm8KPiGxvDl7I90VUw
DQYJKoZIhvcNAQEFBQADggEBAMucN6pIExIK+t1EnE9SsPTfrgT1eXkIoyQY/Esr
hMAtudXH/vTBH1jLuG2cenTnmCmrEbXjcKChzUyImZOMkXDiqw8cvpOp/2PV5Adg
06O/nVsJ8dWO41P0jmP6P6fbtGbfYmbW0W5BjfIttep3Sp+dWOIrWcBAI+0tKIJF
PnlUkiaY4IBIqDfv8NZ5YBberOgOzW6sRBc4L0na4UU+Krk2U886UAb3LujEV0ls
YSEY1QSteDwsOoBrp+uvFRTp2InBuThs4pFsiv9kuXclVzDAGySj4dzp30d8tbQk
CAUw7C29C79Fv1C5qfPrmAESrciIxpg0X40KPMbp1ZWVbd4=
-----END CERTIFICATE-----
)EOF";


// --- Fungsi Callback MQTT ---
void callback(char* topic, byte* payload, unsigned int length) {
  Serial.print("Pesan MQTT Diterima [");
  Serial.print(topic);
  Serial.print("]: ");
  String message = "";
  for (unsigned int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);

  // --- Handle Perintah Kontrol Lampu ---
  if (String(topic) == String(MY_KAMAR_ID) + "/lampu") {
    if (message == "on") {
      digitalWrite(RELAY_LAMP, HIGH); // Nyalakan lampu
      lampState = true;
      Serial.println("Perintah: Lampu ON");
      client.publish((String(MY_KAMAR_ID) + "/status/lampu").c_str(), "on"); // Publikasi status kembali
    } else if (message == "off") {
      digitalWrite(RELAY_LAMP, LOW); // Matikan lampu
      lampState = false;
      Serial.println("Perintah: Lampu OFF");
      client.publish((String(MY_KAMAR_ID) + "/status/lampu").c_str(), "off"); // Publikasi status kembali
    }
  }
}

// --- Fungsi Koneksi dan Reconnect MQTT ---
boolean reconnect() {
  Serial.print("Mencoba koneksi MQTT...");
  String clientId = "ESP32_MQ2_PIR_LAMP_TEST_" + String(random(0xffff), HEX); // Client ID unik

  if (client.connect(clientId.c_str(), mqtt_username, mqtt_password)) { 
    Serial.println("Terhubung ke MQTT Broker!");
    // --- Subscribe ke Topik Kontrol Lampu ---
    client.subscribe((String(MY_KAMAR_ID) + "/lampu").c_str()); 
    Serial.println("Berhasil subscribe ke topik kontrol.");
  } else {
    Serial.print("Gagal, rc=");
    Serial.print(client.state()); 
    Serial.println(". Coba lagi dalam 5 detik.");
    return false; 
  }
  return true; 
}

void setup() {
  Serial.begin(115200); 
  
  pinMode(mq2Pin, INPUT);
  pinMode(pirPin, INPUT); 
  pinMode(RELAY_LAMP, OUTPUT); 

  digitalWrite(RELAY_LAMP, LOW);

  // --- Koneksi WiFi ---
  Serial.print("Menghubungkan ke WiFi");
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nWiFi tersambung! IP: ");
  Serial.println(WiFi.localIP());

  // Konfigurasi SSL/TLS untuk WiFiClientSecure dengan CA Certificate
  espClient.setCACert(ca_cert); // <<< SEKARANG DIAKTIFKAN

  // Set broker dan callback untuk MQTT
  client.setServer(mqtt_server, mqtt_port);
  client.setCallback(callback);
}

void loop() {
  // --- Penanganan Koneksi MQTT ---
  if (!client.connected()) {
    unsigned long now = millis();
    if (now - lastReconnectAttempt > 5000) { 
      lastReconnectAttempt = now;
      if (reconnect()) {
        lastReconnectAttempt = 0;
      }
    }
  }
  client.loop(); 

  // --- Baca Sensor MQ2 dan Publikasi ---
  unsigned long now = millis();
  if (client.connected() && now - lastMQ2PublishTime > MQ2_PUBLISH_INTERVAL) {
    lastMQ2PublishTime = now;

    int gasValue = analogRead(mq2Pin);
    Serial.print("Nilai Gas MQ2: ");
    Serial.println(gasValue);

    String payload = String(gasValue);
    client.publish("esp32/mq2", payload.c_str()); 

    // Logika untuk mengirim notifikasi asap dari ESP32
    if (gasValue > 400 && !gasAlertSent) { 
      client.publish((String("kamar/") + MY_KAMAR_ID + "/notif").c_str(), "asap_terdeteksi"); 
      Serial.println("ESP32: Asap Terdeteksi!");
      gasAlertSent = true;
    } else if (gasValue <= 400 && gasAlertSent) { 
      client.publish((String("kamar/") + MY_KAMAR_ID + "/notif").c_str(), "asap_aman"); 
      Serial.println("ESP32: Asap Aman!");
      gasAlertSent = false;
    }
  }

  // --- Baca Sensor PIR dan Publikasi ---
  int pirState = digitalRead(pirPin); 
  if (client.connected()) { 
    if (pirState == HIGH) { 
      if (!pirAlertSent) { 
        Serial.println("ESP32: Gerakan terdeteksi!");
        client.publish((String("kamar/") + MY_KAMAR_ID + "/notif").c_str(), "gerakan_terdeteksi"); 
        pirAlertSent = true;
      }
    } else { 
      if (pirAlertSent) { 
        client.publish((String("kamar/") + MY_KAMAR_ID + "/notif").c_str(), "gerakan_aman"); 
        Serial.println("ESP32: Gerakan Aman!");
        pirAlertSent = false;
      }
    }
  }

  delay(10); 
}
