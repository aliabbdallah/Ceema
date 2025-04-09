import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/follow_service.dart';
import '../widgets/user_list_item.dart';
import '../models/follow.dart';

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
              return UserListItem(
                userId: followed.followedId,
                userName: followed.followedName,
                userPhotoUrl: followed.followedAvatar,
                isPrivate: false,
              );
            },
          );
        },
      ),
    );
  }
}
