// Cross-device command bus client. Phone publishes assistant.ask
// envelopes here; the user's desktop (subscribed to the same bus)
// runs the prompt and publishes assistant.chunk / assistant.complete
// events back. Caller correlates by the request_id minted here.
//
// Migrated 2026-05-20 from delivery's /api/devices/relay to source's
// /api/device-bus/relay. Envelope field renamed `cmd` → `type` to
// match source's wire shape (one bus, one envelope type for
// scheduler.claim_now and assistant.ask alike).

import '../api/client.dart';

class AssistantAskHandle {
  AssistantAskHandle({required this.requestId});
  final String requestId;
}

class DevicesClient {
  DevicesClient(this._api);

  final ApiClient _api;

  /// Asks the operator a question. Returns the handle (request_id) so
  /// the caller can subscribe to streaming chunks via
  /// [AssistantStreamClient]. The HTTP call returns as soon as the
  /// relay accepts the envelope; the answer streams asynchronously.
  Future<AssistantAskHandle> askAssistant(String text, {String from = 'mobile'}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('text is empty');
    }
    final requestId = '${DateTime.now().microsecondsSinceEpoch}-${_rand()}';
    await _api.dio.post('/api/device-bus/relay', data: {
      'type': 'assistant.ask',
      'from': from,
      'payload': {
        'text': trimmed,
        'request_id': requestId,
      },
    });
    return AssistantAskHandle(requestId: requestId);
  }

  static String _rand() {
    final n = DateTime.now().microsecond ^ DateTime.now().millisecond;
    return n.toRadixString(36);
  }
}
