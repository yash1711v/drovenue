import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

class RaidStatus extends Equatable {
  const RaidStatus({required this.slotsFilled, required this.maxSlots});

  factory RaidStatus.fromMap(Map<String, dynamic>? data) {
    return RaidStatus(
      slotsFilled: _readInt(data?['slots_filled'], fallback: 0),
      maxSlots: _readInt(data?['max_slots'], fallback: defaultMaxSlots),
    );
  }

  static const int defaultMaxSlots = 15;

  final int slotsFilled;
  final int maxSlots;

  bool get isFull => slotsFilled >= maxSlots;

  @override
  List<Object> get props => <Object>[slotsFilled, maxSlots];
}

class RaidService {
  RaidService({required FirebaseFirestore firestore}) : _firestore = firestore;

  static const String eventCollection = 'events';
  static const String raidDocumentId = 'dragon_raid';

  final FirebaseFirestore _firestore;
  Future<void> _joinQueue = Future<void>.value();

  DocumentReference<Map<String, dynamic>> get _raidDocument => _firestore
      .collection(eventCollection)
      .doc(raidDocumentId)
      .withConverter<Map<String, dynamic>>(
        fromFirestore:
            (
              DocumentSnapshot<Map<String, dynamic>> snapshot,
              SnapshotOptions? options,
            ) {
              return snapshot.data() ?? <String, dynamic>{};
            },
        toFirestore: (Map<String, dynamic> value, SetOptions? options) {
          return value;
        },
      );

  Stream<RaidStatus> watchRaid() {
    return _raidDocument.snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      return RaidStatus.fromMap(snapshot.data());
    });
  }

  Future<bool> joinRaid({required String userId}) {
    final String normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty) {
      return Future<bool>.value(false);
    }

    return _enqueue<bool>(() => _joinRaidTransaction(userId: normalizedUserId));
  }

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final Future<T> result = _joinQueue.then<T>((_) => operation());
    _joinQueue = result.then<void>(
      (T _) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return result;
  }

  Future<bool> _joinRaidTransaction({required String userId}) async {
    final DocumentReference<Map<String, dynamic>> raidDocument = _raidDocument;

    return _firestore.runTransaction<bool>((Transaction transaction) async {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await transaction
          .get<Map<String, dynamic>>(raidDocument);
      final Map<String, dynamic>? data = snapshot.data();
      final int slotsFilled = _readInt(data?['slots_filled'], fallback: 0);
      final int maxSlots = _readInt(
        data?['max_slots'],
        fallback: RaidStatus.defaultMaxSlots,
      );

      if (slotsFilled >= maxSlots) {
        return false;
      }

      final Map<String, Object> nextData = <String, Object>{
        'slots_filled': slotsFilled + 1,
        'max_slots': maxSlots,
        'last_joined_user_id': userId,
      };

      if (snapshot.exists) {
        transaction.update(raidDocument, nextData);
      } else {
        transaction.set<Map<String, dynamic>>(raidDocument, <String, dynamic>{
          ...nextData,
        });
      }

      return true;
    });
  }
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return fallback;
}
