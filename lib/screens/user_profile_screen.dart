import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user.dart';
import '../services/profile_service.dart';
import '../services/friend_service.dart';
import '../services/friend_request_service.dart';
import '../models/friend_request.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../widgets/loading_indicator.dart';
import 'settings_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String username;

  const UserProfileScreen({
    Key? key,
    required this.userId,
    required this.username,
  }) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _auth = FirebaseAuth.instance;
  final _profileService = ProfileService();
  final _friendService = FriendService();
  final _requestService = FriendRequestService();
  final _postService = PostService();

  bool _isLoadingFriendship = false;
  String? _errorMessage;

  Future<bool> _checkFriendshipStatus() async {
    try {
      print(
          'Checking friendship status between ${_auth.currentUser!.uid} and ${widget.userId}');
      return await _friendService.isFollowing(
        _auth.currentUser!.uid,
        widget.userId,
      );
    } catch (e) {
      print('Error checking friendship status: $e');
      return false;
    }
  }

  Future<FriendRequest?> _checkPendingRequest() async {
    try {
      print('Checking pending requests for user ${widget.userId}');
      final requests =
          await _requestService.getPendingRequests(widget.userId).first;
      return requests.firstWhere(
        (request) => request.senderId == _auth.currentUser!.uid,
        orElse: () => null as FriendRequest,
      );
    } catch (e) {
      print('Error checking pending request: $e');
      return null;
    }
  }

  Widget _buildFriendshipButton() {
    if (_auth.currentUser!.uid == widget.userId) {
      return Container();
    }

    return FutureBuilder<bool>(
      future: _checkFriendshipStatus(),
      builder: (context, friendshipSnapshot) {
        if (!friendshipSnapshot.hasData) {
          return const SizedBox(
            height: 36,
            width: 36,
            child: CircularProgressIndicator(),
          );
        }

        if (friendshipSnapshot.data!) {
          return ElevatedButton.icon(
            icon: const Icon(Icons.check),
            label: const Text('Following'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.black,
            ),
            onPressed: _isLoadingFriendship
                ? null
                : () async {
                    setState(() {
                      _isLoadingFriendship = true;
                      _errorMessage = null;
                    });

                    try {
                      await _friendService.unfollowUser(
                        _auth.currentUser!.uid,
                        widget.userId,
                      );
                    } catch (e) {
                      setState(() {
                        _errorMessage = 'Failed to unfollow: $e';
                      });
                    } finally {
                      if (mounted) {
                        setState(() {
                          _isLoadingFriendship = false;
                        });
                      }
                    }
                  },
          );
        }

        return FutureBuilder<FriendRequest?>(
          future: _checkPendingRequest(),
          builder: (context, requestSnapshot) {
            if (!requestSnapshot.hasData) {
              return const SizedBox(
                height: 36,
                width: 36,
                child: CircularProgressIndicator(),
              );
            }

            if (requestSnapshot.data != null) {
              return ElevatedButton.icon(
                icon: const Icon(Icons.hourglass_empty),
                label: const Text('Request Sent'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[300],
                  foregroundColor: Colors.black,
                ),
                onPressed: _isLoadingFriendship
                    ? null
                    : () async {
                        setState(() {
                          _isLoadingFriendship = true;
                          _errorMessage = null;
                        });

                        try {
                          await _requestService.cancelFriendRequest(
                            requestSnapshot.data!.id,
                          );
                        } catch (e) {
                          setState(() {
                            _errorMessage = 'Failed to cancel request: $e';
                          });
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isLoadingFriendship = false;
                            });
                          }
                        }
                      },
              );
            }

            return ElevatedButton.icon(
              icon: const Icon(Icons.person_add),
              label: const Text('Follow'),
              onPressed: _isLoadingFriendship
                  ? null
                  : () async {
                      setState(() {
                        _isLoadingFriendship = true;
                        _errorMessage = null;
                      });

                      try {
                        final currentUser = _auth.currentUser!;
                        await _requestService.sendFriendRequest(
                          senderId: currentUser.uid,
                          senderName: currentUser.displayName ?? '',
                          senderAvatar: currentUser.photoURL ?? '',
                          receiverId: widget.userId,
                          receiverName: widget.username,
                          receiverAvatar:
                              '', // Will be updated from user profile
                        );

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Friend request sent!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          _errorMessage = 'Failed to send request: $e';
                        });
                      } finally {
                        if (mounted) {
                          setState(() {
                            _isLoadingFriendship = false;
                          });
                        }
                      }
                    },
            );
          },
        );
      },
    );
  }

  Widget _buildUserStats(UserModel user) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem('Following', user.followingCount),
        _buildStatItem('Followers', user.followersCount),
        _buildStatItem('Movies', 0), // TODO: Add movie count tracking
      ],
    );
  }

  Widget _buildStatItem(String label, int value) {
    return Column(
      children: [
        Text(
          value.toString(),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildPostsList() {
    return StreamBuilder<List<Post>>(
      stream: _postService.getUserPosts(widget.userId),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          print('Error loading posts: ${snapshot.error}');
          return Center(
            child: Text('Error loading posts: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final posts = snapshot.data!;

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.movie_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No posts yet',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            post.moviePosterUrl,
                            width: 40,
                            height: 60,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              print('Error loading movie poster: $error');
                              return Container(
                                width: 40,
                                height: 60,
                                color: Colors.grey[300],
                                child: const Icon(Icons.movie),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                post.movieTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (post.movieYear.isNotEmpty)
                                Text(
                                  post.movieYear,
                                  style: const TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (post.rating > 0) ...[
                      Row(
                        children: List.generate(5, (index) {
                          return Icon(
                            index < post.rating
                                ? Icons.star
                                : Icons.star_border,
                            color: Colors.amber,
                            size: 16,
                          );
                        }),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(post.content),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 16,
                          color: post.likes.contains(_auth.currentUser?.uid)
                              ? Colors.red
                              : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(post.likes.length.toString()),
                        const SizedBox(width: 16),
                        const Icon(
                          Icons.comment_outlined,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(post.commentCount.toString()),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username),
        actions: [
          if (_auth.currentUser?.uid == widget.userId)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<UserModel>(
        stream: _profileService.getUserProfileStream(widget.userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            print('Error loading profile: ${snapshot.error}');
            return Center(
                child: Text('Error loading profile: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const LoadingIndicator(message: 'Loading profile...');
          }

          final user = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {});
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.all(8),
                      color: Colors.red[100],
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: NetworkImage(
                            user.profileImageUrl ??
                                'https://ui-avatars.com/api/?name=${user.username}',
                          ),
                          onBackgroundImageError: (error, stackTrace) {
                            print('Error loading profile image: $error');
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (user.bio != null && user.bio!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            user.bio!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildFriendshipButton(),
                        const SizedBox(height: 16),
                        _buildUserStats(user),
                      ],
                    ),
                  ),
                  const Divider(),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Text(
                          'Posts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Movie Reviews',
                          style: TextStyle(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildPostsList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
