import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/follow_service.dart';
import '../widgets/profile_image_widget.dart';
import '../models/follow.dart';
import '../screens/user_profile_screen.dart';

class FollowingScreen extends StatelessWidget {
  final String targetUserId;

  const FollowingScreen({Key? key, required this.targetUserId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: StreamBuilder<List<Follow>>(
        stream: FollowService().getFollowing(targetUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final following = snapshot.data ?? [];

          if (following.isEmpty) {
            return const Center(child: Text('Not following anyone yet'));
          }

          return ListView.builder(
            itemCount: following.length,
            itemBuilder: (context, index) {
              final followed = following[index];
              return ListTile(
                leading: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => UserProfileScreen(
                              userId: followed.followedId,
                              username: followed.followedName,
                            ),
                      ),
                    );
                  },
                  child: ProfileImageWidget(
                    imageUrl: followed.followedAvatar,
                    radius: 24,
                    fallbackName: followed.followedName,
                  ),
                ),
                title: Text(
                  followed.followedName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => UserProfileScreen(
                            userId: followed.followedId,
                            username: followed.followedName,
                          ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
