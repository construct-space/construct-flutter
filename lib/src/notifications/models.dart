// Wire shapes for delivery-api's /api/notifications/*. Hand-rolled
// (no freezed) to keep the dependency surface small while the app is
// young — promote to freezed when we have more than a handful of types.

import 'dart:convert';

class AppNotification {
  AppNotification({
    required this.id,
    required this.source,
    required this.type,
    required this.title,
    required this.body,
    this.link,
    this.data,
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final String source;
  final String type;
  final String title;
  final String body;
  final String? link;
  final Object? data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isUnread => readAt == null;

  /// Parses `data` into a Map. delivery-api stores it as a JSON string
  /// column, but a server tweak could return a parsed object — handle
  /// both shapes. Returns null if the field is missing or unparseable.
  Map<String, dynamic>? get dataMap {
    final d = data;
    if (d is Map<String, dynamic>) return d;
    if (d is String && d.isNotEmpty) {
      try {
        final parsed = jsonDecode(d);
        if (parsed is Map<String, dynamic>) return parsed;
      } catch (_) {}
    }
    return null;
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
        id: json['id'] as String,
        source: (json['source'] ?? '') as String,
        type: (json['type'] ?? '') as String,
        title: (json['title'] ?? '') as String,
        body: (json['body'] ?? '') as String,
        link: json['link'] as String?,
        data: json['data'],
        readAt: _parseDate(json['read_at']),
        createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      );
}

class NotificationPreferences {
  NotificationPreferences({
    required this.inAppEnabled,
    required this.webPushEnabled,
    required this.mobileEnabled,
    required this.emailFallback,
    this.mutedTypes = const [],
    required this.updatedAt,
  });

  final bool inAppEnabled;
  final bool webPushEnabled;
  final bool mobileEnabled;
  final bool emailFallback;
  final List<String> mutedTypes;
  final DateTime updatedAt;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        inAppEnabled: (json['in_app_enabled'] ?? true) as bool,
        webPushEnabled: (json['web_push_enabled'] ?? true) as bool,
        mobileEnabled: (json['mobile_enabled'] ?? true) as bool,
        emailFallback: (json['email_fallback'] ?? false) as bool,
        mutedTypes: (json['muted_types'] as List?)?.cast<String>() ?? const [],
        updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      );
}

DateTime? _parseDate(Object? v) {
  if (v is String && v.isNotEmpty) {
    return DateTime.tryParse(v);
  }
  return null;
}
