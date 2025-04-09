import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/post_service.dart';
import '../../screens/user_profile_screen.dart';

class CommentCard extends StatefulWidget {
  final Map<String, dynamic> comment;
  final Function onDelete;

  const CommentCard({Key? key, required this.comment, required this.onDelete})
    : super(key: key);

  @override
  State<CommentCard> createState() => _CommentCardState();
}

class _CommentCardState extends State<CommentCard> {
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLiked = false;

  @override
  void initState() {
    super.initState();
    _isLiked = (widget.comment['likes'] as List).contains(
      _auth.currentUser?.uid,
    );
  }

  Future<void> _handleLike() async {
    try {
      await _postService.toggleCommentLike(
        widget.comment['id'],
        _auth.currentUser!.uid,
      );
      setState(() {
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

  @override
  Widget build(BuildContext context) {
    final DateTime createdAt = widget.comment['createdAt'];

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
                      GestureDetector(
                        onTap: _handleLike,
                        child: Text(
                          'Like',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                _isLiked ? FontWeight.bold : FontWeight.normal,
                            color:
                                _isLiked
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(
                                      context,
                                    ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if ((widget.comment['likes'] as List).isNotEmpty)
                        Text(
                          (widget.comment['likes'] as List).length.toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
