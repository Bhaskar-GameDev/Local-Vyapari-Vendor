import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_provider.dart';

final vendorIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.value?.uid ?? FirebaseAuth.instance.currentUser?.uid;
});

class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromRTDB(String id, Map<dynamic, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: map['senderId']?.toString() ?? '',
      text: map['text']?.toString() ?? '',
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] is int ? (map['timestamp'] as int) : 0,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }
}

class ChatSummary {
  final String userId;
  final String userName;
  final String lastMessageText;
  final DateTime timestamp;
  final bool unread;

  ChatSummary({
    required this.userId,
    required this.userName,
    required this.lastMessageText,
    required this.timestamp,
    required this.unread,
  });
}

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, userId) {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return Stream.value([]);

  final dbRef = FirebaseDatabase.instance.ref('chats/$vendorId/$userId/messages');
  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) return [];

    final List<ChatMessage> messages = [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    map.forEach((key, value) {
      if (value is Map) {
        messages.add(ChatMessage.fromRTDB(key.toString(), value));
      }
    });

    messages.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return messages;
  });
});

final vendorChatsProvider = StreamProvider.autoDispose<List<ChatSummary>>((ref) {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return Stream.value([]);

  final dbRef = FirebaseDatabase.instance.ref('chats/$vendorId');
  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) return [];

    final List<ChatSummary> summaries = [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    map.forEach((userId, value) {
      if (value is Map && value.containsKey('lastMessage')) {
        final lastMsg = value['lastMessage'] as Map;
        summaries.add(ChatSummary(
          userId: userId.toString(),
          userName: value['userName']?.toString() ?? 'Customer',
          lastMessageText: lastMsg['text']?.toString() ?? '',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            lastMsg['timestamp'] is int ? (lastMsg['timestamp'] as int) : 0,
          ),
          unread: lastMsg['unread'] == true,
        ));
      }
    });

    // Sort by most recent message first
    summaries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return summaries;
  });
});

final chatServiceProvider = Provider((ref) => ChatService());

class ChatService {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  Future<void> sendVendorMessage({
    required String userId,
    required String text,
    String? shopName,
    String? shopLogo,
  }) async {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null || text.trim().isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final messageData = {
      'senderId': vendorId,
      'text': text.trim(),
      'timestamp': timestamp,
    };

    final messageRef = _rtdb.ref('chats/$vendorId/$userId/messages').push();
    final messageId = messageRef.key;

    if (messageId != null) {
      final Map<String, dynamic> updates = {
        'chats/$vendorId/$userId/messages/$messageId': messageData,
        'chats/$userId/$vendorId/messages/$messageId': messageData,
        'chats/$vendorId/$userId/lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'unread': false,
        },
        'chats/$userId/$vendorId/lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'unread': true, // User has not read it yet
        }
      };

      if (shopName != null && shopName.isNotEmpty) {
        updates['chats/$userId/$vendorId/shopName'] = shopName;
      }
      if (shopLogo != null && shopLogo.isNotEmpty) {
        updates['chats/$userId/$vendorId/shopLogo'] = shopLogo;
      }

      await _rtdb.ref().update(updates);
    }
  }

  Future<void> markAsRead(String userId) async {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return;
    try {
      await _rtdb.ref('chats/$vendorId/$userId/lastMessage/unread').set(false);
    } catch (e) {
      // Ignore/log
    }
  }

  Future<void> deleteChat(String userId) async {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null) return;
    try {
      await _rtdb.ref('chats/$vendorId/$userId').remove();
    } catch (e) {
      // Ignore/log
    }
  }
}
