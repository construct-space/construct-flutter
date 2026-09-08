// Accounts HTTP client. /me/scope is the only thing we need so far; the
// rest of accounts (org switching, password change, …) will land here
// when the corresponding screens do.

import '../api/client.dart';
import 'models.dart';

class AccountsClient {
  AccountsClient(this._api);
  final ApiClient _api;

  Future<AccountScope> scope() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/accounts/me/scope');
    return AccountScope.fromJson(res.data ?? const {});
  }
}
