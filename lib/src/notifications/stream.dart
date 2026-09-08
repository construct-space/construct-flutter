// SSE client for /api/notifications/stream. Dart's `http` package can
// stream a response body; we manually parse the text/event-stream
// framing (lines of "event: …" / "data: …" separated by blank lines).
//
// Built-in re-connect with bounded backoff. Authorization header carried
// directly (no cookie hop) — same path the dio inbox calls use.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'models.dart';

class NotificationStreamClient {
  NotificationStreamClient({
    required this.baseUrl,
    required this.tokenProvider,
  });

  final String baseUrl;
  final Future<String?> Function() tokenProvider;

  http.Client? _client;
  StreamSubscription<String>? _sub;
  bool _stopped = false;
  int _retry = 0;

  /// Open the stream and invoke handlers. Returns a function that
  /// closes everything (call from State.dispose).
  void Function() listen({
    void Function(AppNotification n)? onNotification,
    void Function(int unread)? onUnreadCount,
    void Function(Object e)? onError,
  }) {
    _stopped = false;
    _open(onNotification, onUnreadCount, onError);
    return () {
      _stopped = true;
      _sub?.cancel();
      _client?.close();
      _sub = null;
      _client = null;
    };
  }

  Future<void> _open(
    void Function(AppNotification)? onNotification,
    void Function(int)? onUnreadCount,
    void Function(Object)? onError,
  ) async {
    final token = await tokenProvider();
    if (_stopped) return;

    final req = http.Request('GET', Uri.parse('$baseUrl/api/notifications/stream'));
    req.headers['Accept'] = 'text/event-stream';
    req.headers['Cache-Control'] = 'no-cache';
    if (token != null && token.isNotEmpty) {
      req.headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    _client = http.Client();
    try {
      final resp = await _client!.send(req);
      if (resp.statusCode != 200) {
        throw HttpException('SSE handshake ${resp.statusCode}');
      }
      _retry = 0;

      String? eventName;
      final dataLines = <String>[];

      _sub = resp.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.isEmpty) {
            // Dispatch the assembled event.
            if (dataLines.isNotEmpty) {
              final dataStr = dataLines.join('\n');
              _dispatch(eventName ?? 'message', dataStr, onNotification, onUnreadCount);
            }
            eventName = null;
            dataLines.clear();
            return;
          }
          if (line.startsWith(':')) return; // comment / heartbeat
          if (line.startsWith('event:')) {
            eventName = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trimLeft());
          }
        },
        onError: (e) {
          onError?.call(e);
          _scheduleReconnect(onNotification, onUnreadCount, onError);
        },
        onDone: () => _scheduleReconnect(onNotification, onUnreadCount, onError),
        cancelOnError: true,
      );
    } catch (e) {
      onError?.call(e);
      _scheduleReconnect(onNotification, onUnreadCount, onError);
    }
  }

  void _dispatch(
    String name,
    String data,
    void Function(AppNotification)? onNotification,
    void Function(int)? onUnreadCount,
  ) {
    try {
      final json = jsonDecode(data);
      if (json is! Map) return;
      switch (name) {
        case 'notification':
          final n = json['notification'];
          if (n is Map) {
            onNotification?.call(AppNotification.fromJson(n.cast<String, dynamic>()));
          }
        case 'unread_count':
          final c = json['unread'];
          if (c is num) onUnreadCount?.call(c.toInt());
      }
    } catch (_) {
      // malformed event — ignore
    }
  }

  void _scheduleReconnect(
    void Function(AppNotification)? onNotification,
    void Function(int)? onUnreadCount,
    void Function(Object)? onError,
  ) {
    if (_stopped) return;
    _client?.close();
    _client = null;
    _sub?.cancel();
    _sub = null;
    final delay = Duration(milliseconds: (1000 * (1 << _retry)).clamp(1000, 30000));
    _retry++;
    Future.delayed(delay, () {
      if (_stopped) return;
      _open(onNotification, onUnreadCount, onError);
    });
  }
}
