import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post.dart';
import '../models/movie.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createPost({
    required String userId,
    required String userName,
    required String userAvatar,
    required String content,
    required Movie movie,
    int rating = 0,
  }) async {
    await _firestore.collection('posts').add({
      'userId': userId,
      'userName': userName,
      'userAvatar': userAvatar,
      'content': content,
      'movieId': movie.id,
      'movieTitle': movie.title,
      'moviePosterUrl': movie.posterUrl,
      'movieYear': movie.year,
      'movieOverview': movie.overview,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': [],
      'commentCount': 0,
      'rating': rating,
    });
  }

  Stream<List<Post>> getPosts() {
    return _firestore
        .collection('posts')
        .orderBy('createdAt', descending: true)
        .orderBy('userId') // By default, orderBy is ascending
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  // Get posts for a specific user
  Stream<List<Post>> getUserPosts(String userId) {
    return _firestore
        .collection('posts')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => Post.fromJson(doc.data(), doc.id))
          .toList();
    });
  }

  // Toggle like on a post
  Future<void> toggleLike(String postId, String userId) async {
    final postRef = _firestore.collection('posts').doc(postId);
    final post = await postRef.get();

    if (post.exists) {
      final likes = List<String>.from(post.data()?['likes'] ?? []);

      if (likes.contains(userId)) {
        // Unlike
        await postRef.update({
          'likes': FieldValue.arrayRemove([userId])
        });
      } else {
        // Like
        await postRef.update({
          'likes': FieldValue.arrayUnion([userId])
        });
      }
    }
  }

  // Delete a post
  Future<void> deletePost(String postId) async {
    await _firestore.collection('posts').doc(postId).delete();
  }

  // Update a post's content
  Future<void> updatePostContent(String postId, String newContent) async {
    await _firestore.collection('posts').doc(postId).update({
      'content': newContent,
      'editedAt': FieldValue.serverTimestamp(),
    });
  }
}
