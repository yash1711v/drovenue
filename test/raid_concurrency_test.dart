import 'package:drovenue/raid_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Aether Raid Concurrency Integrity', () {
    late FakeFirebaseFirestore fakeFirestore;
    late RaidService raidService;

    setUp(() async {
      fakeFirestore = FakeFirebaseFirestore();
      raidService = RaidService(firestore: fakeFirestore);

      await fakeFirestore.collection('events').doc('dragon_raid').set(
        <String, Object>{'slots_filled': 0, 'max_slots': 15},
      );
    });

    test(
      'Thundering Herd: 50 simultaneous join requests strictly cap at 15',
      () async {
        final List<Future<bool>> joinRequests = <Future<bool>>[];

        for (int index = 0; index < 50; index += 1) {
          joinRequests.add(raidService.joinRaid(userId: 'user_$index'));
        }

        final List<bool> results = await Future.wait(joinRequests);
        final int successfulJoins = results
            .where((bool result) => result)
            .length;

        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await fakeFirestore.collection('events').doc('dragon_raid').get();
        final Object? slotsFilled = snapshot.data()?['slots_filled'];

        expect(
          successfulJoins,
          15,
          reason: 'Exactly 15 requests should report success.',
        );
        expect(
          slotsFilled,
          15,
          reason: 'The database must record exactly 15 filled slots.',
        );
      },
    );
  });
}
