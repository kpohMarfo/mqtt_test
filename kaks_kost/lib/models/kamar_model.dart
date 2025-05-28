class KamarModel {
  final String deviceId;
  final String? currentUserId;

  KamarModel({
    required this.deviceId,
    this.currentUserId,
  });

  factory KamarModel.fromMap(Map<String, dynamic> map, String deviceId) {
    return KamarModel(
      deviceId: deviceId,
      currentUserId: map['current_user'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'current_user': currentUserId,
    };
  }
}
