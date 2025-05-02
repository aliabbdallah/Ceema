import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/post_service.dart';
import 'comment_card.dart';
import '../../widgets/profile_image_widget.dart';

class CommentList extends StatefulWidget {
  final String postId;
  final bool isEmbedded;

  const CommentList({Key? key, required this.postId, this.isEmbedded = false})
    : super(key: key);

  @override
  State<CommentList> createState() => _CommentListState();
}

class _CommentListState extends State<CommentList> {
  final PostService _postService = PostService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

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

      await _postService.addComment(
        postId: widget.postId,
        userId: user.uid,
        userName: userData['username'] ?? user.displayName ?? 'Anonymous',
        userAvatar:
            userData['profileImageUrl'] ??
            user.photoURL ??
            'https://via.placeholder.com/150',
        content: _commentController.text.trim(),
      );
      _commentController.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error posting comment: $e'),
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
    if (widget.isEmbedded) {
      return SliverList(
        delegate: SliverChildListDelegate([
          StreamBuilder<List<dynamic>>(
            stream: _postService.getComments(
              widget.postId,
              parentCommentId: null,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading comments: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return const SizedBox.shrink();
              }

              // Generate list with dividers
              List<Widget> commentWidgets = [];
              for (int i = 0; i < comments.length; i++) {
                commentWidgets.add(
                  CommentCard(
                    comment: comments[i],
                    onDelete: () async {
                      try {
                        await _postService.deleteComment(
                          comments[i]['id'],
                          widget.postId,
                        );
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
                    },
                  ),
                );
                if (i < comments.length - 1) {
                  commentWidgets.add(
                    const Divider(height: 1, thickness: 0.5),
                  ); // Add Divider
                }
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: commentWidgets, // Use the generated list
                ),
              );
            },
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 48, // Fixed height for single line
              decoration: BoxDecoration(
                color: const Color(0xFF1E2732), // Dark blue background
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFF38444D), // Twitter-like border color
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(24),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(24),
                        ),
                        child: TextField(
                          controller: _commentController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Write a comment...',
                            hintStyle: TextStyle(
                              color: Color(0xFF8899A6),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 14,
                            ),
                            fillColor: Color(0xFF1E2732),
                            filled: true,
                          ),
                          minLines: 1,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(24),
                      ),
                      onTap: _isSubmitting ? null : _submitComment,
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.send_rounded,
                          color:
                              _isSubmitting
                                  ? const Color(0xFF8899A6)
                                  : const Color(0xFF1D9BF0), // Twitter blue
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      );
    }

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<dynamic>>(
            stream: _postService.getComments(
              widget.postId,
              parentCommentId: null,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error loading comments: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final comments = snapshot.data ?? [];

              if (comments.isEmpty) {
                return const SizedBox.shrink();
              }

              // Generate list with dividers for non-embedded view
              List<Widget> commentWidgetsNonEmbedded = [];
              for (int i = 0; i < comments.length; i++) {
                commentWidgetsNonEmbedded.add(
                  CommentCard(
                    comment: comments[i],
                    onDelete: () async {
                      try {
                        await _postService.deleteComment(
                          comments[i]['id'],
                          widget.postId,
                        );
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
                    },
                  ),
                );
                if (i < comments.length - 1) {
                  commentWidgetsNonEmbedded.add(
                    const Divider(height: 1, thickness: 0.5),
                  ); // Add Divider
                }
              }

              // Note: Using a ListView inside an Expanded Column is often inefficient.
              // Consider refactoring if performance issues arise.
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView(
                  // Changed from Column to ListView for potential scrolling
                  children: commentWidgetsNonEmbedded, // Use the generated list
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: 48, // Fixed height for single line
            decoration: BoxDecoration(
              color: const Color(0xFF1E2732), // Dark blue background
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: const Color(0xFF38444D), // Twitter-like border color
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(24),
                      ),
                      child: TextField(
                        controller: _commentController,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Write a comment...',
                          hintStyle: TextStyle(
                            color: Color(0xFF8899A6),
                            fontSize: 16,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          fillColor: Color(0xFF1E2732),
                          filled: true,
                        ),
                        minLines: 1,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: const BorderRadius.horizontal(
                      right: Radius.circular(24),
                    ),
                    onTap: _isSubmitting ? null : _submitComment,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.send_rounded,
                        color:
                            _isSubmitting
                                ? const Color(0xFF8899A6)
                                : const Color(0xFF1D9BF0), // Twitter blue
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
