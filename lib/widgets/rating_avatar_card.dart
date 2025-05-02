import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../screens/user_profile_screen.dart';

class RatingAvatarCard extends StatelessWidget {
  final Map<String, dynamic> rating;

  const RatingAvatarCard({Key? key, required this.rating}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final user = rating['user'] as Map<String, dynamic>;
    final photoURL = user['profileImageUrl'] as String?;
    final displayName = user['displayName'] as String? ?? 'Anonymous';
    final ratingValue = (rating['rating'] as num).toDouble();
    final source = rating['source'] as String? ?? 'rating';
    final username = user['username'] as String? ?? '';
    final userId = rating['userId'] as String? ?? '';
    final isLiked = ratingValue >= 3.5;
    final isFavorite = rating['isFavorite'] as bool? ?? false;

    // Debug logging
    debugPrint('User data: $user');
    debugPrint('Photo URL: $photoURL');
    debugPrint('Display name: $displayName');
    debugPrint('Source: $source');
    debugPrint('User ID: $userId');
    debugPrint('Rating value: $ratingValue');
    debugPrint('Is favorite: $isFavorite');

    return GestureDetector(
      onTap: () {
        if (userId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) =>
                      UserProfileScreen(userId: userId, username: username),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundImage:
                  photoURL != null && photoURL.isNotEmpty
                      ? NetworkImage(photoURL)
                      : null,
              child:
                  photoURL == null || photoURL.isEmpty
                      ? Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(5, (i) {
                final filled = i < ratingValue.floor();
                final halfStar =
                    i == ratingValue.floor() && ratingValue % 1 >= 0.5;

                return Icon(
                  halfStar
                      ? Icons.star_half
                      : filled
                      ? Icons.star
                      : Icons.star_border,
                  size: 14,
                  color: Colors.amber,
                );
              }),
            ),
            if (isLiked || isFavorite) ...[
              const SizedBox(height: 2),
              Icon(Icons.favorite, size: 12, color: Colors.red),
            ],
          ],
        ),
      ),
    );
  }
}
