import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:like_button/like_button.dart';
import '../../services/post_service.dart';
import '../../screens/user_profile_screen.dart';

class CommentCard extends StatefulWidget {
  final Map<String, dynamic> comment;
  final Function onDelete;
  final bool showTopReply;
  final bool showReplyButton;

  const CommentCard({
    Key? key,
    required this.comment,
    required this.onDelete,
    this.showTopReply = true,
    this.showReplyButton = true,
  }) : super(key: key);

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLiked = false;
  List<String> _likes = [];

  @override
  void initState() {
    super.initState();
    _updateLikes();
  }

  void _updateLikes() {
    _likes = List<String>.from(widget.comment['likes'] ?? []);
    _isLiked = _likes.contains(_auth.currentUser?.uid);
  }

  @override
  void didUpdateWidget(CommentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.comment['likes'] != widget.comment['likes']) {
      _updateLikes();
    }
  }

  Future<void> _handleLike() async {
    if (_auth.currentUser == null) return;

    try {
      await _postService.toggleCommentLike(
        widget.comment['id'],
        widget.comment['postId'],
        _auth.currentUser!.uid,
      );
      setState(() {
        if (_isLiked) {
          _likes.remove(_auth.currentUser!.uid);
        } else {
          _likes.add(_auth.currentUser!.uid);
        }
        _isLiked = !_isLiked;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating like: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReplies() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => RepliesScreen(
              postId: widget.comment['postId'],
              parentComment: widget.comment,
            ),
      ),
    );
  }

  void _showCommentOptions() {
    final bool isCurrentUser =
        widget.comment['userId'] == _auth.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      builder:
          (context) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isCurrentUser) ...[
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    'Delete Comment',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('Delete Comment'),
                            content: const Text(
                              'Are you sure you want to delete this comment?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text(
                                  'Delete',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                    );

                    if (confirmed == true && mounted) {
                      try {
                        await _postService.deleteComment(
                          widget.comment['id'],
                          widget.comment['postId'],
                        );
                        widget.onDelete();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Comment deleted')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error deleting comment: $e'),
                            ),
                          );
                        }
                      }
                    }
                  },
                ),
              ],
            ],
          ),
    );
  }

  Widget _buildTopReply(BuildContext context) {
    if (widget.comment['replyCount'] == 0) return const SizedBox.shrink();

    return StreamBuilder<List<dynamic>>(
      stream: _postService.getComments(
        widget.comment['postId'],
        parentCommentId: widget.comment['id'],
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        // Find the reply with the most likes
        final replies = List<Map<String, dynamic>>.from(snapshot.data!);
        final topReply = replies.reduce((a, b) {
          final aLikes = List<String>.from(a['likes'] ?? []).length;
          final bLikes = List<String>.from(b['likes'] ?? []).length;
          return aLikes > bLikes ? a : b;
        });

        final likes = List<String>.from(topReply['likes'] ?? []);
        // Only show if the reply has likes or is the only reply
        if (likes.isEmpty && replies.length > 1) {
          return const SizedBox.shrink();
        }

        return Padding(
          padding: const EdgeInsets.only(left: 24.0, top: 8.0),
          child: InkWell(
            onTap: _showReplies,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundImage: NetworkImage(topReply['userAvatar']),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        topReply['userName'],
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (likes.isNotEmpty) ...[
                        const Spacer(),
                        Icon(Icons.favorite, size: 14, color: Colors.red[400]),
                        const SizedBox(width: 4),
                        Text(
                          likes.length.toString(),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    topReply['content'],
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (replies.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      'View all ${replies.length} replies...',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime createdAt = widget.comment['createdAt'];
    final bool hasReplies = (widget.comment['replyCount'] ?? 0) > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
              if (widget.comment['userId'] != _auth.currentUser?.uid) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => UserProfileScreen(
                          userId: widget.comment['userId'],
                          username: widget.comment['userName'],
                        ),
                  ),
                );
              }
            },
            child: CircleAvatar(
              radius: 16,
              backgroundImage: NetworkImage(widget.comment['userAvatar']),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            widget.comment['userName'],
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          GestureDetector(
                            onTap: _showCommentOptions,
                            child: const Icon(Icons.more_horiz, size: 16),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(widget.comment['content']),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 4.0),
                  child: Row(
                    children: [
                      Text(
                        timeago.format(createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(width: 16),
                      LikeButton(
                        size: 20,
                        isLiked: _isLiked,
                        likeCount: _likes.length,
                        onTap: (isLiked) async {
                          await _handleLike();
                          return !isLiked;
                        },
                        likeBuilder: (bool isLiked) {
                          return Icon(
                            isLiked ? Icons.favorite : Icons.favorite_border,
                            color:
                                isLiked
                                    ? Colors.red
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                            size: 16,
                          );
                        },
                        countBuilder: (int? count, bool isLiked, String text) {
                          if (count == 0) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 4.0),
                            child: Text(
                              text,
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    isLiked
                                        ? Colors.red
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withOpacity(0.6),
                              ),
                            ),
                          );
                        },
                      ),
                      if (widget.showReplyButton) ...[
                        const SizedBox(width: 16),
                        TextButton.icon(
                          onPressed: _showReplies,
                          icon: Icon(
                            Icons.reply,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                          label: Text(
                            hasReplies
                                ? '${widget.comment['replyCount']} replies'
                                : 'Reply',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasReplies && widget.showTopReply) _buildTopReply(context),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RepliesScreen extends StatelessWidget {
  final String postId;
  final Map<String, dynamic> parentComment;

  const RepliesScreen({
    Key? key,
    required this.postId,
    required this.parentComment,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Replies')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CommentCard(
              comment: parentComment,
              onDelete: () => Navigator.pop(context),
              showTopReply: false,
              showReplyButton: false,
            ),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<dynamic>>(
              stream: PostService().getComments(
                postId,
                parentCommentId: parentComment['id'],
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading replies: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                final replies = snapshot.data ?? [];

                if (replies.isEmpty) {
                  return const Center(
                    child: Text('No replies yet. Be the first to reply!'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: replies.length,
                  itemBuilder: (context, index) {
                    return CommentCard(
                      comment: replies[index],
                      onDelete: () {},
                      showTopReply: false,
                      showReplyButton: false,
                    );
                  },
                );
              },
            ),
          ),
          ReplyInput(postId: postId, parentCommentId: parentComment['id']),
        ],
      ),
    );
  }
}

class ReplyInput extends StatefulWidget {
  final String postId;
  final String parentCommentId;

  const ReplyInput({
    Key? key,
    required this.postId,
    required this.parentCommentId,
  }) : super(key: key);

  @override
  State<ReplyInput> createState() => _ReplyInputState();
}

class _ReplyInputState extends State<ReplyInput> {
  final TextEditingController _controller = TextEditingController();
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isSubmitting = false;

  Future<void> _submitReply() async {
    if (_controller.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final user = _auth.currentUser!;
      final userDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
      final userData = userDoc.data() ?? {};

      await _postService.addReply(
        postId: widget.postId,
        parentCommentId: widget.parentCommentId,
        userId: user.uid,
        userName: userData['username'] ?? user.displayName ?? 'Anonymous',
        userAvatar: userData['profileImageUrl'] ?? user.photoURL ?? '',
        content: _controller.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting reply: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Write a reply...',
                border: OutlineInputBorder(),
              ),
              maxLines: null,
              autofocus: true,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: _isSubmitting ? null : _submitReply,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
