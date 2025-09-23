import 'package:flutter/material.dart';
import 'package:ceema/models/post.dart';
import 'package:ceema/home/components/post_card.dart';
import 'package:ceema/home/components/comment_list.dart';
import 'package:ceema/services/post_service.dart';

class PostScreen extends StatelessWidget {
  final Post post;

  const PostScreen({Key? key, required this.post}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post')),
      body: CustomScrollView(
        slivers: [
          // Post content
          SliverToBoxAdapter(
            child: SeamlessPostCard(post: post, isClickable: false),
          ),

          // Comments section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Comments',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Comments list
          CommentList(postId: post.id, isEmbedded: true),
        ],
      ),
    );
  }
}
