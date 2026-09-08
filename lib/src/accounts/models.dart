// Mirror of /api/accounts/me/scope's wire shape. Hand-rolled to keep the
// dep surface small; promote to freezed when there's more than a couple
// of accounts types.

class AccountUser {
  AccountUser({
    required this.uuid,
    required this.email,
    this.firstName,
    this.lastName,
    this.username,
    this.avatarUrl,
  });

  final String uuid;
  final String email;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? avatarUrl;

  String get displayName {
    final parts = [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty);
    if (parts.isNotEmpty) return parts.join(' ');
    return username ?? email;
  }

  /// First word of the display name — for greetings like "Welcome, Flak".
  String get firstNameOrUsername {
    if (firstName != null && firstName!.isNotEmpty) return firstName!;
    if (username != null && username!.isNotEmpty) return username!;
    return email.split('@').first;
  }

  factory AccountUser.fromJson(Map<String, dynamic> json) => AccountUser(
        uuid: (json['uuid'] ?? json['id'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        firstName: json['first_name'] as String?,
        lastName: json['last_name'] as String?,
        username: json['username'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}

class AccountScope {
  AccountScope({
    required this.user,
    required this.authenticated,
    this.scope,
    this.developer = false,
    this.delivery = false,
    this.org,
  });

  final AccountUser user;
  final bool authenticated;
  final String? scope; // 'user' | 'org'
  final bool developer;
  final bool delivery;
  final AccountOrg? org;

  factory AccountScope.fromJson(Map<String, dynamic> json) => AccountScope(
        authenticated: (json['authenticated'] ?? false) as bool,
        scope: json['scope'] as String?,
        developer: (json['developer'] ?? false) as bool,
        delivery: (json['delivery'] ?? false) as bool,
        user: AccountUser.fromJson((json['user'] as Map?)?.cast<String, dynamic>() ?? const {}),
        org: json['org'] is Map
            ? AccountOrg.fromJson((json['org'] as Map).cast<String, dynamic>())
            : null,
      );
}

class AccountOrg {
  AccountOrg({required this.id, required this.slug, this.name, this.icon});

  final String id;
  final String slug;
  final String? name;
  final String? icon;

  factory AccountOrg.fromJson(Map<String, dynamic> json) => AccountOrg(
        id: (json['id'] ?? '') as String,
        slug: (json['slug'] ?? '') as String,
        name: json['name'] as String?,
        icon: json['icon'] as String?,
      );
}
