import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class ChatMessage extends Equatable {
  const ChatMessage({
    required this.id,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.snapshot,
  });

  factory ChatMessage.fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
    return ChatMessage(
      id: snapshot.id,
      userId: _readString(data['user_id'], fallback: 'unknown'),
      body: _readString(data['body'], fallback: ''),
      createdAt: _readDateTime(data['created_at']),
      snapshot: snapshot,
    );
  }

  final String id;
  final String userId;
  final String body;
  final DateTime createdAt;
  final DocumentSnapshot<Map<String, dynamic>>? snapshot;

  @override
  List<Object> get props => <Object>[id, userId, body, createdAt];
}

class ChatPage {
  const ChatPage({required this.messages, required this.hasMore});

  final List<ChatMessage> messages;
  final bool hasMore;
}

abstract interface class ChatRepository {
  Stream<List<ChatMessage>> watchLatestMessages({int limit = 30});

  Future<ChatPage> fetchOlderMessages({
    required DocumentSnapshot<Map<String, dynamic>> startAfter,
    int limit = 30,
  });

  Future<void> sendMessage({required String userId, required String body});
}

class FirestoreChatRepository implements ChatRepository {
  FirestoreChatRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _messages =>
      _firestore.collection('chat_rooms').doc('global').collection('messages');

  Query<Map<String, dynamic>> get _latestQuery {
    return _messages.orderBy('created_at', descending: true);
  }

  @override
  Stream<List<ChatMessage>> watchLatestMessages({int limit = 30}) {
    return _latestQuery.limit(limit).snapshots().map((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) {
      return _ascendingMessages(snapshot.docs);
    });
  }

  @override
  Future<ChatPage> fetchOlderMessages({
    required DocumentSnapshot<Map<String, dynamic>> startAfter,
    int limit = 30,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _latestQuery
        .startAfterDocument(startAfter)
        .limit(limit)
        .get();
    return ChatPage(
      messages: _ascendingMessages(snapshot.docs),
      hasMore: snapshot.docs.length == limit,
    );
  }

  @override
  Future<void> sendMessage({
    required String userId,
    required String body,
  }) async {
    final String trimmedBody = body.trim();
    if (trimmedBody.isEmpty) {
      return;
    }

    await _messages.add(<String, Object>{
      'user_id': userId,
      'body': trimmedBody,
      'created_at': Timestamp.now(),
    });
  }
}

List<ChatMessage> _ascendingMessages(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  return docs
      .map<ChatMessage>(ChatMessage.fromSnapshot)
      .toList(growable: false)
      .reversed
      .toList(growable: false);
}

String _readString(Object? value, {required String fallback}) {
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  return fallback;
}

DateTime _readDateTime(Object? value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
