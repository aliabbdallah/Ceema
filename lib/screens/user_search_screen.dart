import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../models/friend_request.dart';
import '../services/friend_request_service.dart';
import '../services/friend_service.dart';
import '../screens/user_profile_screen.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({Key? key}) : super(key: key);

  @override
  _UserSearchScreenState createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FriendRequestService _requestService = FriendRequestService();
  final FriendService _friendService = FriendService();

  List<UserModel> _searchResults = [];
  List<UserModel> _recentSearches = [];
  List<UserModel> _suggestedUsers = [];
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadSuggestedUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final searches = await _firestore
          .collection('userSearches')
          .doc(currentUserId)
          .collection('recent')
          .orderBy('timestamp', descending: true)
          .limit(5)
          .get();

      if (mounted) {
        setState(() {
          _recentSearches = searches.docs
              .map((doc) {
                final data = doc.data();
                if (data.containsKey('userId')) {
                  return UserModel(
                    id: data['userId'],
                    username: data['username'] ?? '',
                    profileImageUrl: data['profileImageUrl'],
                    bio: data['bio'],
                    email: '',
                    favoriteGenres: [],
                    createdAt: DateTime.now(),
                  );
                }
                return null;
              })
              .where((user) => user != null)
              .cast<UserModel>()
              .toList();
        });
      }
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _loadSuggestedUsers() async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Get a list of users the current user is following
      final followingList =
          await _friendService.getFollowing(currentUserId).first;
      final followingIds = followingList.map((user) => user.id).toList();

      // Get users with most followers, excluding those the user already follows
      final suggestedUserDocs = await _firestore
          .collection('users')
          .orderBy('followerCount', descending: true)
          .limit(10)
          .get();

      final suggestions = suggestedUserDocs.docs
          .map((doc) => UserModel.fromJson(doc.data(), doc.id))
          .where((user) =>
              user.id != currentUserId && !followingIds.contains(user.id))
          .take(5)
          .toList();

      if (mounted) {
        setState(() {
          _suggestedUsers = suggestions;
        });
      }
    } catch (e) {
      print('Error loading suggested users: $e');
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      setState(() => _isLoading = true);

      try {
        // Search for users where username contains the query (case-insensitive)
        final querySnapshot = await _firestore
            .collection('users')
            .where('username', isGreaterThanOrEqualTo: query.toLowerCase())
            .where('username',
                isLessThanOrEqualTo: query.toLowerCase() + '\uf8ff')
            .get();

        // Also search for displayName
        final nameQuerySnapshot = await _firestore
            .collection('users')
            .where('displayName', isGreaterThanOrEqualTo: query)
            .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        // Combine results (avoiding duplicates)
        final Set<String> userIds = {};
        final List<UserModel> users = [];

        for (final doc in [...querySnapshot.docs, ...nameQuerySnapshot.docs]) {
          if (!userIds.contains(doc.id) && doc.id != _auth.currentUser!.uid) {
            userIds.add(doc.id);
            users.add(UserModel.fromJson(doc.data(), doc.id));
          }
        }

        if (mounted) {
          setState(() {
            _searchResults = users;
            _isLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error searching users: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    });
  }

  Future<void> _saveSearchHistory(UserModel user) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      await _firestore
          .collection('userSearches')
          .doc(currentUserId)
          .collection('recent')
          .doc(user.id)
          .set({
        'userId': user.id,
        'username': user.username,
        'profileImageUrl': user.profileImageUrl,
        'bio': user.bio,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving search history: $e');
    }
  }

  void _navigateToUserProfile(UserModel user) {
    _saveSearchHistory(user);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UserProfileScreen(
          userId: user.id,
          username: user.username,
        ),
      ),
    );
  }

  Widget _buildUserItem(UserModel user,
      {bool isRecent = false, bool isSuggested = false}) {
    return FutureBuilder<bool>(
      future: _friendService.isFollowing(_auth.currentUser!.uid, user.id),
      builder: (context, isFollowingSnapshot) {
        return FutureBuilder<List<FriendRequest>>(
          future: _requestService.getPendingRequests(user.id).first,
          builder: (context, requestsSnapshot) {
            final isFollowing = isFollowingSnapshot.data ?? false;
            final hasPendingRequest = requestsSnapshot.data?.any(
                  (request) => request.senderId == _auth.currentUser!.uid,
                ) ??
                false;

            return ListTile(
              leading: GestureDetector(
                onTap: () => _navigateToUserProfile(user),
                child: CircleAvatar(
                  radius: 24,
                  backgroundImage: NetworkImage(
                    user.profileImageUrl ??
                        'https://ui-avatars.com/api/?name=${user.username}&background=1B2228&color=fff',
                  ),
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _navigateToUserProfile(user),
                      child: Text(
                        user.username,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (isRecent)
                    IconButton(
                      icon: const Icon(Icons.history, size: 16),
                      onPressed: () {
                        // Show option to remove from history
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Remove from search history?'),
                            action: SnackBarAction(
                              label: 'REMOVE',
                              onPressed: () async {
                                try {
                                  await _firestore
                                      .collection('userSearches')
                                      .doc(_auth.currentUser!.uid)
                                      .collection('recent')
                                      .doc(user.id)
                                      .delete();
                                  _loadRecentSearches();
                                } catch (e) {
                                  print('Error removing search history: $e');
                                }
                              },
                            ),
                          ),
                        );
                      },
                      color: Colors.grey,
                      tooltip: 'Recent search',
                    ),
                ],
              ),
              subtitle: user.bio != null && user.bio!.isNotEmpty
                  ? Text(
                      user.bio!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                  : null,
              trailing: isFollowing
                  ? ElevatedButton(
                      onPressed: () async {
                        try {
                          await _friendService.unfollowUser(
                            _auth.currentUser!.uid,
                            user.id,
                          );
                          setState(() {}); // Refresh UI
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[300],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: const Size(0, 36),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      child: const Text('Following'),
                    )
                  : hasPendingRequest
                      ? OutlinedButton(
                          onPressed: null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 36),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.normal),
                          ),
                          child: const Text('Requested'),
                        )
                      : ElevatedButton(
                          onPressed: () async {
                            try {
                              final currentUser = _auth.currentUser!;
                              await _requestService.sendFriendRequest(
                                senderId: currentUser.uid,
                                senderName: currentUser.displayName ?? '',
                                senderAvatar: currentUser.photoURL ?? '',
                                receiverId: user.id,
                                receiverName: user.username,
                                receiverAvatar: user.profileImageUrl ?? '',
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Friend request sent!')),
                                );
                                setState(() {}); // Refresh UI
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            minimumSize: const Size(0, 36),
                            textStyle:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          child: const Text('Follow'),
                        ),
              onTap: () => _navigateToUserProfile(user),
            );
          },
        );
      },
    );
  }

  Widget _buildRecentSearches() {
    if (_recentSearches.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Searches',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              TextButton(
                onPressed: () async {
                  try {
                    await _firestore
                        .collection('userSearches')
                        .doc(_auth.currentUser!.uid)
                        .collection('recent')
                        .get()
                        .then((snapshot) {
                      for (final doc in snapshot.docs) {
                        doc.reference.delete();
                      }
                    });
                    setState(() {
                      _recentSearches = [];
                    });
                  } catch (e) {
                    print('Error clearing search history: $e');
                  }
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
        ),
        ..._recentSearches.map((user) => _buildUserItem(user, isRecent: true)),
      ],
    );
  }

  Widget _buildSuggestedUsers() {
    if (_suggestedUsers.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Suggested Users',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        ..._suggestedUsers
            .map((user) => _buildUserItem(user, isSuggested: true)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool hasResults = _searchResults.isNotEmpty;
    final bool isSearchActive = _searchController.text.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search users...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: colorScheme.onSurface.withOpacity(0.6)),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _searchResults = [];
                      });
                    },
                  )
                : null,
          ),
          onChanged: _searchUsers,
          textInputAction: TextInputAction.search,
          style: TextStyle(color: colorScheme.onSurface),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasResults
              ? ListView.builder(
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) =>
                      _buildUserItem(_searchResults[index]),
                )
              : isSearchActive
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: colorScheme.onSurface.withOpacity(0.4),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(
                              color: colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildRecentSearches(),
                          _buildSuggestedUsers(),
                          if (_recentSearches.isEmpty &&
                              _suggestedUsers.isEmpty)
                            Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.people_outline,
                                      size: 64,
                                      color: colorScheme.onSurface
                                          .withOpacity(0.4),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Find Friends',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Search for users to follow and connect with',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
    );
  }
}
