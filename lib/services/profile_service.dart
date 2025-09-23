// services/profile_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';
import 'dart:async'; // Added for StreamController

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

  // Stream controllers for real-time updates (moved from ProfileCacheService)
  final Map<String, StreamController<UserModel>> _profileStreamControllers = {};

  // Method to pick and process image
  Future<String?> pickAndProcessImage() async {
    try {
      // Pick image from gallery
      final XFile? imageFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 400,
        maxHeight: 400,
        imageQuality: 70,
      );

      if (imageFile == null) return null;

      // Read the image file
      final File file = File(imageFile.path);
      final bytes = await file.readAsBytes();

      // Decode and process the image
      img.Image? image = img.decodeImage(bytes);
      if (image == null) return null;

      // Resize if too large
      if (image.width > 400 || image.height > 400) {
        image = img.copyResize(
          image,
          width: 400,
          height: (400 * image.height / image.width).round(),
        );
      }

      // Encode to JPG with compression
      final compressedBytes = img.encodeJpg(image, quality: 70);

      // Convert to base64
      final base64Image = base64Encode(compressedBytes);
      return base64Image;
    } catch (e) {
      debugPrint('Error processing image: $e');
      return null;
    }
  }

  // Method to update profile
  Future<void> updateProfile({
    String? base64Image,
    String? displayName,
    String? bio,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    final updates = <String, dynamic>{};

    // Update display name if provided
    if (displayName != null && displayName.isNotEmpty) {
      await user.updateDisplayName(displayName);
      updates['username'] = displayName;
    }

    // Update bio if provided
    if (bio != null) {
      updates['bio'] = bio;
    }

    // Update profile image if provided
    if (base64Image != null) {
      final imageUri = 'data:image/jpeg;base64,$base64Image';
      await user.updatePhotoURL(imageUri);
      updates['profileImageUrl'] = imageUri;
    }

    // Update Firestore if we have any changes
    if (updates.isNotEmpty) {
      // Update user document
      await _firestore.collection('users').doc(user.uid).update(updates);

      // Update all posts by this user with the new profile information
      final postsSnapshot =
          await _firestore
              .collection('posts')
              .where('userId', isEqualTo: user.uid)
              .get();

      final batch = _firestore.batch();
      for (var doc in postsSnapshot.docs) {
        batch.update(doc.reference, {
          'userName': updates['username'] ?? doc.data()['userName'],
          'userAvatar': updates['profileImageUrl'] ?? doc.data()['userAvatar'],
        });
      }
      await batch.commit();

      // Force refresh the Firebase Auth user data
      await user.reload();
    }
  }

  // Get user profile stream (logic moved from ProfileCacheService)
  Stream<UserModel> getUserProfileStream(String userId) {
    // Create or get existing stream controller
    if (!_profileStreamControllers.containsKey(userId) ||
        _profileStreamControllers[userId]!.isClosed) {
      _profileStreamControllers[userId] =
          StreamController<UserModel>.broadcast();
      _setupProfileListener(userId); // Use the listener within this service
    }
    return _profileStreamControllers[userId]!.stream;
  }

  // Set up Firestore listener for profile updates (moved from ProfileCacheService)
  void _setupProfileListener(String userId) {
    _firestore.collection('users').doc(userId).snapshots().listen((doc) async {
      if (!doc.exists) {
        // Optionally add error handling or specific logic if user doc disappears
        print('User document $userId does not exist.');
        _profileStreamControllers[userId]?.addError(
          'User not found',
        ); // Add error to stream
        return;
      }

      try {
        // Get friend stats (same as before)
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

        // Add to stream if controller exists and is not closed
        if (_profileStreamControllers.containsKey(userId) &&
            !_profileStreamControllers[userId]!.isClosed) {
          _profileStreamControllers[userId]!.add(profile);
        }
      } catch (e) {
        print('Error processing user update for $userId: $e');
        // Add error to the stream if the controller is still valid
        if (_profileStreamControllers.containsKey(userId) &&
            !_profileStreamControllers[userId]!.isClosed) {
          _profileStreamControllers[userId]!.addError(
            'Failed to process profile update: $e',
          );
        }
      }
    });
  }

  // Update user stats after friend actions
  Future<void> updateUserFriendStats(String userId) async {
    // Get unique watched movies count
    final Set<String> uniqueMovieIds = {};

    // Add movies from diary entries
    final diaryEntries =
        await _firestore
            .collection('diary_entries')
            .where('userId', isEqualTo: userId)
            .get();
    for (var doc in diaryEntries.docs) {
      uniqueMovieIds.add(doc.data()['movieId']);
    }

    // Add movies from direct ratings
    final directRatings =
        await _firestore
            .collection('movie_ratings')
            .where('userId', isEqualTo: userId)
            .get();
    for (var doc in directRatings.docs) {
      uniqueMovieIds.add(doc.data()['movieId']);
    }

    // Update the watched count
    await _firestore.collection('users').doc(userId).update({
      'watchedCount': uniqueMovieIds.length,
    });
  }

  // Get user profile data (for single fetch)
  Future<UserModel> getUserProfile(String userId) async {
    // Changed return type
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

      return UserModel.fromJson(userData, doc.id);
    } catch (e) {
      print('Error getting user profile for $userId: $e');
      rethrow; // Rethrow to allow callers to handle
    }
  }

  // Dispose method to clean up stream controllers
  void dispose() {
    for (final controller in _profileStreamControllers.values) {
      controller.close();
    }
    _profileStreamControllers.clear();
    print('ProfileService disposed and controllers closed.');
  }
}
