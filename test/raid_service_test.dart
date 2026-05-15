import 'package:drovenue/raid_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RaidService', () {
    late FakeFirebaseFirestore firestore;
    late RaidService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = RaidService(firestore: firestore);
      await firestore.collection('events').doc('dragon_raid').set(
        <String, Object>{'slots_filled': 14, 'max_slots': 15},
      );
    });

    test('joins when capacity remains', () async {
      final bool joined = await service.joinRaid(userId: 'player_one');

      final Map<String, dynamic>? data =
          (await firestore.collection('events').doc('dragon_raid').get())
              .data();

      expect(joined, isTrue);
      expect(data?['slots_filled'], 15);
      expect(data?['last_joined_user_id'], 'player_one');
    });

    test('fails gracefully when the raid is full', () async {
      await firestore.collection('events').doc('dragon_raid').update(
        <String, Object>{'slots_filled': 15},
      );

      final bool joined = await service.joinRaid(userId: 'player_two');

      final Map<String, dynamic>? data =
          (await firestore.collection('events').doc('dragon_raid').get())
              .data();

      expect(joined, isFalse);
      expect(data?['slots_filled'], 15);
    });
  });
}
