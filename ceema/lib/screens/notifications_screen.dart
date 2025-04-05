import 'package:flutter/material.dart';
import 'package:ceema/models/notification.dart' as app_notification;
import 'package:ceema/services/notification_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:ceema/screens/profile_screen.dart';
import 'package:ceema/screens/user_profile_screen.dart';
import 'package:ceema/screens/friends_screen.dart';
import 'package:ceema/screens/timeline_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ceema/widgets/profile_image_widget.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
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

  void _handleNotificationTap(app_notification.Notification notification) {
    // Navigate based on notification type
    switch (notification.type) {
      case app_notification.NotificationType.friendRequest:
      case app_notification.NotificationType.friendAccepted:
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FriendsScreen(
                userId: currentUser.uid,
              ),
            ),
          );
        }
        break;
      case app_notification.NotificationType.postLike:
      case app_notification.NotificationType.postComment:
        if (notification.referenceId != null) {
          // Navigate to post (if we had a specific PostScreen we would navigate there)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const TimelineScreen(), // This is a placeholder
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
      case app_notification.NotificationType.friendRequest:
        iconData = Icons.person_add_outlined;
        iconColor = Colors.blue;
        break;
      case app_notification.NotificationType.friendAccepted:
        iconData = Icons.people_outline;
        iconColor = Colors.green;
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

    return Dismissible(
      key: Key(notification.id),
      background: Container(
        color: colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(
          Icons.delete_outline,
          color: colorScheme.onErrorContainer,
        ),
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _notificationService.deleteNotification(notification.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Notification deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // No real undo functionality as we'd need to keep the notification data
                // This would just show another snackbar in a real app
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot restore notification')),
                );
              },
            ),
          ),
        );
      },
      child: InkWell(
        onTap: () => _handleNotificationTap(notification),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: notification.isRead
                ? colorScheme.surface
                : colorScheme.primaryContainer.withOpacity(0.1),
            border: Border(
              bottom: BorderSide(
                color: colorScheme.outlineVariant.withOpacity(0.3),
                width: 0.5,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (notification.senderPhotoUrl != null &&
                  notification.senderPhotoUrl!.isNotEmpty)
                ProfileImageWidget(
                  imageUrl: notification.senderPhotoUrl,
                  radius: 24,
                  fallbackName: notification.senderName ?? 'User',
                )
              else
                CircleAvatar(
                  backgroundColor: iconColor.withOpacity(0.1),
                  radius: 24,
                  child: Icon(
                    iconData,
                    color: iconColor,
                    size: 24,
                  ),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: notification.isRead
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
                  ],
                ),
              ),
            ],
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
                  builder: (context) => AlertDialog(
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
            itemBuilder: (context) => [
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
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<List<app_notification.Notification>>(
              stream: _notificationService.getUserNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error: ${snapshot.error}'),
                  );
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
