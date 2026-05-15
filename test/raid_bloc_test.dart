import 'package:aether_project/features/raid/raid_bloc.dart';
import 'package:aether_project/raid_service.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RaidBloc', () {
    late FakeFirebaseFirestore firestore;
    late RaidService service;

    setUp(() async {
      firestore = FakeFirebaseFirestore();
      service = RaidService(firestore: firestore);
      await firestore.collection('events').doc('dragon_raid').set(
        <String, Object>{'slots_filled': 0, 'max_slots': 15},
      );
    });

    blocTest<RaidBloc, RaidState>(
      'emits joining then joined when a slot is available',
      build: () => RaidBloc(raidService: service),
      act: (RaidBloc bloc) {
        bloc.add(const RaidJoinPressed(userId: 'bloc_user'));
      },
      expect: () {
        return <Matcher>[
          isA<RaidState>().having(
            (RaidState state) => state.joinStatus,
            'joinStatus',
            RaidJoinStatus.joining,
          ),
          isA<RaidState>().having(
            (RaidState state) => state.joinStatus,
            'joinStatus',
            RaidJoinStatus.joined,
          ),
        ];
      },
    );
  });
}
