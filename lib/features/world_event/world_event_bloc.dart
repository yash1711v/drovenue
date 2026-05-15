import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

sealed class WorldEventEvent extends Equatable {
  const WorldEventEvent();

  @override
  List<Object> get props => <Object>[];
}

class WorldEventStarted extends WorldEventEvent {
  const WorldEventStarted({this.duration = const Duration(minutes: 10)});

  final Duration duration;

  @override
  List<Object> get props => <Object>[duration];
}

class WorldEventTicked extends WorldEventEvent {
  const WorldEventTicked(this.remaining);

  final Duration remaining;

  @override
  List<Object> get props => <Object>[remaining];
}

class WorldEventReset extends WorldEventEvent {
  const WorldEventReset();
}

class WorldEventState extends Equatable {
  const WorldEventState({required this.remaining, required this.isRunning});

  const WorldEventState.initial()
    : remaining = const Duration(minutes: 10),
      isRunning = false;

  final Duration remaining;
  final bool isRunning;

  WorldEventState copyWith({Duration? remaining, bool? isRunning}) {
    return WorldEventState(
      remaining: remaining ?? this.remaining,
      isRunning: isRunning ?? this.isRunning,
    );
  }

  @override
  List<Object> get props => <Object>[remaining, isRunning];
}

class WorldEventBloc extends Bloc<WorldEventEvent, WorldEventState> {
  WorldEventBloc({
    DateTime Function()? clock,
    Duration tickInterval = const Duration(milliseconds: 100),
  }) : _clock = clock ?? DateTime.now,
       _tickInterval = tickInterval,
       super(const WorldEventState.initial()) {
    on<WorldEventStarted>(_onStarted);
    on<WorldEventTicked>(_onTicked);
    on<WorldEventReset>(_onReset);
  }

  final DateTime Function() _clock;
  final Duration _tickInterval;
  Timer? _timer;
  DateTime? _endsAt;

  void _onStarted(WorldEventStarted event, Emitter<WorldEventState> emit) {
    _timer?.cancel();
    _endsAt = _clock().add(event.duration);
    emit(WorldEventState(remaining: event.duration, isRunning: true));
    _timer = Timer.periodic(_tickInterval, (Timer timer) {
      final DateTime? endsAt = _endsAt;
      if (endsAt == null) {
        timer.cancel();
        return;
      }

      final Duration remaining = endsAt.difference(_clock());
      final Duration nextRemaining = remaining.isNegative
          ? Duration.zero
          : remaining;
      add(WorldEventTicked(nextRemaining));
      if (nextRemaining == Duration.zero) {
        timer.cancel();
      }
    });
  }

  void _onTicked(WorldEventTicked event, Emitter<WorldEventState> emit) {
    emit(
      state.copyWith(
        remaining: event.remaining,
        isRunning: event.remaining > Duration.zero,
      ),
    );
  }

  void _onReset(WorldEventReset event, Emitter<WorldEventState> emit) {
    _timer?.cancel();
    _endsAt = null;
    emit(const WorldEventState.initial());
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
