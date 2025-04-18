// lib/home/components/post_list.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import './post_card.dart';

class PostList extends StatelessWidget {
  final List<Post> posts;
  final bool showFollowingEmptyState; // To customize empty message

  const PostList({
    Key? key,
    required this.posts,
    this.showFollowingEmptyState = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (posts.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                showFollowingEmptyState ? Icons.person_search : Icons.post_add,
                size: 64,
                color: colorScheme.primary.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                showFollowingEmptyState
                    ? 'No posts from following'
                    : 'No posts yet',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                showFollowingEmptyState
                    ? 'Follow users to see their posts here.'
                    : 'Check back later or be the first to post!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Build the SliverList if posts exist
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          // Add padding at the end of the list
          if (index == posts.length) {
            return const SizedBox(height: 80);
          }
          // Use the seamless post card
          return SeamlessPostCard(post: posts[index]);
        },
        // +1 for the bottom padding SizedBox
        childCount: posts.length + 1,
      ),
    );
  }
}
