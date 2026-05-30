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

String? _stringValue(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String? _conversationVendorId(Map<dynamic, dynamic> conversation) {
  final lastMessage = conversation['lastMessage'];
  final lastMessageMap = lastMessage is Map ? lastMessage : const <dynamic, dynamic>{};

  return _stringValue(conversation['vendorId']) ??
      _stringValue(conversation['shopId']) ??
      _stringValue(conversation['merchantId']) ??
      _stringValue(lastMessageMap['vendorId']) ??
      _stringValue(lastMessageMap['shopId']) ??
      _stringValue(lastMessageMap['merchantId']);
}

String? _conversationCustomerId(Map<dynamic, dynamic> conversation) {
  final lastMessage = conversation['lastMessage'];
  final lastMessageMap = lastMessage is Map ? lastMessage : const <dynamic, dynamic>{};

  return _stringValue(conversation['customerId']) ??
      _stringValue(conversation['userId']) ??
      _stringValue(lastMessageMap['customerId']) ??
      _stringValue(lastMessageMap['userId']);
}

bool _belongsToVendorConversation(
  Map<dynamic, dynamic> conversation, {
  required String vendorId,
  required String customerId,
}) {
  final scopedVendorId = _conversationVendorId(conversation);
  final scopedCustomerId = _conversationCustomerId(conversation);

  if (scopedVendorId != null && scopedVendorId != vendorId) return false;
  if (scopedCustomerId != null && scopedCustomerId != customerId) return false;

  return true;
}

final chatMessagesProvider = StreamProvider.autoDispose.family<List<ChatMessage>, String>((ref, userId) {
  final vendorId = ref.watch(vendorIdProvider);
  if (vendorId == null) return Stream.value([]);

  // Only load the latest 50 messages
  final dbRef = FirebaseDatabase.instance
      .ref('chats/$vendorId/$userId/messages')
      .orderByChild('timestamp')
      .limitToLast(50);

  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) return [];
    if (snapshot.value is! Map) return [];

    final messagesMap = snapshot.value as Map<dynamic, dynamic>;
    final List<ChatMessage> messages = [];
    messagesMap.forEach((key, value) {
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

  // Only fetch last 20 conversations, ordered by most recent message
  final dbRef = FirebaseDatabase.instance
      .ref('chats/$vendorId')
      .orderByChild('lastMessage/timestamp')
      .limitToLast(20);

  return dbRef.onValue.map((event) {
    final snapshot = event.snapshot;
    if (!snapshot.exists || snapshot.value == null) return [];
    if (snapshot.value is! Map) return [];

    final List<ChatSummary> summaries = [];
    final map = snapshot.value as Map<dynamic, dynamic>;
    map.forEach((userId, value) {
      if (value is Map && value.containsKey('lastMessage')) {
        final customerId = userId.toString();
        if (!_belongsToVendorConversation(
          value,
          vendorId: vendorId,
          customerId: customerId,
        )) {
          return;
        }

        final lastMsgValue = value['lastMessage'];
        if (lastMsgValue is! Map) return;

        final lastMsg = lastMsgValue;
        summaries.add(ChatSummary(
          userId: customerId,
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
    required String shopId,
    String? shopName,
    String? shopLogo,
  }) async {
    final vendorId = FirebaseAuth.instance.currentUser?.uid;
    if (vendorId == null || text.trim().isEmpty) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final messageData = {
      'senderId': vendorId,
      'receiverId': userId,
      'vendorId': vendorId,
      'customerId': userId,
      'shopId': shopId,
      'text': text.trim(),
      'timestamp': timestamp,
    };

    final messageRef = _rtdb.ref('chats/$vendorId/$userId/messages').push();
    final messageId = messageRef.key;

    if (messageId != null) {
      final vendorConversationUpdate = {
        'vendorId': vendorId,
        'customerId': userId,
        'shopId': shopId,
        'messages/$messageId': messageData,
        'lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'senderId': vendorId,
          'vendorId': vendorId,
          'customerId': userId,
          'shopId': shopId,
          'unread': false,
        },
      };

      final customerConversationUpdate = {
        'vendorId': vendorId,
        'customerId': userId,
        'shopId': shopId,
        'messages/$messageId': messageData,
        'lastMessage': {
          'text': text.trim(),
          'timestamp': timestamp,
          'senderId': vendorId,
          'vendorId': vendorId,
          'customerId': userId,
          'shopId': shopId,
          'unread': true, // User has not read it yet
        },
      };

      if (shopName != null && shopName.isNotEmpty) {
        customerConversationUpdate['shopName'] = shopName;
      }
      if (shopLogo != null && shopLogo.isNotEmpty) {
        customerConversationUpdate['shopLogo'] = shopLogo;
      }

      await Future.wait([
        _rtdb.ref('chats/$vendorId/$userId').update(vendorConversationUpdate),
        _rtdb.ref('chats/$userId/$vendorId').update(customerConversationUpdate),
      ]);
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
