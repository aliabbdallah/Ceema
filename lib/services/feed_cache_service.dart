import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/post.dart';
import 'simplified_post_recommendation_service.dart';
import 'post_service.dart';

class CacheResult {
  final List<Post> posts;
  final String? lastDocumentId;
  final bool isComplete;

  CacheResult({
    required this.posts,
    this.lastDocumentId,
    this.isComplete = false,
  });
}

class FeedCacheService {
  static const String _cacheKeyPrefix = 'feed_cache_';
  static const Duration _forYouCacheDuration = Duration(hours: 1);
  static const Duration _followingCacheDuration = Duration(minutes: 15);

  final SharedPreferences _prefs;
  final SimplifiedPostRecommendationService _recommendationService;
  final PostService _postService;
  final FirebaseAuth _auth;
  final _updateController = StreamController<void>.broadcast();
  Timer? _updateTimer;
  final _metrics = <String, dynamic>{};

  FeedCacheService(
    this._prefs, {
    SimplifiedPostRecommendationService? recommendationService,
    PostService? postService,
    FirebaseAuth? auth,
  }) : _recommendationService =
           recommendationService ?? SimplifiedPostRecommendationService(),
       _postService = postService ?? PostService(),
       _auth = auth ?? FirebaseAuth.instance;

  Stream<void> get onUpdate => _updateController.stream;

  void notifyUpdate(String feedType) {
    _updateController.add(null);
  }

  void startBackgroundUpdates() {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(const Duration(minutes: 5), (_) async {
      await _updateForYouCache();
      await _updateFollowingCache();
    });
  }

  void dispose() {
    _updateTimer?.cancel();
    _updateController.close();
  }

  Future<void> cachePostsWithPagination(
    String feedType,
    List<Post> posts,
    String? lastDocumentId,
    bool isComplete,
  ) async {
    try {
      final cacheKey = '$_cacheKeyPrefix$feedType';
      final cacheData = {
        'posts':
            posts
                .map((post) => {'data': post.toJson(), 'id': post.id})
                .toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'lastDocumentId': lastDocumentId,
        'isComplete': isComplete,
      };
      await _prefs.setString(cacheKey, jsonEncode(cacheData));

      // Create a backup after successful cache update
      await _createBackup(
        feedType,
        CacheResult(
          posts: posts,
          lastDocumentId: lastDocumentId,
          isComplete: isComplete,
        ),
      );

      notifyUpdate(feedType);
      _recordMetric('cache_success', {
        'feedType': feedType,
        'postCount': posts.length,
      });
    } catch (e) {
      _recordMetric('cache_error', {
        'feedType': feedType,
        'error': e.toString(),
      });
      rethrow;
    }
  }

  Future<CacheResult?> getCachedPostsWithPagination(String feedType) async {
    try {
      final cacheKey = '$_cacheKeyPrefix$feedType';
      final cacheData = _prefs.getString(cacheKey);
      if (cacheData == null) return null;

      final decoded = jsonDecode(cacheData);
      final timestamp = DateTime.fromMillisecondsSinceEpoch(
        decoded['timestamp'],
      );
      final duration =
          feedType == 'forYou' ? _forYouCacheDuration : _followingCacheDuration;

      if (DateTime.now().difference(timestamp) > duration) {
        await _prefs.remove(cacheKey);
        return null;
      }

      final posts =
          (decoded['posts'] as List)
              .map(
                (postData) => Post.fromJson(postData['data'], postData['id']),
              )
              .toList();

      _recordMetric('cache_hit', {
        'feedType': feedType,
        'postCount': posts.length,
      });
      return CacheResult(
        posts: posts,
        lastDocumentId: decoded['lastDocumentId'],
        isComplete: decoded['isComplete'] ?? false,
      );
    } catch (e) {
      _recordMetric('cache_error', {
        'feedType': feedType,
        'error': e.toString(),
      });
      return null;
    }
  }

  Future<CacheResult> getPostsWithFallback(
    String feedType,
    Future<CacheResult> Function() fetchFreshPosts,
  ) async {
    try {
      // Try to get cached posts first
      final cachedResult = await getCachedPostsWithPagination(feedType);
      if (cachedResult != null) {
        return cachedResult;
      }

      // If no cache or expired, fetch fresh posts
      final freshResult = await fetchFreshPosts();
      await cachePostsWithPagination(
        feedType,
        freshResult.posts,
        freshResult.lastDocumentId,
        freshResult.isComplete,
      );
      return freshResult;
    } catch (e) {
      _recordMetric('fetch_error', {
        'feedType': feedType,
        'error': e.toString(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Try to get any cached data, even if expired
      final anyCachedResult = await _getAnyCachedPosts(feedType);
      if (anyCachedResult != null) {
        _recordMetric('fallback_success', {
          'feedType': feedType,
          'postCount': anyCachedResult.posts.length,
        });
        return anyCachedResult;
      }

      // If we have no cache at all, try to recover from a backup
      final backupResult = await _tryRecoverFromBackup(feedType);
      if (backupResult != null) {
        _recordMetric('backup_recovery_success', {
          'feedType': feedType,
          'postCount': backupResult.posts.length,
        });
        return backupResult;
      }

      // Return empty result as last resort
      _recordMetric('complete_failure', {
        'feedType': feedType,
        'error': e.toString(),
      });
      return CacheResult(posts: [], isComplete: false);
    }
  }

  Future<CacheResult?> _getAnyCachedPosts(String feedType) async {
    try {
      final cacheKey = '$_cacheKeyPrefix$feedType';
      final cacheData = _prefs.getString(cacheKey);
      if (cacheData == null) return null;

      final decoded = jsonDecode(cacheData);
      final posts =
          (decoded['posts'] as List)
              .map(
                (postData) => Post.fromJson(postData['data'], postData['id']),
              )
              .toList();

      return CacheResult(
        posts: posts,
        lastDocumentId: decoded['lastDocumentId'],
        isComplete: decoded['isComplete'] ?? false,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateForYouCache() async {
    try {
      final result = await _recommendationService.getRecommendedPosts();
      await cachePostsWithPagination(
        'forYou',
        result.posts,
        result.lastDoc?.id,
        false,
      );
      notifyUpdate('forYou');
      _recordMetric('update_success', {'feedType': 'forYou'});
    } catch (e) {
      _recordMetric('update_error', {
        'feedType': 'forYou',
        'error': e.toString(),
      });
    }
  }

  Future<void> _updateFollowingCache() async {
    try {
      final posts = await _postService.fetchFollowingPostsOnce(
        _auth.currentUser!.uid,
      );
      await cachePostsWithPagination('following', posts, null, false);
      notifyUpdate('following');
      _recordMetric('update_success', {'feedType': 'following'});
    } catch (e) {
      _recordMetric('update_error', {
        'feedType': 'following',
        'error': e.toString(),
      });
    }
  }

  Future<CacheResult?> _tryRecoverFromBackup(String feedType) async {
    try {
      final backupKey = '${_cacheKeyPrefix}${feedType}_backup';
      final backupData = _prefs.getString(backupKey);
      if (backupData == null) return null;

      final decoded = jsonDecode(backupData);
      final posts =
          (decoded['posts'] as List)
              .map(
                (postData) => Post.fromJson(postData['data'], postData['id']),
              )
              .toList();

      // Restore the backup to main cache
      await cachePostsWithPagination(
        feedType,
        posts,
        decoded['lastDocumentId'],
        decoded['isComplete'] ?? false,
      );

      return CacheResult(
        posts: posts,
        lastDocumentId: decoded['lastDocumentId'],
        isComplete: decoded['isComplete'] ?? false,
      );
    } catch (e) {
      _recordMetric('backup_recovery_error', {
        'feedType': feedType,
        'error': e.toString(),
      });
      return null;
    }
  }

  Future<void> _createBackup(String feedType, CacheResult result) async {
    try {
      final backupKey = '${_cacheKeyPrefix}${feedType}_backup';
      final backupData = {
        'posts':
            result.posts
                .map((post) => {'data': post.toJson(), 'id': post.id})
                .toList(),
        'lastDocumentId': result.lastDocumentId,
        'isComplete': result.isComplete,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      await _prefs.setString(backupKey, jsonEncode(backupData));
    } catch (e) {
      _recordMetric('backup_error', {
        'feedType': feedType,
        'error': e.toString(),
      });
    }
  }

  void _recordMetric(String name, dynamic value) {
    _metrics[name] = value;
  }

  Future<void> _logMetrics() async {
    // This will be implemented to send metrics to analytics
    print('Metrics: $_metrics');
  }
}
