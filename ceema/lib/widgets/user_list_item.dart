import 'package:flutter/material.dart';
import '../widgets/follow_button.dart';

class UserListItem extends StatelessWidget {
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final bool isPrivate;
  final bool showFollowButton;

  const UserListItem({
    Key? key,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.isPrivate = false,
    this.showFollowButton = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage:
            userPhotoUrl != null ? NetworkImage(userPhotoUrl!) : null,
        child: userPhotoUrl == null ? Text(userName[0].toUpperCase()) : null,
      ),
      title: Text(
        userName,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      trailing:
          showFollowButton
              ? FollowButton(targetUserId: userId, isPrivate: isPrivate)
              : null,
      onTap: () {
        // TODO: Navigate to user profile
        // Navigator.push(
        //   context,
        //   MaterialPageRoute(
        //     builder: (context) => ProfileScreen(userId: userId),
        //   ),
        // );
      },
    );
  }
}
