import 'package:flutter/material.dart';
import '../../../models/post.dart';
import '../widgets/post_list_item.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostSearchTab extends StatelessWidget {
  final List<Post> postResults;
  final bool isLoading;
  final bool isSearchActive;
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  const PostSearchTab({
    Key? key,
    required this.postResults,
    required this.isLoading,
    required this.isSearchActive,
    required this.auth,
    required this.firestore,
  }) : super(key: key);

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.article_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'No posts found',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text(
            'Search Posts',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Find posts by movie titles or content',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (isSearchActive && postResults.isEmpty) {
      return _buildEmptyState();
    }

    if (postResults.isNotEmpty) {
      return ListView.builder(
        itemCount: postResults.length,
        itemBuilder:
            (context, index) => PostListItem(
              post: postResults[index],
              auth: auth,
              firestore: firestore,
            ),
      );
    }

    return _buildInitialState();
  }
}
