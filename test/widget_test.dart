import 'package:aether_project/features/chat/chat_repository.dart';
import 'package:aether_project/main.dart';
import 'package:aether_project/raid_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the Project Aether dashboard', (
    WidgetTester tester,
  ) async {
    final FakeFirebaseFirestore firestore = FakeFirebaseFirestore();
    await firestore.collection('events').doc('dragon_raid').set(
      <String, Object>{'slots_filled': 0, 'max_slots': 15},
    );

    await tester.pumpWidget(
      AetherApp(
        raidService: RaidService(firestore: firestore),
        chatRepository: FirestoreChatRepository(firestore: firestore),
      ),
    );
    await tester.pump();

    expect(find.text('Project Aether'), findsOneWidget);
    expect(find.text('Global Pulse'), findsOneWidget);
    expect(find.text('Geo-Raid'), findsOneWidget);
    expect(find.text('Engagement Chat'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
