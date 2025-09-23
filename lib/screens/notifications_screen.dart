import 'package:flutter/material.dart';
import 'package:ceema/models/notification.dart' as app_notification;
import 'package:ceema/services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ceema/screens/profile_screen.dart';
import 'package:ceema/screens/user_profile_screen.dart';
import 'package:ceema/screens/followers_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ceema/widgets/profile_image_widget.dart';
import 'package:ceema/screens/follow_requests_screen.dart';
import 'package:ceema/screens/comments_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ceema/models/post.dart';
import 'package:ceema/services/follow_request_service.dart';
import 'package:ceema/models/follow_request.dart';
import 'package:ceema/services/follow_service.dart';
import 'package:ceema/screens/post_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Mark all as read when screen opens
    _markAllAsRead();
  }

  Future<void> _markAllAsRead() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _notificationService.markAllAsRead();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 70,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ll be notified about friend requests,\nlikes, comments and more',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _handleNotificationTap(
    app_notification.Notification notification,
  ) async {
    // Mark notification as read
    await _notificationService.markAsRead(notification.id);

    // Navigate based on notification type
    switch (notification.type) {
      case app_notification.NotificationType.followRequest:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const FollowRequestsScreen()),
        );
        break;
      case app_notification.NotificationType.followBackSuggestion:
        if (notification.senderUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => UserProfileScreen(
                    userId: notification.senderUserId!,
                    username: notification.senderName ?? 'User',
                  ),
            ),
          );
        }
        break;
      case app_notification.NotificationType.commentReply:
      case app_notification.NotificationType.postLike:
      case app_notification.NotificationType.postComment:
        if (notification.referenceId != null) {
          // Fetch the post data and navigate to post screen
          FirebaseFirestore.instance
              .collection('posts')
              .doc(notification.referenceId)
              .get()
              .then((doc) {
                if (doc.exists) {
                  final post = Post.fromJson(doc.data()!, doc.id);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PostScreen(post: post),
                    ),
                  );
                } else {
                  // If post not found, show error
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Post not found')),
                  );
                }
              })
              .catchError((error) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${error.toString()}')),
                );
              });
        }
        break;
      case app_notification.NotificationType.followRequestSent:
      case app_notification.NotificationType.followRequestSentAccepted:
        if (notification.senderUserId != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => UserProfileScreen(
                    userId: notification.senderUserId!,
                    username: notification.senderName ?? 'User',
                  ),
            ),
          );
        }
        break;
      case app_notification.NotificationType.follow:
      case app_notification.NotificationType.followRequestAccepted:
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => FollowersScreen(targetUserId: currentUser.uid),
            ),
          );
        }
        break;
      case app_notification.NotificationType.systemNotice:
        // For system notifications, usually no action is needed
        break;
    }
  }

  Widget _buildNotificationItem(app_notification.Notification notification) {
    final colorScheme = Theme.of(context).colorScheme;

    // Choose icon based on notification type
    IconData iconData;
    Color iconColor;

    switch (notification.type) {
      case app_notification.NotificationType.follow:
        iconData = Icons.person_add_outlined;
        iconColor = Colors.blue;
        break;
      case app_notification.NotificationType.commentReply:
        iconData = Icons.reply_outlined;
        iconColor = Colors.purple;
        break;
      case app_notification.NotificationType.followRequest:
        iconData = Icons.person_add_outlined;
        iconColor = Colors.blue;
        break;
      case app_notification.NotificationType.followRequestAccepted:
        iconData = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case app_notification.NotificationType.followRequestSent:
        iconData = Icons.person_add_outlined;
        iconColor = Colors.blue;
        break;
      case app_notification.NotificationType.followRequestSentAccepted:
        iconData = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case app_notification.NotificationType.followBackSuggestion:
        iconData = Icons.person_add_outlined;
        iconColor = Colors.blue;
        break;
      case app_notification.NotificationType.postLike:
        iconData = Icons.favorite_outline;
        iconColor = Colors.red;
        break;
      case app_notification.NotificationType.postComment:
        iconData = Icons.comment_outlined;
        iconColor = Colors.purple;
        break;
      case app_notification.NotificationType.systemNotice:
        iconData = Icons.info_outline;
        iconColor = Colors.orange;
        break;
    }

    return Slidable(
      key: Key(notification.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) async {
              await _notificationService.deleteNotification(notification.id);
            },
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: 'Delete',
          ),
        ],
      ),
      child: Container(
        decoration: BoxDecoration(
          color:
              notification.isRead
                  ? colorScheme.surface
                  : colorScheme.primaryContainer.withOpacity(0.1),
          border: Border(
            bottom: BorderSide(
              color: colorScheme.outlineVariant.withOpacity(0.3),
              width: 0.5,
            ),
          ),
        ),
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(iconData, color: iconColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: Theme.of(
                          context,
                        ).textTheme.titleMedium?.copyWith(
                          fontWeight:
                              notification.isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        timeago.format(notification.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                      if (notification.type ==
                          app_notification.NotificationType.followRequest)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            children: [
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    final followRequestService =
                                        FollowRequestService();
                                    // Find the follow request document
                                    final requestQuery =
                                        await FirebaseFirestore.instance
                                            .collection('follow_requests')
                                            .where(
                                              'requesterId',
                                              isEqualTo:
                                                  notification.senderUserId,
                                            )
                                            .where(
                                              'targetId',
                                              isEqualTo:
                                                  FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.uid,
                                            )
                                            .where(
                                              'status',
                                              isEqualTo:
                                                  FollowRequestStatus
                                                      .pending
                                                      .name,
                                            )
                                            .get();

                                    if (requestQuery.docs.isNotEmpty) {
                                      await followRequestService
                                          .acceptFollowRequest(
                                            requestQuery.docs.first.id,
                                          );
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error accepting request: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text('Accept'),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () async {
                                  try {
                                    final followRequestService =
                                        FollowRequestService();
                                    // Find the follow request document
                                    final requestQuery =
                                        await FirebaseFirestore.instance
                                            .collection('follow_requests')
                                            .where(
                                              'requesterId',
                                              isEqualTo:
                                                  notification.senderUserId,
                                            )
                                            .where(
                                              'targetId',
                                              isEqualTo:
                                                  FirebaseAuth
                                                      .instance
                                                      .currentUser
                                                      ?.uid,
                                            )
                                            .where(
                                              'status',
                                              isEqualTo:
                                                  FollowRequestStatus
                                                      .pending
                                                      .name,
                                            )
                                            .get();

                                    if (requestQuery.docs.isNotEmpty) {
                                      await followRequestService
                                          .declineFollowRequest(
                                            requestQuery.docs.first.id,
                                          );
                                      await _notificationService
                                          .deleteNotification(notification.id);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error declining request: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                ),
                                child: const Text('Decline'),
                              ),
                            ],
                          ),
                        ),
                      if (notification.type ==
                          app_notification
                              .NotificationType
                              .followBackSuggestion)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                final followRequestService =
                                    FollowRequestService();
                                await followRequestService.sendFollowRequest(
                                  requesterId:
                                      FirebaseAuth.instance.currentUser!.uid,
                                  targetId: notification.senderUserId!,
                                );
                                await _notificationService
                                    .createFollowRequestSentNotification(
                                      recipientUserId:
                                          FirebaseAuth
                                              .instance
                                              .currentUser!
                                              .uid,
                                      senderUserId: notification.senderUserId!,
                                      senderName:
                                          notification.senderName ?? 'User',
                                      senderPhotoUrl:
                                          notification.senderPhotoUrl ?? '',
                                    );
                                await _notificationService.deleteNotification(
                                  notification.id,
                                );
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error sending follow request: $e',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                            ),
                            child: const Text('Follow Back'),
                          ),
                        ),
                      if (notification.type ==
                          app_notification.NotificationType.followRequestSent)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Request sent',
                            style: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.copyWith(
                              color: Colors.grey,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      if (notification.type ==
                          app_notification
                              .NotificationType
                              .followRequestSentAccepted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            timeago.format(notification.createdAt),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colorScheme.outline),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_all') {
                showDialog(
                  context: context,
                  builder:
                      (context) => AlertDialog(
                        title: const Text('Clear All Notifications'),
                        content: const Text(
                          'Are you sure you want to delete all notifications? This cannot be undone.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('CANCEL'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _notificationService.deleteAllNotifications();
                            },
                            child: const Text('DELETE'),
                          ),
                        ],
                      ),
                );
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem<String>(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep_outlined),
                        SizedBox(width: 8),
                        Text('Clear all notifications'),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : StreamBuilder<List<app_notification.Notification>>(
                stream: _notificationService.getUserNotifications(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final notifications = snapshot.data ?? [];

                  if (notifications.isEmpty) {
                    return _buildEmptyState();
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: notifications.length,
                    itemBuilder: (context, index) {
                      return _buildNotificationItem(notifications[index]);
                    },
                  );
                },
              ),
    );
  }
}
