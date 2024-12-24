import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../models/friend_request.dart';
import '../services/friend_request_service.dart';
import '../services/friend_service.dart';

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
  bool _isLoading = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
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
            .where('username', isGreaterThanOrEqualTo: query)
            .where('username', isLessThanOrEqualTo: query + '\uf8ff')
            .get();

        final currentUserId = _auth.currentUser!.uid;
        final users = await Future.wait(
          querySnapshot.docs
              .where((doc) => doc.id != currentUserId)
              .map((doc) async {
            final userData = UserModel.fromJson(doc.data(), doc.id);
            // Check if already following
            final isFollowing =
                await _friendService.isFollowing(currentUserId, doc.id);
            // Check if friend request is pending
            final pendingRequest = await _requestService
                .getPendingRequests(doc.id)
                .first
                .then((requests) =>
                    requests.any((r) => r.senderId == currentUserId));

            return {
              'user': userData,
              'isFollowing': isFollowing,
              'hasPendingRequest': pendingRequest,
            };
          }),
        );

        if (mounted) {
          setState(() {
            _searchResults =
                users.map((data) => data['user'] as UserModel).toList();
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

  Widget _buildUserItem(UserModel user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: NetworkImage(
          user.profileImageUrl ??
              'https://ui-avatars.com/api/?name=${user.username}&background=1B2228&color=fff',
        ),
      ),
      title: Text(user.username),
      subtitle: Text(user.bio ?? ''),
      trailing: FutureBuilder<bool>(
        future: _friendService.isFollowing(_auth.currentUser!.uid, user.id),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox.shrink();
          }

          final isFollowing = snapshot.data!;
          if (isFollowing) {
            return ElevatedButton(
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
              ),
              child: const Text('Following'),
            );
          }

          return FutureBuilder<List<FriendRequest>>(
            future: _requestService.getPendingRequests(user.id).first,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox.shrink();
              }

              final hasPendingRequest = snapshot.data!
                  .any((request) => request.senderId == _auth.currentUser!.uid);

              if (hasPendingRequest) {
                return ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                  ),
                  child: const Text('Requested'),
                );
              }

              return ElevatedButton(
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
                        const SnackBar(content: Text('Friend request sent!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                },
                child: const Text('Follow'),
              );
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onChanged: _searchUsers,
            ),
          ),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_searchResults.isEmpty && _searchController.text.isNotEmpty)
            const Center(child: Text('No users found'))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) =>
                    _buildUserItem(_searchResults[index]),
              ),
            ),
        ],
      ),
    );
  }
}
