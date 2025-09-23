import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PresenceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isOnline = false;

  // Initialize presence tracking
  Future<void> initialize() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Set initial online status
    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    _isOnline = true;

    // Set up offline handler
    _firestore.collection('users').doc(user.uid).snapshots().listen((snapshot) {
      if (!snapshot.exists) return;

      // Update last seen timestamp periodically while online
      if (_isOnline) {
        _firestore.collection('users').doc(user.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  // Set user as offline
  Future<void> setOffline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    _isOnline = false;
  }

  // Set user as online
  Future<void> setOnline() async {
    final user = _auth.currentUser;
    if (user == null) return;

    await _firestore.collection('users').doc(user.uid).update({
      'isOnline': true,
      'lastSeen': FieldValue.serverTimestamp(),
    });
    _isOnline = true;
  }
}
