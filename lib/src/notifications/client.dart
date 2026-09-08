// Notifications HTTP client. Mirrors @construct-space/sdk's useNotification
// but receive-side only (sending is service-only with X-Internal-Secret
// — never from a phone). Backed by delivery-api.

import 'package:dio/dio.dart';

import '../api/client.dart';
import 'models.dart';

class NotificationsClient {
  NotificationsClient(this._api);

  final ApiClient _api;

  Future<List<AppNotification>> list({bool? unread, int? limit, String? sinceId}) async {
    final qs = <String, dynamic>{};
    if (unread == true) qs['unread'] = 'true';
    if (limit != null) qs['limit'] = limit;
    if (sinceId != null) qs['since_id'] = sinceId;
    final res = await _api.dio.get<Map<String, dynamic>>(
      '/api/notifications',
      queryParameters: qs.isEmpty ? null : qs,
    );
    final raw = (res.data?['notifications'] as List?) ?? const [];
    return raw.map((j) => AppNotification.fromJson(j as Map<String, dynamic>)).toList();
  }

  Future<int> unreadCount() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/notifications/unread-count');
    return (res.data?['unread'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id) =>
      _api.dio.post('/api/notifications/${Uri.encodeComponent(id)}/read');

  Future<void> markAllRead() => _api.dio.post('/api/notifications/read-all');

  Future<void> delete(String id) =>
      _api.dio.delete('/api/notifications/${Uri.encodeComponent(id)}');

  /// Register this device's FCM token. Platform must be 'ios' or 'android'.
  /// Calling again with a new token replaces the prior one server-side.
  Future<void> registerDevice({
    required String platform,
    required String token,
    String? appVersion,
  }) {
    return _api.dio.post('/api/notifications/devices', data: {
      'platform': platform,
      'token': token,
      'app_version': ?appVersion,
    });
  }

  Future<void> unregisterDevice(String token) {
    return _api.dio.delete(
      '/api/notifications/devices',
      data: {'token': token},
      // Dio's delete drops the body unless we set this option.
      options: Options(headers: {'Content-Type': 'application/json'}),
    );
  }

  Future<NotificationPreferences> preferences() async {
    final res = await _api.dio.get<Map<String, dynamic>>('/api/notifications/preferences');
    return NotificationPreferences.fromJson(res.data!);
  }

  Future<NotificationPreferences> updatePreferences({
    bool? inAppEnabled,
    bool? webPushEnabled,
    bool? mobileEnabled,
    bool? emailFallback,
    List<String>? mutedTypes,
  }) async {
    final res = await _api.dio.put<Map<String, dynamic>>(
      '/api/notifications/preferences',
      data: {
        'in_app_enabled': ?inAppEnabled,
        'web_push_enabled': ?webPushEnabled,
        'mobile_enabled': ?mobileEnabled,
        'email_fallback': ?emailFallback,
        'muted_types': ?mutedTypes,
      },
    );
    return NotificationPreferences.fromJson(res.data!);
  }
}
