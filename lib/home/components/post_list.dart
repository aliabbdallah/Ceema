import 'package:flutter/material.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import 'post_card.dart';

class PostList extends StatelessWidget {
  const PostList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Post>>(
      stream: PostService().getPosts(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => PostCard(post: snapshot.data![index]),
            childCount: snapshot.data!.length,
          ),
        );
      },
    );
  }
}
