// services/profile_service.dart
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart';

class ProfileService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _picker = ImagePicker();

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
      await _firestore.collection('users').doc(user.uid).update(updates);
    }
  }

  // Get user profile with friend stats
  Stream<UserModel> getUserProfileStream(String userId) {
    return _firestore.collection('users').doc(userId).snapshots().asyncMap((
      doc,
    ) async {
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

      // Create updated user data with friend stats
      final userData = doc.data()!;
      userData['followersCount'] = followersCount.count;
      userData['followingCount'] = followingCount.count;
      userData['mutualFriendsCount'] = mutualCount.count;

      return UserModel.fromJson(userData, doc.id);
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

  // Get user profile data
  Future<Map<String, dynamic>> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data() ?? {};
  }
}
