import 'package:flutter/material.dart';
import '../models/post.dart';
import '../home/components/comment_list.dart';

class CommentsScreen extends StatelessWidget {
  final Post post;

  const CommentsScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Comments'),
        elevation: 0,
      ),
      body: CommentList(postId: post.id),
    );
  }
}
