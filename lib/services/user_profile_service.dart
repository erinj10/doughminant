import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_profile.dart';

class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Save or merge the profile document for [uid]. Returns true on success,
  /// false on failure (network, permissions, etc.). Uses a short timeout so it
  /// won't block UI for long.
  Future<bool> saveProfile(UserProfile profile) async {
    try {
      final doc = _db.collection('users').doc(profile.uid);
      final data = profile.toMap();
      data['updatedAt'] = DateTime.now().toUtc().toIso8601String();
      await doc.set(data, SetOptions(merge: true)).timeout(const Duration(seconds: 8));
      return true;
    } catch (e) {
      // log error for easier debugging and return false so caller can choose to retry
      // Use debugPrint to ensure messages appear in Flutter logs.
      try {
        // ignore: avoid_print
        print('UserProfileService.saveProfile error: $e');
      } catch (_) {}
      return false;
    }
  }

  /// Load the profile for [uid] or null if not present / on error.
  Future<UserProfile?> getProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get().timeout(const Duration(seconds: 8));
      if (!doc.exists) return null;
      final data = doc.data()!..['uid'] = doc.id;
      return UserProfile.fromMap(Map<String, dynamic>.from(data));
    } catch (e) {
      return null;
    }
  }
}
