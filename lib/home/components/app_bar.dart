// lib/home/components/app_bar.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ceema/screens/notifications_screen.dart';
import 'package:ceema/screens/dm_screen.dart';
import 'package:ceema/services/notification_service.dart';
import 'package:ceema/services/dm_service.dart';
import 'package:ceema/models/conversation.dart';

class CeemaAppBar extends StatelessWidget {
  const CeemaAppBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final notificationService = NotificationService();
    final dmService = DMService();

    return SliverAppBar(
      floating: true,
      pinned: false,
      stretch: true,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: colorScheme.surface,
      title: const Text(
        'Ceema',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
      ),
      actions: [
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsScreen(),
                  ),
                );
              },
            ),
            StreamBuilder<int>(
              stream: notificationService.getUnreadNotificationCount(),
              builder: (context, snapshot) {
                final unreadCount = snapshot.data ?? 0;

                if (unreadCount == 0) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child:
                        unreadCount > 9
                            ? Text(
                              '9+',
                              style: TextStyle(
                                color: colorScheme.onError,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : unreadCount > 1
                            ? Text(
                              '$unreadCount',
                              style: TextStyle(
                                color: colorScheme.onError,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.onError,
                                shape: BoxShape.circle,
                              ),
                            ),
                  ),
                );
              },
            ),
          ],
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Direct Messages',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const DMScreen()),
                );
              },
            ),
            StreamBuilder<List<Conversation>>(
              stream: dmService.getConversations(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const SizedBox.shrink();
                }

                final unreadCount =
                    snapshot.data!
                        .where((conversation) => conversation.isUnread)
                        .length;

                if (unreadCount == 0) {
                  return const SizedBox.shrink();
                }

                return Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colorScheme.error,
                      shape: BoxShape.circle,
                    ),
                    child:
                        unreadCount > 9
                            ? Text(
                              '9+',
                              style: TextStyle(
                                color: colorScheme.onError,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : unreadCount > 1
                            ? Text(
                              '$unreadCount',
                              style: TextStyle(
                                color: colorScheme.onError,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                            : Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colorScheme.onError,
                                shape: BoxShape.circle,
                              ),
                            ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
