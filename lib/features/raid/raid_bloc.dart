import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../raid_service.dart';

sealed class RaidEvent extends Equatable {
  const RaidEvent();

  @override
  List<Object> get props => <Object>[];
}

class RaidStarted extends RaidEvent {
  const RaidStarted();
}

class RaidJoinPressed extends RaidEvent {
  const RaidJoinPressed({required this.userId});

  final String userId;

  @override
  List<Object> get props => <Object>[userId];
}

enum RaidJoinStatus { idle, joining, joined, full, failure }

class RaidState extends Equatable {
  const RaidState({
    required this.status,
    required this.joinStatus,
    this.errorMessage,
  });

  const RaidState.initial()
    : status = const RaidStatus(slotsFilled: 0, maxSlots: 15),
      joinStatus = RaidJoinStatus.idle,
      errorMessage = null;

  final RaidStatus status;
  final RaidJoinStatus joinStatus;
  final String? errorMessage;

  RaidState copyWith({
    RaidStatus? status,
    RaidJoinStatus? joinStatus,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RaidState(
      status: status ?? this.status,
      joinStatus: joinStatus ?? this.joinStatus,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => <Object?>[status, joinStatus, errorMessage];
}

class RaidBloc extends Bloc<RaidEvent, RaidState> {
  RaidBloc({required RaidService raidService})
    : _raidService = raidService,
      super(const RaidState.initial()) {
    on<RaidStarted>(_onStarted, transformer: restartable());
    on<RaidJoinPressed>(_onJoinPressed, transformer: droppable());
  }

  final RaidService _raidService;

  Future<void> _onStarted(RaidStarted event, Emitter<RaidState> emit) async {
    await emit.forEach<RaidStatus>(
      _raidService.watchRaid(),
      onData: (RaidStatus status) {
        return state.copyWith(status: status, clearError: true);
      },
      onError: (Object error, StackTrace stackTrace) {
        return state.copyWith(
          joinStatus: RaidJoinStatus.failure,
          errorMessage: error.toString(),
        );
      },
    );
  }

  Future<void> _onJoinPressed(
    RaidJoinPressed event,
    Emitter<RaidState> emit,
  ) async {
    emit(state.copyWith(joinStatus: RaidJoinStatus.joining, clearError: true));

    try {
      final bool joined = await _raidService.joinRaid(userId: event.userId);
      emit(
        state.copyWith(
          joinStatus: joined ? RaidJoinStatus.joined : RaidJoinStatus.full,
          clearError: true,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          joinStatus: RaidJoinStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
