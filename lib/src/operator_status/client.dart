// Operator-presence status. Backed by GET /api/device-bus/operator/status
// on source-api which inspects the WS hub for a subscription that
// has identified itself with `{type:"register",kind:"operator"}`.
//
// Migrated 2026-05-20 from delivery's /api/operator/status — the
// hub itself moved to source for SRP (delivery does notifications,
// source owns the device bus).

import '../api/client.dart';

class OperatorStatus {
  const OperatorStatus({required this.online});
  final bool online;
}

class OperatorStatusClient {
  OperatorStatusClient(this._api);

  final ApiClient _api;

  Future<OperatorStatus> fetch() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/device-bus/operator/status');
    return OperatorStatus(online: (res.data?['online'] as bool?) ?? false);
  }
}
