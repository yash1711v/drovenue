import 'package:aether_project/features/world_event/world_event_bloc.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorldEventBloc', () {
    blocTest<WorldEventBloc, WorldEventState>(
      'accepts 100ms tick updates without widget state',
      build: WorldEventBloc.new,
      act: (WorldEventBloc bloc) {
        bloc.add(const WorldEventTicked(Duration(milliseconds: 900)));
      },
      expect: () {
        return <WorldEventState>[
          const WorldEventState(
            remaining: Duration(milliseconds: 900),
            isRunning: true,
          ),
        ];
      },
    );
  });
}
