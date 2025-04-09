import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/follow_service.dart';
import '../widgets/user_list_item.dart';
import '../models/follow.dart';

class FollowersScreen extends StatelessWidget {
  final String targetUserId;

  const FollowersScreen({Key? key, required this.targetUserId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Followers')),
      body: StreamBuilder<List<Follow>>(
        stream: FollowService().getFollowers(targetUserId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final followers = snapshot.data ?? [];

          if (followers.isEmpty) {
            return const Center(child: Text('No followers yet'));
          }

          return ListView.builder(
            itemCount: followers.length,
            itemBuilder: (context, index) {
              final follower = followers[index];
              return UserListItem(
                userId: follower.followerId,
                userName: follower.followerName,
                userPhotoUrl: follower.followerAvatar,
                isPrivate: false,
              );
            },
          );
        },
      ),
    );
  }
}
