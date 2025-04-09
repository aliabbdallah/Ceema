import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/follow_request_service.dart';
import '../widgets/user_list_item.dart';
import '../models/follow_request.dart';

class FollowRequestsScreen extends StatefulWidget {
  const FollowRequestsScreen({Key? key}) : super(key: key);

  @override
  State<FollowRequestsScreen> createState() => _FollowRequestsScreenState();
}

class _FollowRequestsScreenState extends State<FollowRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FollowRequestService _followRequestService = FollowRequestService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Follow Requests'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Incoming'), Tab(text: 'Sent')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildIncomingRequests(), _buildSentRequests()],
      ),
    );
  }

  Widget _buildIncomingRequests() {
    return StreamBuilder<List<FollowRequest>>(
      stream: _followRequestService.getPendingRequests(_auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return const Center(child: Text('No incoming requests'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage:
                    request.requesterAvatar.isNotEmpty
                        ? NetworkImage(request.requesterAvatar)
                        : null,
                child:
                    request.requesterAvatar.isEmpty
                        ? Text(request.requesterName[0].toUpperCase())
                        : null,
              ),
              title: Text(request.requesterName),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () async {
                      await _followRequestService.acceptFollowRequest(
                        request.id,
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () async {
                      await _followRequestService.declineFollowRequest(
                        request.id,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSentRequests() {
    return StreamBuilder<List<FollowRequest>>(
      stream: _followRequestService.getSentRequests(_auth.currentUser!.uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return const Center(child: Text('No sent requests'));
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return UserListItem(
              userId: request.targetId,
              userName: request.targetName,
              userPhotoUrl: request.targetAvatar,
              showFollowButton: false,
            );
          },
        );
      },
    );
  }
}
