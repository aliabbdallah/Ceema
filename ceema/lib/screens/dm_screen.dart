import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation.dart';
import '../services/dm_service.dart';
import 'conversation_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DMScreen extends StatelessWidget {
  const DMScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dmService = DMService();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Direct Messages',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
        ],
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: dmService.getConversations(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final conversations = snapshot.data!;
          if (conversations.isEmpty) {
            return Center(
              child: Text(
                'No conversations yet',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            );
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Recent Conversations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final conversation = conversations[index];
                  final otherUserId = conversation.participants.firstWhere(
                    (id) => id != FirebaseAuth.instance.currentUser?.uid,
                  );

                  return _buildConversationTile(
                    context,
                    conversation,
                    otherUserId,
                  );
                }, childCount: conversations.length),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement new conversation
        },
        child: const Icon(Icons.edit_outlined),
      ),
    );
  }

  Widget _buildConversationTile(
    BuildContext context,
    Conversation conversation,
    String otherUserId,
  ) {
    final otherUserName =
        conversation.participantNames[otherUserId] ?? 'Unknown User';

    return ListTile(
      leading: StreamBuilder<DocumentSnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('users')
                .doc(otherUserId)
                .snapshots(),
        builder: (context, snapshot) {
          final profileImageUrl =
              snapshot.data?.get('profileImageUrl') as String?;
          final username = snapshot.data?.get('username') as String?;

          return CircleAvatar(
            backgroundImage:
                profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl)
                    : null,
            child:
                profileImageUrl == null || profileImageUrl.isEmpty
                    ? Text((username ?? otherUserName)[0].toUpperCase())
                    : null,
          );
        },
      ),
      title: Row(
        children: [
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(otherUserId)
                      .snapshots(),
              builder: (context, snapshot) {
                final username = snapshot.data?.get('username') as String?;
                return Text(
                  username ?? otherUserName,
                  style: const TextStyle(fontWeight: FontWeight.normal),
                );
              },
            ),
          ),
          Text(
            _formatTime(conversation.lastMessageTime),
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
        ],
      ),
      subtitle: Text(
        conversation.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontWeight: FontWeight.normal,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
      trailing:
          conversation.isUnread
              ? Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              )
              : null,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) => ConversationScreen(
                  conversationId: conversation.id,
                  otherUserId: otherUserId,
                  otherUsername: otherUserName,
                ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'now';
    }
  }
}
