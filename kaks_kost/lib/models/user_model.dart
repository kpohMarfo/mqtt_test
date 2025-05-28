class UserModel {
  final String uid;
  final String email;
  final String? kamarId;

  UserModel({
    required this.uid,
    required this.email,
    this.kamarId,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) {
    return UserModel(
      uid: uid,
      email: map['email'] ?? '',
      kamarId: map['kamar_id'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'kamar_id': kamarId,
    };
  }
}
