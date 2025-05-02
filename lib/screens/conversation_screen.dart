import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/message.dart';
import '../services/dm_service.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/profile_image_widget.dart';

class ConversationScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUsername;
  final String? otherUserAvatar;

  const ConversationScreen({
    Key? key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUsername,
    this.otherUserAvatar,
  }) : super(key: key);

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final DMService _dmService = DMService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isComposing = false;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _dmService.markAsRead(widget.conversationId);
    _messageController.addListener(_handleTextChanged);
  }

  @override
  void dispose() {
    _messageController.removeListener(_handleTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    if (_isTyping) {
      _dmService.setTypingStatus(
        widget.conversationId,
        _auth.currentUser!.uid,
        false,
      );
    }
    super.dispose();
  }

  void _handleTextChanged() {
    setState(() {
      _isComposing = _messageController.text.trim().isNotEmpty;
    });

    if (!_isTyping) {
      _isTyping = true;
      _dmService.setTypingStatus(
        widget.conversationId,
        _auth.currentUser!.uid,
        true,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isTyping) {
        _isTyping = false;
        _dmService.setTypingStatus(
          widget.conversationId,
          _auth.currentUser!.uid,
          false,
        );
      }
    });
  }

  void _handleSubmitted(String text) {
    if (text.trim().isEmpty) return;

    _messageController.clear();
    setState(() {
      _isComposing = false;
    });

    _dmService.sendMessage(widget.conversationId, text);
  }

  String _formatMessageTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  String _formatDayHeader(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    } else if (now.difference(time).inDays < 7) {
      return DateFormat('EEEE').format(time);
    } else {
      return DateFormat('MMMM d, y').format(time);
    }
  }

  Widget _buildDayHeader(DateTime timestamp) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            _formatDayHeader(timestamp),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final theme = Theme.of(context);
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          left: isMe ? 64 : 8,
          right: isMe ? 8 : 64,
          bottom: 4,
        ),
        child: GestureDetector(
          onLongPress:
              isMe
                  ? () {
                    showModalBottomSheet(
                      context: context,
                      builder:
                          (context) => Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.edit),
                                  title: const Text('Edit Message'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showEditDialog(message);
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.delete),
                                  title: const Text('Delete Message'),
                                  onTap: () {
                                    Navigator.pop(context);
                                    _showDeleteConfirmation(message);
                                  },
                                ),
                              ],
                            ),
                          ),
                    );
                  }
                  : null,
          child: Container(
            decoration: BoxDecoration(
              color:
                  isMe
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondaryContainer,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color:
                          isMe
                              ? theme.colorScheme.onPrimary
                              : theme.colorScheme.onSecondaryContainer,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(
                        fontSize: 11,
                        color: (isMe
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSecondaryContainer)
                            .withOpacity(0.7),
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 2),
                      Icon(
                        Icons.done_all,
                        size: 14,
                        color: theme.colorScheme.onPrimary.withOpacity(0.7),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEditDialog(Message message) {
    final TextEditingController editController = TextEditingController(
      text: message.content,
    );
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Edit Message'),
            content: TextField(
              controller: editController,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Edit your message'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  if (editController.text.trim().isNotEmpty) {
                    _dmService.updateMessage(
                      widget.conversationId,
                      message.id,
                      editController.text,
                    );
                    Navigator.pop(context);
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  void _showDeleteConfirmation(Message message) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Message'),
            content: const Text(
              'Are you sure you want to delete this message?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  _dmService.deleteMessage(widget.conversationId, message.id);
                  Navigator.pop(context);
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  Widget _buildMessageInput() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.outline.withOpacity(0.2),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 1,
                    maxLines: 5,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message',
                      hintStyle: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(
                          0.7,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    onSubmitted: _isComposing ? _handleSubmitted : null,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              decoration: BoxDecoration(
                color:
                    _isComposing
                        ? theme.colorScheme.primary
                        : theme.colorScheme.surfaceVariant.withOpacity(0.3),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: Icon(
                  Icons.send_rounded,
                  color:
                      _isComposing
                          ? theme.colorScheme.onPrimary
                          : theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
                onPressed:
                    _isComposing
                        ? () => _handleSubmitted(_messageController.text)
                        : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.otherUserId)
                      .snapshots(),
              builder: (context, snapshot) {
                final profileImageUrl =
                    snapshot.data?.get('profileImageUrl') as String?;
                final username = snapshot.data?.get('username') as String?;

                return ProfileImageWidget(
                  imageUrl: profileImageUrl,
                  radius: 20,
                  fallbackName: username ?? widget.otherUsername,
                );
              },
            ),
            const SizedBox(width: 12),
            StreamBuilder<DocumentSnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(widget.otherUserId)
                      .snapshots(),
              builder: (context, snapshot) {
                final username = snapshot.data?.get('username') as String?;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username ?? widget.otherUsername,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    StreamBuilder<Map<String, bool>>(
                      stream: _dmService.getTypingStatus(widget.conversationId),
                      builder: (context, snapshot) {
                        final typingStatus = snapshot.data ?? {};
                        final otherUserId = widget.otherUserId;
                        final isTyping = typingStatus[otherUserId] ?? false;

                        if (isTyping) {
                          return Text(
                            'typing...',
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Implement conversation options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Message>>(
              stream: _dmService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == _auth.currentUser?.uid;

                    // Show day header if it's the first message or if the day changes
                    final showDayHeader =
                        index == messages.length - 1 ||
                        !_isSameDay(
                          messages[index].timestamp,
                          messages[index + 1].timestamp,
                        );

                    return Column(
                      children: [
                        if (showDayHeader) _buildDayHeader(message.timestamp),
                        _buildMessageBubble(message, isMe),
                      ],
                    );
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }
}
