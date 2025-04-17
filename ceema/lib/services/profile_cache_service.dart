import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import 'dart:async';

class ProfileCacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Cache for user profiles with expiration
  final Map<String, _CachedProfile> _profileCache = {};
  static const Duration _cacheExpiration = Duration(minutes: 30);
  static const int _maxCacheSize = 1000; // Maximum number of cached profiles

  // Stream controllers for real-time updates
  final Map<String, StreamController<UserModel>> _profileStreamControllers = {};

  // Singleton instance
  static final ProfileCacheService _instance = ProfileCacheService._internal();
  factory ProfileCacheService() => _instance;
  ProfileCacheService._internal();

  // Get user profile with caching
  Future<UserModel> getUserProfile(String userId) async {
    // Check cache first
    if (_profileCache.containsKey(userId)) {
      final cached = _profileCache[userId]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheExpiration) {
        return cached.profile;
      }
    }

    // Clean cache if it's too large
    if (_profileCache.length >= _maxCacheSize) {
      _cleanCache();
    }

    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        throw Exception('User not found');
      }

      // Get friend stats
      final followersCount =
          await _firestore
              .collection('follows')
              .where('followedId', isEqualTo: userId)
              .count()
              .get();

      final followingCount =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId)
              .count()
              .get();

      final mutualCount =
          await _firestore
              .collection('follows')
              .where('followerId', isEqualTo: userId)
              .where('isMutual', isEqualTo: true)
              .count()
              .get();

      // Create user model with friend stats
      final userData = doc.data()!;
      userData['followersCount'] = followersCount.count;
      userData['followingCount'] = followingCount.count;
      userData['mutualFriendsCount'] = mutualCount.count;

      final profile = UserModel.fromJson(userData, doc.id);

      // Update cache
      _profileCache[userId] = _CachedProfile(profile, DateTime.now());

      return profile;
    } catch (e) {
      print('Error getting user profile: $e');
      rethrow;
    }
  }

  // Get user profile stream with caching
  Stream<UserModel> getUserProfileStream(String userId) {
    // Create or get existing stream controller
    if (!_profileStreamControllers.containsKey(userId)) {
      // Use a broadcast controller to allow multiple listeners
      _profileStreamControllers[userId] =
          StreamController<UserModel>.broadcast();
      _setupProfileListener(userId);
    }

    return _profileStreamControllers[userId]!.stream;
  }

  // Set up Firestore listener for profile updates
  void _setupProfileListener(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((doc) async {
      if (!doc.exists) return;

      try {
        // Get friend stats
        final followersCount =
            await _firestore
                .collection('follows')
                .where('followedId', isEqualTo: userId)
                .count()
                .get();

        final followingCount =
            await _firestore
                .collection('follows')
                .where('followerId', isEqualTo: userId)
                .count()
                .get();

        final mutualCount =
            await _firestore
                .collection('follows')
                .where('followerId', isEqualTo: userId)
                .where('isMutual', isEqualTo: true)
                .count()
                .get();

        // Create user model with friend stats
        final userData = doc.data()!;
        userData['followersCount'] = followersCount.count;
        userData['followingCount'] = followingCount.count;
        userData['mutualFriendsCount'] = mutualCount.count;

        final profile = UserModel.fromJson(userData, doc.id);

        // Update cache
        _profileCache[userId] = _CachedProfile(profile, DateTime.now());

        // Add to stream
        _profileStreamControllers[userId]?.add(profile);
      } catch (e) {
        print('Error updating profile stream: $e');
      }
    });
  }

  // Clean cache by removing oldest entries
  void _cleanCache() {
    final sortedEntries =
        _profileCache.entries.toList()
          ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    // Remove oldest entries until we're under the limit
    while (_profileCache.length >= _maxCacheSize) {
      _profileCache.remove(sortedEntries.removeAt(0).key);
    }
  }

  // Clear cache for a specific user
  void clearUserCache(String userId) {
    _profileCache.remove(userId);
  }

  // Clear entire cache
  void clearAllCache() {
    _profileCache.clear();
  }

  // Dispose of stream controllers
  void dispose() {
    for (final controller in _profileStreamControllers.values) {
      controller.close();
    }
    _profileStreamControllers.clear();
  }
}

// Helper class for cached profiles
class _CachedProfile {
  final UserModel profile;
  final DateTime timestamp;

  _CachedProfile(this.profile, this.timestamp);
}
