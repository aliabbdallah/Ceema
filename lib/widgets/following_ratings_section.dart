import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../services/follow_service.dart';
import 'rating_avatar_card.dart';
import 'dart:convert';

class FollowingRatingsSection extends StatefulWidget {
  final String movieId;

  const FollowingRatingsSection({Key? key, required this.movieId})
    : super(key: key);

  @override
  _FollowingRatingsSectionState createState() =>
      _FollowingRatingsSectionState();
}

class _FollowingRatingsSectionState extends State<FollowingRatingsSection> {
  final _followService = FollowService();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  List<Map<String, dynamic>> _ratings = [];
  bool _isLoading = true;
  bool _hasMore = true;
  DocumentSnapshot? _lastDocument;
  static const int _pageSize = 10;
  StreamSubscription<dynamic>? _ratingsSubscription;
  static const String _cacheKeyPrefix = 'following_ratings_';

  // Cache for following users' IDs
  static final Map<String, List<String>> _followingCache = {};
  static final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  String get _noRatingsText => Intl.message(
    'No ratings from people you follow yet',
    name: 'noRatingsText',
    desc: 'Text shown when there are no ratings from followed users',
  );

  String get _ratingsTitle => Intl.message(
    'Watched By',
    name: 'ratingsTitle',
    desc: 'Title for the following ratings section',
  );

  @override
  void initState() {
    super.initState();
    _loadCachedRatings();
    _loadFollowingRatings();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _ratingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadCachedRatings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString('${_cacheKeyPrefix}${widget.movieId}');

      if (cachedData != null) {
        final decodedData = json.decode(cachedData) as Map<String, dynamic>;
        final ratingsList = decodedData['ratings'] as List;

        if (mounted) {
          setState(() {
            _ratings =
                ratingsList.map((r) => Map<String, dynamic>.from(r)).toList();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading cached ratings: $e');
    }
  }

  Future<void> _cacheRatings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dataToCache = {
        'ratings': _ratings,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(
        '${_cacheKeyPrefix}${widget.movieId}',
        json.encode(dataToCache),
      );
    } catch (e) {
      debugPrint('Error caching ratings: $e');
    }
  }

  void _setupRealTimeUpdates() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final followingIds = await _getFollowingIds(currentUser.uid);
      if (followingIds.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Listen to diary entries
      final diaryStream = _firestore
          .collection('diary_entries')
          .where('userId', whereIn: followingIds)
          .where('movieId', isEqualTo: widget.movieId)
          .orderBy('watchedDate', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            if (!mounted) return null;
            await _processRatingsSnapshot(snapshot, 'diary');
            return null;
          });

      // Listen to direct ratings
      final ratingsStream = _firestore
          .collection('movie_ratings')
          .where('userId', whereIn: followingIds)
          .where('movieId', isEqualTo: widget.movieId)
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .asyncMap((snapshot) async {
            if (!mounted) return null;
            await _processRatingsSnapshot(snapshot, 'rating');
            return null;
          });

      _ratingsSubscription = MergeStream([diaryStream, ratingsStream]).listen(
        (_) {},
        onError: (error) {
          debugPrint('Error in real-time updates: $error');
        },
      );
    } catch (e) {
      debugPrint('Error setting up real-time updates: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processRatingsSnapshot(
    QuerySnapshot snapshot,
    String source,
  ) async {
    if (snapshot.docs.isEmpty) {
      if (mounted) {
        setState(() {
          _ratings = [];
          _isLoading = false;
        });
      }
      return;
    }

    // Map to store the latest rating for each user
    final Map<String, Map<String, dynamic>> userLatestRatings = {};

    // Process new ratings
    for (var doc in snapshot.docs) {
      final ratingData = doc.data() as Map<String, dynamic>;
      final userId = ratingData['userId'] as String;

      // Only keep the latest rating for each user
      if (!userLatestRatings.containsKey(userId) ||
          (ratingData[source == 'diary' ? 'watchedDate' : 'updatedAt']
                      as Timestamp)
                  .compareTo(
                    userLatestRatings[userId]!['watchedAt'] as Timestamp,
                  ) >
              0) {
        userLatestRatings[userId] = {
          ...ratingData,
          'source': source,
          'watchedAt':
              source == 'diary'
                  ? ratingData['watchedDate']
                  : ratingData['updatedAt'],
        };
      }
    }

    // Fetch user data and create final ratings list
    final List<Map<String, dynamic>> newRatings = [];
    for (var userId in userLatestRatings.keys) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData != null) {
          newRatings.add({...userLatestRatings[userId]!, 'user': userData});
        }
      }
    }

    // Sort ratings by watched date
    newRatings.sort((a, b) {
      final dateA = a['watchedAt'] as Timestamp;
      final dateB = b['watchedAt'] as Timestamp;
      return dateB.compareTo(dateA);
    });

    if (mounted) {
      setState(() {
        _ratings = newRatings;
        _isLoading = false;
        _hasMore = newRatings.length >= _pageSize;
        if (newRatings.isNotEmpty) {
          _lastDocument = snapshot.docs.last;
        }
      });
    }
  }

  Future<List<String>> _getFollowingIds(String userId) async {
    if (_followingCache.containsKey(userId) &&
        _cacheTimestamps.containsKey(userId) &&
        DateTime.now().difference(_cacheTimestamps[userId]!) < _cacheExpiry) {
      return _followingCache[userId]!;
    }

    final followingIds = await _followService.getFollowingIdsOnce(userId);
    _followingCache[userId] = followingIds;
    _cacheTimestamps[userId] = DateTime.now();
    return followingIds;
  }

  Future<void> _loadFollowingRatings() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        setState(() {
          _isLoading = false;
          _ratings = [];
        });
        return;
      }

      final followingIds = await _getFollowingIds(currentUser.uid);
      if (followingIds.isEmpty) {
        setState(() {
          _isLoading = false;
          _ratings = [];
        });
        return;
      }

      // Get ratings from diary entries
      final diaryEntries =
          await _firestore
              .collection('diary_entries')
              .where('userId', whereIn: followingIds)
              .where('movieId', isEqualTo: widget.movieId)
              .orderBy('watchedDate', descending: true)
              .get();

      // Get direct ratings
      final directRatings =
          await _firestore
              .collection('movie_ratings')
              .where('userId', whereIn: followingIds)
              .where('movieId', isEqualTo: widget.movieId)
              .orderBy('updatedAt', descending: true)
              .get();

      // Map to store the latest rating for each user
      final Map<String, Map<String, dynamic>> userLatestRatings = {};

      // Process diary entries
      for (var doc in diaryEntries.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;

        // Only keep the latest rating for each user
        if (!userLatestRatings.containsKey(userId) ||
            (data['watchedDate'] as Timestamp).compareTo(
                  userLatestRatings[userId]!['watchedAt'] as Timestamp,
                ) >
                0) {
          userLatestRatings[userId] = {
            ...data,
            'source': 'diary',
            'watchedAt': data['watchedDate'],
          };
        }
      }

      // Process direct ratings
      for (var doc in directRatings.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final userId = data['userId'] as String;

        // Only keep the latest rating for each user
        if (!userLatestRatings.containsKey(userId) ||
            (data['updatedAt'] as Timestamp).compareTo(
                  userLatestRatings[userId]!['watchedAt'] as Timestamp,
                ) >
                0) {
          userLatestRatings[userId] = {
            ...data,
            'source': 'rating',
            'watchedAt': data['updatedAt'],
          };
        }
      }

      // Fetch user data and create final ratings list
      final List<Map<String, dynamic>> allRatings = [];
      for (var userId in userLatestRatings.keys) {
        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            allRatings.add({...userLatestRatings[userId]!, 'user': userData});
          }
        }
      }

      // Sort ratings by watched date
      allRatings.sort((a, b) {
        final dateA = a['watchedAt'] as Timestamp;
        final dateB = b['watchedAt'] as Timestamp;
        return dateB.compareTo(dateA);
      });

      if (mounted) {
        setState(() {
          _ratings = allRatings;
          _isLoading = false;
          _hasMore = allRatings.length >= _pageSize;
        });
      }

      await _cacheRatings();
    } catch (e) {
      debugPrint('Error loading following ratings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreRatings() async {
    if (!_hasMore || _lastDocument == null) return;

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final followingIds = await _getFollowingIds(currentUser.uid);
      if (followingIds.isEmpty) return;

      final query = _firestore
          .collection('movie_ratings')
          .where('movieId', isEqualTo: widget.movieId)
          .where('userId', whereIn: followingIds)
          .orderBy('createdAt', descending: true)
          .startAfterDocument(_lastDocument!)
          .limit(_pageSize);

      final snapshot = await query.get();
      if (snapshot.docs.isEmpty) {
        setState(() {
          _hasMore = false;
        });
        return;
      }

      _lastDocument = snapshot.docs.last;
      final newRatings = <Map<String, dynamic>>[];

      for (var doc in snapshot.docs) {
        final ratingData = doc.data();
        final userId = ratingData['userId'] as String;

        final userDoc = await _firestore.collection('users').doc(userId).get();
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            newRatings.add({...ratingData, 'user': userData});
          }
        }
      }

      if (mounted) {
        setState(() {
          _ratings.addAll(newRatings);
          _hasMore = snapshot.docs.length == _pageSize;
        });
      }
    } catch (e) {
      debugPrint('Error loading more ratings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ratings.isEmpty) {
      return Center(child: Text(_noRatingsText));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            _ratingsTitle,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: _ratings.length,
            itemBuilder:
                (context, index) => RatingAvatarCard(rating: _ratings[index]),
          ),
        ),
      ],
    );
  }
}
