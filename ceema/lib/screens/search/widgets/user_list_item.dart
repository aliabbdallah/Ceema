import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/user.dart';
import '../../../models/follow_request.dart';
import '../../../services/follow_request_service.dart';
import '../../../services/follow_service.dart';
import '../../../widgets/profile_image_widget.dart';
import '../../../screens/user_profile_screen.dart';

class UserListItem extends StatelessWidget {
  final UserModel user;
  final bool isRecent;
  final bool isSuggested;
  final FollowService followService;
  final FollowRequestService requestService;
  final FirebaseAuth auth;
  final Function(UserModel) onRemoveFromHistory;
  final Function() onRefresh;

  const UserListItem({
    Key? key,
    required this.user,
    this.isRecent = false,
    this.isSuggested = false,
    required this.followService,
    required this.requestService,
    required this.auth,
    required this.onRemoveFromHistory,
    required this.onRefresh,
  }) : super(key: key);

  void _navigateToUserProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) =>
                UserProfileScreen(userId: user.id, username: user.username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: followService.isFollowing(user.id),
      builder: (context, isFollowingSnapshot) {
        return FutureBuilder<List<FollowRequest>>(
          future: requestService.getPendingRequests(user.id).first,
          builder: (context, requestsSnapshot) {
            final isFollowing = isFollowingSnapshot.data ?? false;
            final hasPendingRequest =
                requestsSnapshot.data?.any(
                  (request) => request.requesterId == auth.currentUser!.uid,
                ) ??
                false;

            return ListTile(
              leading: GestureDetector(
                onTap: () => _navigateToUserProfile(context),
                child: ProfileImageWidget(
                  imageUrl: user.profileImageUrl,
                  radius: 24,
                  fallbackName: user.username,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateToUserProfile(context),
                      child: Text(
                        user.username,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
                  if (isRecent)
                    IconButton(
                      icon: const Icon(Icons.history, size: 16),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Remove from search history?'),
                            action: SnackBarAction(
                              label: 'REMOVE',
                              onPressed: () => onRemoveFromHistory(user),
                            ),
                          ),
                        );
                      },
                      color: Colors.grey,
                      tooltip: 'Recent search',
                    ),
                ],
              ),
              subtitle:
                  user.bio != null && user.bio!.isNotEmpty
                      ? Text(
                        user.bio!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                      : null,
              trailing:
                  isFollowing
                      ? ElevatedButton(
                        onPressed: () async {
                          try {
                            await followService.unfollowUser(user.id);
                            onRefresh();
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[300],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Following'),
                      )
                      : hasPendingRequest
                      ? OutlinedButton(
                        onPressed: null,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        child: const Text('Requested'),
                      )
                      : ElevatedButton(
                        onPressed: () async {
                          try {
                            final currentUser = auth.currentUser!;
                            await requestService.sendFollowRequest(
                              requesterId: currentUser.uid,
                              targetId: user.id,
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Follow request sent!'),
                                ),
                              );
                              onRefresh();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          minimumSize: const Size(0, 36),
                          textStyle: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        child: const Text('Follow'),
                      ),
              onTap: () => _navigateToUserProfile(context),
            );
          },
        );
      },
    );
  }
}
