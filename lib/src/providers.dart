// Riverpod provider graph. Hand-written (not codegen) — Riverpod 3.x's
// codegen is mid-migration in 2026, and the manual syntax stays compact
// enough for an app this size.
//
// Provider tree:
//   secureStorageProvider
//     ↓
//   authTokenProvider (AsyncValue<String?>)
//     ↓
//   apiClientProvider — Dio + bearer injection
//     ↓
//   notificationsClientProvider
//     ├ inboxProvider           (Future<List<AppNotification>>)
//     ├ unreadCountProvider     (Future<int>)
//     └ preferencesProvider     (Future<NotificationPreferences>)

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'accounts/client.dart';
import 'accounts/models.dart';
import 'api/client.dart';
import 'assistant/client.dart';
import 'auth/oauth.dart';
import 'auth/password.dart';
import 'notifications/client.dart';
import 'notifications/models.dart';
import 'notifications/stream.dart';
import 'operator_status/client.dart';

const _baseUrl = String.fromEnvironment(
  'CONSTRUCT_BASE_URL',
  defaultValue: 'https://my.construct.space',
);
// Direct upstream for delivery-api endpoints (kept for future
// notification-only usage; the device bus moved to source on
// 2026-05-20 and now routes through the my.construct.space gateway
// — gateway exempts /api/device-bus/ws from auth_request so the
// ?token= handshake works).
const _deliveryBaseUrl = String.fromEnvironment(
  'CONSTRUCT_DELIVERY_URL',
  defaultValue: 'https://api.construct.delivery',
);
const _tokenKey = 'cat_token';

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
});

class AuthController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async {
    final storage = ref.read(secureStorageProvider);
    return storage.read(key: _tokenKey);
  }

  Future<void> setToken(String token) async {
    final storage = ref.read(secureStorageProvider);
    await storage.write(key: _tokenKey, value: token);
    state = AsyncData(token);
  }

  Future<void> signOut() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: _tokenKey);
    state = const AsyncData(null);
  }
}

final authProvider = AsyncNotifierProvider<AuthController, String?>(
  AuthController.new,
);

final oauthServiceProvider = Provider<OAuthService>((ref) => OAuthService());
final passwordAuthProvider = Provider<PasswordAuthService>(
  (ref) => PasswordAuthService(),
);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: _baseUrl,
    tokenProvider: () async {
      // ref.read returns the current AsyncValue; we resolve to its
      // value (or null if still loading / errored). This matches the
      // contract ApiClient expects.
      final auth = ref.read(authProvider);
      return auth.value;
    },
  );
});

/// Direct delivery-api client for endpoints that can't go through the
/// gateway. Same auth token, different base.
final deliveryApiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    baseUrl: _deliveryBaseUrl,
    tokenProvider: () async => ref.read(authProvider).value,
  );
});

final notificationsClientProvider = Provider<NotificationsClient>((ref) {
  return NotificationsClient(ref.watch(apiClientProvider));
});

final accountsClientProvider = Provider<AccountsClient>((ref) {
  return AccountsClient(ref.watch(apiClientProvider));
});

final devicesClientProvider = Provider<DevicesClient>((ref) {
  return DevicesClient(ref.watch(apiClientProvider));
});

/// Operator presence — gateway-routed to source-api which owns the
/// device-bus hub (moved 2026-05-20).
final operatorStatusClientProvider = Provider<OperatorStatusClient>((ref) {
  return OperatorStatusClient(ref.watch(apiClientProvider));
});

/// Polled every 15s while the app is in the foreground. UI (the
/// AppBar dot) reads this to flip green/red without forcing the user
/// to take an action that would surface the offline state.
final operatorStatusProvider = StreamProvider<OperatorStatus>((ref) async* {
  final client = ref.watch(operatorStatusClientProvider);
  // ref.watch(authProvider) so the stream resets on sign-in/out.
  ref.watch(authProvider);
  while (true) {
    try {
      yield await client.fetch();
    } catch (_) {
      yield const OperatorStatus(online: false);
    }
    await Future<void>.delayed(const Duration(seconds: 15));
  }
});

/// Per-screen SSE client. The Inbox creates an instance via this
/// provider, attaches handlers in initState, and the .listen() return
/// is cancelled on dispose. Doing it as a Provider (not StateProvider)
/// keeps the connection lifecycle owned by the screen, not the global
/// app — Home shouldn't pay for an open connection.
final notificationStreamClientProvider = Provider<NotificationStreamClient>((ref) {
  final api = ref.watch(apiClientProvider);
  return NotificationStreamClient(
    baseUrl: api.baseUrl,
    tokenProvider: api.tokenProvider,
  );
});

/// Current user scope (identity + org + flags). Refetches whenever the
/// auth token changes (sign-in / sign-out).
final scopeProvider = FutureProvider<AccountScope>((ref) async {
  ref.watch(authProvider);
  return ref.watch(accountsClientProvider).scope();
});

final inboxProvider = FutureProvider<List<AppNotification>>((ref) async {
  // Re-fetch whenever the auth token changes (sign-in / sign-out).
  ref.watch(authProvider);
  final client = ref.watch(notificationsClientProvider);
  return client.list(limit: 50);
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.watch(authProvider);
  return ref.watch(notificationsClientProvider).unreadCount();
});
