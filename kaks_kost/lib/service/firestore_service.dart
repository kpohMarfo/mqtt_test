// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Cek apakah kamar sudah memiliki user aktif
  Future<bool> isKamarTerpakai(String kamarId) async {
    final doc = await _db.collection('kamar').doc(kamarId).get();
    return doc.exists && doc.data()?['active_user'] != null;
  }

  /// Putuskan binding user lama jika ada
  Future<void> putuskanUserLama(String kamarId, String userBaruId) async {
    final kamarDoc = await _db.collection('kamar').doc(kamarId).get();
    final data = kamarDoc.data();
    final oldUserId = data?['active_user'];

    if (oldUserId != null && oldUserId != userBaruId) {
      await _db.collection('users').doc(oldUserId).update({
        'kamar_id': FieldValue.delete(),
      });
    }
  }

  /// Bind user ke kamar dan update Firestore
  Future<void> bindUserKeKamar(String kamarId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await putuskanUserLama(kamarId, user.uid);

    await _db.collection('kamar').doc(kamarId).set({
      'active_user': user.uid,
    });

    await _db.collection('users').doc(user.uid).set({
      'email': user.email,
      'kamar_id': kamarId,
    }, SetOptions(merge: true));
  }

  /// Ambil ID kamar user jika ada
  Future<String?> getKamarUser(String userId) async {
    final userDoc = await _db.collection('users').doc(userId).get();
    return userDoc.data()?['kamar_id'];
  }
}
