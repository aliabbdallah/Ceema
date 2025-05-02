import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/conversation.dart';
import '../models/message.dart';

class DMService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get all conversations for the current user
  Stream<List<Conversation>> getConversations() {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('Error: No current user found');
      return Stream.value([]);
    }

    try {
      return _firestore
          .collection('conversations')
          .where('participants', arrayContains: currentUserId)
          .orderBy('lastMessageTime', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Conversation.fromMap(doc.data(), doc.id))
                .toList();
          });
    } catch (e) {
      print('Error fetching conversations: $e');
      return Stream.value([]);
    }
  }

  // Get messages for a specific conversation
  Stream<List<Message>> getMessages(String conversationId) {
    try {
      return _firestore
          .collection('messages')
          .where('conversationId', isEqualTo: conversationId)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snapshot) {
            return snapshot.docs
                .map((doc) => Message.fromFirestore(doc))
                .toList();
          });
    } catch (e) {
      print('Error fetching messages: $e');
      return Stream.value([]);
    }
  }

  // Send a new message
  Future<void> sendMessage(String conversationId, String content) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('Error: No current user found while sending message');
      return;
    }

    try {
      final message = Message(
        id: '', // Will be set by Firestore
        conversationId: conversationId,
        senderId: currentUserId,
        content: content,
        timestamp: DateTime.now(),
        isRead: false,
      );

      // Add message to messages collection
      await _firestore.collection('messages').add(message.toMap());

      // Update conversation's last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': content,
        'lastMessageTime': Timestamp.now(),
        'lastMessageSenderId': currentUserId,
        'isUnread': true,
      });
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  // Create a new conversation
  Future<String> createConversation(String otherUserId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      print('Error: No current user found while creating conversation');
      return '';
    }

    try {
      // Check if conversation already exists using a compound query
      final existingConversation =
          await _firestore
              .collection('conversations')
              .where('participants', arrayContains: currentUserId)
              .get();

      // Filter the results in memory to find the conversation with both participants
      for (var doc in existingConversation.docs) {
        final participants = List<String>.from(
          doc.data()['participants'] ?? [],
        );
        if (participants.contains(otherUserId)) {
          print('Found existing conversation: ${doc.id}');
          return doc.id;
        }
      }

      // Get user data for both participants
      final currentUserDoc =
          await _firestore.collection('users').doc(currentUserId).get();
      final otherUserDoc =
          await _firestore.collection('users').doc(otherUserId).get();

      final currentUserData =
          currentUserDoc.data() as Map<String, dynamic>? ?? {};
      final otherUserData = otherUserDoc.data() as Map<String, dynamic>? ?? {};

      // If no existing conversation found, create a new one
      final conversation = Conversation(
        id: '', // Will be set by Firestore
        participants: [currentUserId, otherUserId],
        lastMessage: '',
        lastMessageTime: DateTime.now(),
        isUnread: false,
        participantNames: {
          currentUserId: currentUserData['username'] ?? 'Unknown User',
          otherUserId: otherUserData['username'] ?? 'Unknown User',
        },
        participantAvatars: {
          currentUserId: currentUserData['profileImageUrl'] ?? '',
          otherUserId: otherUserData['profileImageUrl'] ?? '',
        },
      );

      final docRef = await _firestore
          .collection('conversations')
          .add(conversation.toMap());

      print('Created new conversation: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error creating conversation: $e');
      rethrow;
    }
  }

  // Mark conversation as read
  Future<void> markAsRead(String conversationId) async {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // Update conversation read status
      await _firestore.collection('conversations').doc(conversationId).update({
        'isUnread': false,
      });

      // Mark all unread messages as read
      final unreadMessages =
          await _firestore
              .collection('messages')
              .where('conversationId', isEqualTo: conversationId)
              .where('senderId', isNotEqualTo: currentUserId)
              .where('isRead', isEqualTo: false)
              .get();

      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking conversation as read: $e');
      rethrow;
    }
  }

  // Get user online status
  Stream<bool> getUserOnlineStatus(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((snapshot) => snapshot.data()?['isOnline'] ?? false);
  }

  Future<void> updateMessage(
    String conversationId,
    String messageId,
    String newContent,
  ) async {
    await _firestore.collection('messages').doc(messageId).update({
      'content': newContent,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteMessage(String conversationId, String messageId) async {
    await _firestore.collection('messages').doc(messageId).delete();
  }

  Future<void> setTypingStatus(
    String conversationId,
    String userId,
    bool isTyping,
  ) async {
    await _firestore.collection('conversations').doc(conversationId).update({
      'typingStatus.$userId': isTyping,
    });
  }

  Stream<Map<String, bool>> getTypingStatus(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .snapshots()
        .map(
          (doc) => Map<String, bool>.from(doc.data()?['typingStatus'] ?? {}),
        );
  }

  // Get unread message count for a conversation
  Stream<int> getUnreadMessageCount(String conversationId) {
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) {
      return Stream.value(0);
    }

    return _firestore
        .collection('messages')
        .where('conversationId', isEqualTo: conversationId)
        .where('senderId', isNotEqualTo: currentUserId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}
