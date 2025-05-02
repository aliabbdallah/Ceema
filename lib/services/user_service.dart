import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> updates,
  ) async {
    try {
      // Update user document
      await _firestore.collection('users').doc(userId).update(updates);
    } catch (e) {
      print('[UserService] Error updating user profile: $e');
      rethrow;
    }
  }
}
