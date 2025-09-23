import 'package:flutter/material.dart';
import '../services/follow_service.dart';
import '../services/follow_request_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FollowButton extends StatefulWidget {
  final String targetUserId;
  final bool isPrivate;

  const FollowButton({
    Key? key,
    required this.targetUserId,
    this.isPrivate = false,
  }) : super(key: key);

  @override
  State<FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<FollowButton> {
  final _followService = FollowService();
  final _followRequestService = FollowRequestService();
  final _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    // Don't show follow button for your own profile
    if (_auth.currentUser?.uid == widget.targetUserId) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: _followService.isFollowing(widget.targetUserId).asStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final isFollowing = snapshot.data ?? false;

        return _isLoading
            ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
            : ElevatedButton(
              onPressed:
                  _isLoading
                      ? null
                      : () async {
                        setState(() => _isLoading = true);
                        try {
                          if (isFollowing) {
                            await _followService.unfollowUser(
                              widget.targetUserId,
                            );
                          } else if (widget.isPrivate) {
                            await _followRequestService.sendFollowRequest(
                              requesterId: _auth.currentUser!.uid,
                              targetId: widget.targetUserId,
                            );
                          } else {
                            await _followService.followUser(
                              widget.targetUserId,
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isLoading = false);
                          }
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isFollowing
                        ? Colors.grey[300]
                        : Theme.of(context).primaryColor,
                foregroundColor: isFollowing ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                isFollowing
                    ? 'Following'
                    : widget.isPrivate
                    ? 'Request'
                    : 'Follow',
              ),
            );
      },
    );
  }
}
