import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/single_child_widget.dart';

import 'features/chat/chat_bloc.dart';
import 'features/chat/chat_repository.dart';
import 'features/raid/raid_bloc.dart';
import 'features/world_event/world_event_bloc.dart';
import 'firebase_options.dart';
import 'injection_container.dart';
import 'raid_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  configureDependencies();

  runApp(
    DrovenueApp(
      raidService: serviceLocator<RaidService>(),
      chatRepository: serviceLocator<ChatRepository>(),
    ),
  );
}

class DrovenueApp extends StatelessWidget {
  const DrovenueApp({
    required this.raidService,
    required this.chatRepository,
    super.key,
  });

  final RaidService raidService;
  final ChatRepository chatRepository;

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: <SingleChildWidget>[
        BlocProvider<WorldEventBloc>(
          create: (BuildContext context) {
            return WorldEventBloc()..add(const WorldEventStarted());
          },
        ),
        BlocProvider<RaidBloc>(
          create: (BuildContext context) {
            return RaidBloc(raidService: raidService)..add(const RaidStarted());
          },
        ),
        BlocProvider<ChatBloc>(
          create: (BuildContext context) {
            return ChatBloc(repository: chatRepository)
              ..add(const ChatStarted());
          },
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Project Aether',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xff0f766e),
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: const Color(0xff0b1120),
          cardTheme: const CardThemeData(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
          ),
        ),
        home: const AetherHomePage(),
      ),
    );
  }
}

class AetherHomePage extends StatefulWidget {
  const AetherHomePage({super.key});

  @override
  State<AetherHomePage> createState() => _AetherHomePageState();
}

class _AetherHomePageState extends State<AetherHomePage> {
  late final String _userId = 'player_${DateTime.now().microsecondsSinceEpoch}';
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project Aether'),
        centerTitle: false,
        backgroundColor: const Color(0xff0b1120),
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final bool wide = constraints.maxWidth >= 860;
            final Widget pulse = const WorldPulsePanel();
            final Widget raid = GeoRaidPanel(userId: _userId);
            final Widget chat = EngagementChatPanel(
              userId: _userId,
              controller: _messageController,
            );

            if (wide) {
              return Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    SizedBox(
                      width: 360,
                      child: Column(
                        children: <Widget>[
                          pulse,
                          const SizedBox(height: 16),
                          raid,
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: chat),
                  ],
                ),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                pulse,
                const SizedBox(height: 16),
                raid,
                const SizedBox(height: 16),
                SizedBox(height: 520, child: chat),
              ],
            );
          },
        ),
      ),
    );
  }
}

class WorldPulsePanel extends StatelessWidget {
  const WorldPulsePanel({super.key});

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SectionHeader(
            icon: Icons.public,
            title: 'Global Pulse',
            value: 'World Boss',
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            child: BlocSelector<WorldEventBloc, WorldEventState, Duration>(
              selector: (WorldEventState state) => state.remaining,
              builder: (BuildContext context, Duration remaining) {
                return Text(
                  _formatDuration(remaining),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontFeatures: const <FontFeature>[
                      FontFeature.tabularFigures(),
                    ],
                    fontWeight: FontWeight.w800,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            value: context.select<WorldEventBloc, double>((
              WorldEventBloc bloc,
            ) {
              final Duration remaining = bloc.state.remaining;
              return _clampProgress(
                remaining.inMilliseconds /
                    const Duration(minutes: 10).inMilliseconds,
              );
            }),
          ),
        ],
      ),
    );
  }
}

class GeoRaidPanel extends StatelessWidget {
  const GeoRaidPanel({required this.userId, super.key});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      child: BlocBuilder<RaidBloc, RaidState>(
        builder: (BuildContext context, RaidState state) {
          final bool isJoining = state.joinStatus == RaidJoinStatus.joining;
          final bool isFull = state.status.isFull;
          final double progress = state.status.maxSlots == 0
              ? 0
              : state.status.slotsFilled / state.status.maxSlots;
          final String buttonText = isFull ? 'Raid Full' : 'Join Raid';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SectionHeader(
                icon: Icons.shield,
                title: 'Geo-Raid',
                value: '15 slots',
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${state.status.slotsFilled}',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10, left: 6),
                    child: Text(
                      '/ ${state.status.maxSlots}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
                value: _clampProgress(progress),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isJoining || isFull
                      ? null
                      : () {
                          context.read<RaidBloc>().add(
                            RaidJoinPressed(userId: userId),
                          );
                        },
                  icon: isJoining
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt),
                  label: Text(buttonText),
                ),
              ),
              if (state.joinStatus == RaidJoinStatus.joined) ...<Widget>[
                const SizedBox(height: 12),
                const StatusLine(
                  icon: Icons.check_circle,
                  text: 'Joined',
                  color: Color(0xff22c55e),
                ),
              ],
              if (state.joinStatus == RaidJoinStatus.full) ...<Widget>[
                const SizedBox(height: 12),
                const StatusLine(
                  icon: Icons.block,
                  text: 'Full',
                  color: Color(0xfff97316),
                ),
              ],
              if (state.errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                StatusLine(
                  icon: Icons.error,
                  text: state.errorMessage!,
                  color: const Color(0xffef4444),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class EngagementChatPanel extends StatelessWidget {
  const EngagementChatPanel({
    required this.userId,
    required this.controller,
    super.key,
  });

  final String userId;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SectionSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const SectionHeader(
            icon: Icons.forum,
            title: 'Engagement Chat',
            value: 'live',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (BuildContext context, ChatState state) {
                final List<ChatMessage> messages = state.messages;
                if (state.connectionStatus == ChatConnectionStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.separated(
                  reverse: true,
                  itemCount: messages.length + 1,
                  separatorBuilder: (BuildContext context, int index) {
                    return const SizedBox(height: 8);
                  },
                  itemBuilder: (BuildContext context, int index) {
                    if (index == messages.length) {
                      return TextButton.icon(
                        onPressed: state.hasMoreOlder && !state.isLoadingOlder
                            ? () {
                                context.read<ChatBloc>().add(
                                  const ChatOlderRequested(),
                                );
                              }
                            : null,
                        icon: const Icon(Icons.history),
                        label: Text(state.isLoadingOlder ? 'Loading' : 'Older'),
                      );
                    }

                    final ChatMessage message =
                        messages[messages.length - index - 1];
                    return MessageBubble(
                      message: message,
                      isMine: message.userId == userId,
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 3,
                  textInputAction: TextInputAction.send,
                  decoration: const InputDecoration(
                    hintText: 'Message',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (String value) {
                    _submitMessage(context);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send',
                onPressed: () {
                  _submitMessage(context);
                },
                icon: const Icon(Icons.send),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _submitMessage(BuildContext context) {
    final String body = controller.text;
    if (body.trim().isEmpty) {
      return;
    }
    context.read<ChatBloc>().add(
      ChatMessageSubmitted(userId: userId, body: body),
    );
    controller.clear();
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({required this.message, required this.isMine, super.key});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final Color background = isMine
        ? const Color(0xff0f766e)
        : const Color(0xff1e293b);
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message.userId,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(message.body),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionSurface extends StatelessWidget {
  const SectionSurface({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff111827),
        border: Border.all(color: const Color(0xff334155)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(18), child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.icon,
    required this.title,
    required this.value,
    super.key,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 20, color: const Color(0xff5eead4)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: const Color(0xffcbd5e1)),
        ),
      ],
    );
  }
}

class StatusLine extends StatelessWidget {
  const StatusLine({
    required this.icon,
    required this.text,
    required this.color,
    super.key,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final Duration clamped = duration.isNegative ? Duration.zero : duration;
  final int minutes = clamped.inMinutes.remainder(60);
  final int seconds = clamped.inSeconds.remainder(60);
  final int tenths = clamped.inMilliseconds.remainder(1000) ~/ 100;
  final String minuteText = minutes.toString().padLeft(2, '0');
  final String secondText = seconds.toString().padLeft(2, '0');
  return '$minuteText:$secondText.$tenths';
}

double _clampProgress(double value) {
  return value.clamp(0.0, 1.0).toDouble();
}
