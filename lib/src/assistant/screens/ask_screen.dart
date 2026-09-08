// Ask the assistant from the phone — chat-style live streaming UX,
// matching the desktop AssistantPanel layout: history scrolls at the
// top, input docked at the bottom so the keyboard pushes nothing
// important off-screen.
//
// Flow on Send:
//   1. POST /api/devices/relay with cmd=assistant.ask + a fresh
//      request_id. Server fans out to the user's operator.
//   2. Open a WS subscription filtered by that request_id (via
//      AssistantStreamClient) and append delta tokens to the visible
//      answer in real time.
//   3. assistant.complete closes the stream.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../operator_status/widgets.dart';
import '../../providers.dart';
import '../../theme/construct_theme.dart';
import '../blocks/blocks.dart';
import '../blocks/normalize.dart';
import '../stream.dart';
import '../widgets/response_blocks_view.dart';

import 'package:url_launcher/url_launcher.dart';

class _Turn {
  _Turn({required this.question});
  final String question;
  String answer = '';
  bool streaming = true;
  String? error;
}

class AskScreen extends ConsumerStatefulWidget {
  const AskScreen({super.key});

  @override
  ConsumerState<AskScreen> createState() => _AskScreenState();
}

class _AskScreenState extends ConsumerState<AskScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_Turn> _turns = [];
  bool _sending = false;
  StreamSubscription<Object>? _sub;
  AssistantStreamClient? _streamClient;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final turn = _Turn(question: text);
    setState(() {
      _sending = true;
      _turns.add(turn);
      _controller.clear();
    });
    _scrollAfterFrame();

    await _sub?.cancel();
    // Gateway-routed: device-bus moved from delivery to source on
    // 2026-05-20; the WS lives at my.construct.space/api/device-bus/ws.
    _streamClient ??= AssistantStreamClient(api: ref.read(apiClientProvider));

    try {
      final handle = await ref.read(devicesClientProvider).askAssistant(text);
      final stream = _streamClient!.watch(handle.requestId);
      _sub = stream.listen(
        (ev) => _onStreamEvent(turn, ev),
        onError: (e) {
          if (!mounted) return;
          setState(() {
            turn.error = 'Stream error: $e';
            turn.streaming = false;
            _sending = false;
          });
        },
        onDone: () {
          if (!mounted) return;
          setState(() {
            turn.streaming = false;
            _sending = false;
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      // Surface the operator-offline 503 as plain English instead of
      // a raw DioException dump. Anything else is treated as an
      // unknown send failure.
      final msg = e.toString().contains('no operator online')
          ? 'Operator is offline. Tap the red dot for instructions.'
          : 'Send failed: $e';
      setState(() {
        turn.error = msg;
        turn.streaming = false;
        _sending = false;
      });
    }
  }

  void _onStreamEvent(_Turn turn, Object ev) {
    if (!mounted) return;
    if (ev is AssistantChunk) {
      setState(() => turn.answer += ev.delta);
      _scrollAfterFrame();
    } else if (ev is AssistantComplete) {
      setState(() {
        if (turn.answer.isEmpty && ev.content.isNotEmpty) {
          turn.answer = ev.content;
        }
        turn.streaming = false;
        _sending = false;
      });
      _scrollAfterFrame();
    }
  }

  // Auto-scroll to the bottom after the next frame so freshly-appended
  // chunks (and new turns) stay in view. Skipped if the user has
  // scrolled up to read history — they probably don't want the floor
  // pulled out from under them.
  void _scrollAfterFrame() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final pos = _scrollController.position;
      final atBottom = pos.maxScrollExtent - pos.pixels < 80;
      if (!atBottom) return;
      _scrollController.animateTo(
        pos.maxScrollExtent,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('ASSISTANT'),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
        actions: const [OperatorStatusDot()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _turns.isEmpty
                  ? _EmptyState(theme: theme)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      itemCount: _turns.length,
                      itemBuilder: (_, i) => _TurnView(turn: _turns[i]),
                    ),
            ),
            _Composer(
              controller: _controller,
              sending: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Pill-shaped composer that floats above the bottom edge — same
    // shape as the desktop's "Ask anything…" bar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: ConstructColors.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const SizedBox(width: 4),
            const Icon(Icons.add, color: ConstructColors.muted, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                style: theme.textTheme.bodyMedium,
                decoration: const InputDecoration(
                  hintText: 'Ask anything…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Material(
              color: sending
                  ? ConstructColors.surfaceTint
                  : ConstructColors.accent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: sending ? null : onSend,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(11),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: ConstructColors.accent,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: ConstructColors.accentForeground,
                          size: 20,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: ConstructColors.surfaceTint,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: ConstructColors.accent,
                size: 26,
              ),
            ),
            const SizedBox(height: 20),
            Text('Ask anything', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Your operator runs on your desktop.\nAnswers stream back live.',
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TurnView extends StatelessWidget {
  const _TurnView({required this.turn});
  final _Turn turn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // User bubble — right-aligned, accent fill, matches the
          // desktop AssistantPanel's red pill exactly.
          Align(
            alignment: Alignment.centerRight,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  color: ConstructColors.accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(22),
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(6),
                  ),
                ),
                child: Text(
                  turn.question,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: ConstructColors.accentForeground,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Assistant — plain text, like desktop. No bubble — keeps the
          // canvas clean, lets prose breathe. Structured-output JSON
          // envelopes (action blocks, version wrappers) are parsed out
          // and rendered as chips below the prose.
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: turn.error != null
                ? Text(
                    turn.error!,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  )
                : (turn.answer.isEmpty && turn.streaming)
                    ? const _ThinkingDots()
                    : _AnswerBody(answer: turn.answer, streaming: turn.streaming),
          ),
        ],
      ),
    );
  }
}

class _AnswerBody extends StatelessWidget {
  const _AnswerBody({required this.answer, required this.streaming});
  final String answer;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final blocks = normalize(answer);
    return ResponseBlocksView(
      blocks: blocks,
      streaming: streaming,
      onAction: (action) => _onAction(context, action),
      onQuestionAnswer: (qId, answer) {
        // No relay channel for question answers yet — show feedback.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: ConstructColors.foreground,
            content: Text(
              'Selected: ${answer is List ? (answer).join(', ') : answer}',
              style: const TextStyle(color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }

  Future<void> _onAction(BuildContext context, ActionItem action) async {
    // External URL — open it. Otherwise relay-to-desktop placeholder
    // (the desktop spaces these reference don't have mobile UIs yet).
    final url = action.url;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    }
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ConstructColors.foreground,
        content: Text(
          '"${action.label}" opens on your desktop. Mobile handoff coming soon.',
          style: const TextStyle(color: Colors.white),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _ThinkingDots extends StatefulWidget {
  const _ThinkingDots();

  @override
  State<_ThinkingDots> createState() => _ThinkingDotsState();
}

class _ThinkingDotsState extends State<_ThinkingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          children: List.generate(3, (i) {
            final phase = (_controller.value + i * 0.18) % 1.0;
            // Smooth in-out alpha so each dot pulses slightly out of
            // phase — typing-indicator feel.
            final pulse = (1 - (phase - 0.5).abs() * 2).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: ConstructColors.accent.withValues(
                    alpha: 0.3 + 0.6 * pulse,
                  ),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
