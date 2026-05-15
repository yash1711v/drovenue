import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'chat_repository.dart';

sealed class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object> get props => <Object>[];
}

class ChatStarted extends ChatEvent {
  const ChatStarted();
}

class ChatOlderRequested extends ChatEvent {
  const ChatOlderRequested();
}

class ChatMessageSubmitted extends ChatEvent {
  const ChatMessageSubmitted({required this.userId, required this.body});

  final String userId;
  final String body;

  @override
  List<Object> get props => <Object>[userId, body];
}

enum ChatConnectionStatus { initial, loading, live, failure }

class ChatState extends Equatable {
  const ChatState({
    required this.latestMessages,
    required this.olderMessages,
    required this.connectionStatus,
    required this.isLoadingOlder,
    required this.hasMoreOlder,
    this.errorMessage,
  });

  const ChatState.initial()
    : latestMessages = const <ChatMessage>[],
      olderMessages = const <ChatMessage>[],
      connectionStatus = ChatConnectionStatus.initial,
      isLoadingOlder = false,
      hasMoreOlder = true,
      errorMessage = null;

  final List<ChatMessage> latestMessages;
  final List<ChatMessage> olderMessages;
  final ChatConnectionStatus connectionStatus;
  final bool isLoadingOlder;
  final bool hasMoreOlder;
  final String? errorMessage;

  List<ChatMessage> get messages {
    return <ChatMessage>[...olderMessages, ...latestMessages];
  }

  ChatState copyWith({
    List<ChatMessage>? latestMessages,
    List<ChatMessage>? olderMessages,
    ChatConnectionStatus? connectionStatus,
    bool? isLoadingOlder,
    bool? hasMoreOlder,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ChatState(
      latestMessages: latestMessages ?? this.latestMessages,
      olderMessages: olderMessages ?? this.olderMessages,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMoreOlder: hasMoreOlder ?? this.hasMoreOlder,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props {
    return <Object?>[
      latestMessages,
      olderMessages,
      connectionStatus,
      isLoadingOlder,
      hasMoreOlder,
      errorMessage,
    ];
  }
}

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required ChatRepository repository})
    : _repository = repository,
      super(const ChatState.initial()) {
    on<ChatStarted>(_onStarted, transformer: restartable());
    on<ChatOlderRequested>(_onOlderRequested, transformer: droppable());
    on<ChatMessageSubmitted>(_onMessageSubmitted, transformer: sequential());
  }

  final ChatRepository _repository;

  Future<void> _onStarted(ChatStarted event, Emitter<ChatState> emit) async {
    emit(
      state.copyWith(
        connectionStatus: ChatConnectionStatus.loading,
        clearError: true,
      ),
    );
    await emit.forEach<List<ChatMessage>>(
      _repository.watchLatestMessages(),
      onData: (List<ChatMessage> latestMessages) {
        return state.copyWith(
          latestMessages: latestMessages,
          connectionStatus: ChatConnectionStatus.live,
          clearError: true,
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        return state.copyWith(
          connectionStatus: ChatConnectionStatus.failure,
          errorMessage: error.toString(),
        );
      },
    );
  }

  Future<void> _onOlderRequested(
    ChatOlderRequested event,
    Emitter<ChatState> emit,
  ) async {
    if (state.isLoadingOlder || !state.hasMoreOlder || state.messages.isEmpty) {
      return;
    }

    final ChatMessage oldestMessage = state.messages.first;
    final DocumentSnapshot<Map<String, dynamic>>? snapshot =
        oldestMessage.snapshot;
    if (snapshot == null) {
      return;
    }

    emit(state.copyWith(isLoadingOlder: true, clearError: true));
    try {
      final ChatPage page = await _repository.fetchOlderMessages(
        startAfter: snapshot,
      );
      emit(
        state.copyWith(
          olderMessages: <ChatMessage>[
            ...page.messages,
            ...state.olderMessages,
          ],
          isLoadingOlder: false,
          hasMoreOlder: page.hasMore,
          clearError: true,
        ),
      );
    } on Object catch (error) {
      emit(
        state.copyWith(
          isLoadingOlder: false,
          connectionStatus: ChatConnectionStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> _onMessageSubmitted(
    ChatMessageSubmitted event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _repository.sendMessage(userId: event.userId, body: event.body);
    } on Object catch (error) {
      emit(
        state.copyWith(
          connectionStatus: ChatConnectionStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }
}
