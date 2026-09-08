// Live cross-device assistant stream. Opens a WebSocket to source's
// device bus (/api/device-bus/ws, gateway-routed) and surfaces
// chunk/complete events for the AskScreen to render in real time.
// Filters by request_id so a screen only sees its own ask.
//
// Migrated 2026-05-20 from delivery's /api/notifications/ws (which
// used a nested {type:'device.command', command:{cmd, payload}}
// envelope) to source's flat {type, from, payload} shape — same
// hub that carries scheduler.claim_now events.

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/io.dart';

import '../api/client.dart';

class AssistantChunk {
  AssistantChunk(this.delta);
  final String delta;
}

class AssistantComplete {
  AssistantComplete({required this.content, required this.stopReason});
  final String content;
  final String stopReason;
}

class AssistantStreamClient {
  AssistantStreamClient({required this.api});

  final ApiClient api;

  IOWebSocketChannel? _channel;
  StreamController<Object>? _controller;

  /// Opens a WS for [requestId] and emits AssistantChunk / AssistantComplete
  /// objects for matching events. Closes when the consumer cancels the
  /// returned subscription.
  Stream<Object> watch(String requestId) {
    _controller?.close();
    _channel?.sink.close();

    final ctl = StreamController<Object>();
    _controller = ctl;

    _open(requestId, ctl);

    ctl.onCancel = () async {
      await _channel?.sink.close();
      _channel = null;
      _controller = null;
    };
    return ctl.stream;
  }

  Future<void> _open(String requestId, StreamController<Object> ctl) async {
    final token = await api.tokenProvider();
    if (token == null || token.isEmpty) {
      ctl.addError(StateError('not signed in'));
      await ctl.close();
      return;
    }
    final base = api.baseUrl;
    final wsBase = base.replaceFirst(RegExp(r'^https'), 'wss').replaceFirst(RegExp(r'^http'), 'ws');
    final url = '$wsBase/api/device-bus/ws?token=${Uri.encodeQueryComponent(token)}';

    try {
      _channel = IOWebSocketChannel.connect(Uri.parse(url));
    } catch (e) {
      ctl.addError(e);
      await ctl.close();
      return;
    }

    _channel!.stream.listen((raw) {
      if (raw is! String) return;
      final msg = _tryDecode(raw);
      if (msg == null) return;
      // Source's bus uses a flat envelope: {type, from?, payload?}.
      // We filter by type + request_id to ignore other devices' asks
      // and unrelated event types (scheduler.claim_now, hello frame).
      final type = msg['type'] as String?;
      final payload = msg['payload'] as Map<String, dynamic>?;
      if (payload == null || payload['request_id'] != requestId) return;

      if (type == 'assistant.chunk') {
        final delta = payload['delta'] as String?;
        if (delta != null) ctl.add(AssistantChunk(delta));
      } else if (type == 'assistant.complete') {
        ctl.add(AssistantComplete(
          content: (payload['content'] as String?) ?? '',
          stopReason: (payload['stop_reason'] as String?) ?? 'complete',
        ));
        ctl.close();
      }
    }, onError: (e) {
      if (!ctl.isClosed) ctl.addError(e);
    }, onDone: () {
      if (!ctl.isClosed) ctl.close();
    });
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    try {
      final v = jsonDecode(raw);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }
}
