import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/user_profile_screen.dart';
import '../models/friend.dart';
import '../services/friend_service.dart';
import '../widgets/loading_indicator.dart';

class FriendsScreen extends StatefulWidget {
  final String userId;
  final int initialTabIndex;
  const FriendsScreen({
    Key? key,
    required this.userId,
    this.initialTabIndex = 0,
  }) : super(key: key);

  @override
  _FriendsScreenState createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final FriendService _friendService = FriendService();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildUserList(List<Friend> friends) {
    if (friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _tabController.index == 0
                  ? Icons.people_outline
                  : Icons.person_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _tabController.index == 0
                  ? 'Not following anyone yet'
                  : 'No followers yet',
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
      itemCount: friends.length,
      itemBuilder: (context, index) {
        final friend = friends[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: NetworkImage(friend.friendAvatar),
          ),
          title: Text(friend.friendName),
          trailing: friend.friendId != _auth.currentUser?.uid
              ? ElevatedButton(
                  onPressed: () async {
                    if (friend.isFollowing) {
                      await _friendService.unfollowUser(
                        _auth.currentUser!.uid,
                        friend.friendId,
                      );
                    } else {
                      await _friendService.followUser(
                        _auth.currentUser!.uid,
                        friend.friendId,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: friend.isFollowing
                        ? Colors.grey[200]
                        : Theme.of(context).primaryColor,
                    foregroundColor:
                        friend.isFollowing ? Colors.black : Colors.white,
                  ),
                  child: Text(friend.isFollowing ? 'Unfollow' : 'Follow'),
                )
              : null,
          subtitle: friend.isMutual ? const Text('Mutual Friend') : null,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserProfileScreen(
                  userId: friend.friendId,
                  username: friend.friendName,
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
        title: const Text('Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Following'),
            Tab(text: 'Followers'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Following Tab
          StreamBuilder<List<Friend>>(
            stream: _friendService.getFollowing(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const LoadingIndicator();
              }
              return _buildUserList(snapshot.data!);
            },
          ),
          // Followers Tab
          StreamBuilder<List<Friend>>(
            stream: _friendService.getFollowers(widget.userId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const LoadingIndicator();
              }
              return _buildUserList(snapshot.data!);
            },
          ),
        ],
      ),
    );
  }
}
