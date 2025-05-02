import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:ceema/models/post.dart';
import 'package:ceema/services/feed_cache_service.dart';

void main() {
  late FeedCacheService cacheService;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    cacheService = FeedCacheService(prefs);
  });

  group('FeedCacheService', () {
    test('should cache and retrieve posts', () async {
      final posts = [
        Post(
          id: '1',
          userId: 'user1',
          userName: 'user1',
          displayName: 'User One',
          userAvatar: 'avatar1',
          content: 'Test post 1',
          movieId: 'movie1',
          movieTitle: 'Movie 1',
          moviePosterUrl: 'poster1',
          movieYear: '2023',
          movieOverview: 'Overview 1',
          createdAt: DateTime.now(),
          likes: [],
          commentCount: 0,
        ),
        Post(
          id: '2',
          userId: 'user2',
          userName: 'user2',
          displayName: 'User Two',
          userAvatar: 'avatar2',
          content: 'Test post 2',
          movieId: 'movie2',
          movieTitle: 'Movie 2',
          moviePosterUrl: 'poster2',
          movieYear: '2023',
          movieOverview: 'Overview 2',
          createdAt: DateTime.now(),
          likes: [],
          commentCount: 0,
        ),
      ];

      await cacheService.cachePostsWithPagination(
        'forYou',
        posts,
        'lastDocId',
        false,
      );
      final result = await cacheService.getCachedPostsWithPagination('forYou');

      expect(result, isNotNull);
      expect(result!.posts.length, equals(2));
      expect(result.posts[0].id, equals('1'));
      expect(result.posts[1].id, equals('2'));
      expect(result.lastDocumentId, equals('lastDocId'));
      expect(result.isComplete, isFalse);
    });

    test('should handle cache expiration', () async {
      final posts = [
        Post(
          id: '1',
          userId: 'user1',
          userName: 'user1',
          displayName: 'User One',
          userAvatar: 'avatar1',
          content: 'Test post',
          movieId: 'movie1',
          movieTitle: 'Movie 1',
          moviePosterUrl: 'poster1',
          movieYear: '2023',
          movieOverview: 'Overview 1',
          createdAt: DateTime.now(),
          likes: [],
          commentCount: 0,
        ),
      ];

      // Cache posts with an old timestamp
      final cacheKey = 'feed_cache_forYou';
      final cacheData = {
        'posts':
            posts
                .map((post) => {'data': post.toJson(), 'id': post.id})
                .toList(),
        'timestamp':
            DateTime.now()
                .subtract(const Duration(hours: 2))
                .millisecondsSinceEpoch,
        'lastDocumentId': 'lastDocId',
        'isComplete': false,
      };
      await prefs.setString(cacheKey, jsonEncode(cacheData));

      final result = await cacheService.getCachedPostsWithPagination('forYou');
      expect(result, isNull);
    });

    test(
      'should handle fallback to expired cache when fresh fetch fails',
      () async {
        final posts = [
          Post(
            id: '1',
            userId: 'user1',
            userName: 'user1',
            displayName: 'User One',
            userAvatar: 'avatar1',
            content: 'Test post',
            movieId: 'movie1',
            movieTitle: 'Movie 1',
            moviePosterUrl: 'poster1',
            movieYear: '2023',
            movieOverview: 'Overview 1',
            createdAt: DateTime.now(),
            likes: [],
            commentCount: 0,
          ),
        ];

        // Cache posts with an old timestamp
        final cacheKey = 'feed_cache_forYou';
        final cacheData = {
          'posts':
              posts
                  .map((post) => {'data': post.toJson(), 'id': post.id})
                  .toList(),
          'timestamp':
              DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .millisecondsSinceEpoch,
          'lastDocumentId': 'lastDocId',
          'isComplete': false,
        };
        await prefs.setString(cacheKey, jsonEncode(cacheData));

        // Try to get posts with a failing fetch function
        final result = await cacheService.getPostsWithFallback(
          'forYou',
          () async {
            throw Exception('Failed to fetch fresh posts');
          },
        );

        expect(result.posts.length, equals(1));
        expect(result.posts[0].id, equals('1'));
      },
    );

    test('should handle update notifications', () async {
      bool notified = false;
      cacheService.onUpdate.listen((_) => notified = true);

      await cacheService.cachePostsWithPagination('forYou', [], null, true);
      expect(notified, isTrue);
    });

    test('should handle background updates', () async {
      bool notified = false;
      cacheService.onUpdate.listen((_) => notified = true);

      cacheService.startBackgroundUpdates();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notified, isTrue);
    });
  });
}
