// Direct password login against accounts-api. Mirrors construct-app's
// useConstructAuth.loginWithPassword: POST /api/auth/login with
// { email, password, client_id } and accounts switches from setting a
// session cookie to returning a bearer access_token (cat_*).
//
// Three response branches the caller must handle:
//   • access_token        — signed in
//   • requires_2fa        — call verifyTwoFactor with pending_token
//   • must_change_password — out of scope here; ship a reset flow later

import 'package:dio/dio.dart';

// Calls go to the my.construct.space gateway (which forwards to accounts
// with the internal shared secret). Hitting api.construct.space directly
// targets a separate accounts deployment with a different DB and 401s
// with "API key is required". Override only for local gateway testing.
const String accountsBaseUrl = String.fromEnvironment(
  'CONSTRUCT_ACCOUNTS_URL',
  defaultValue: 'https://my.construct.space',
);
const String _clientId = 'construct_app';

sealed class LoginOutcome {
  const LoginOutcome();
}

class LoginOk extends LoginOutcome {
  const LoginOk(this.accessToken, {this.refreshToken, this.expiresIn});
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
}

class LoginNeeds2FA extends LoginOutcome {
  const LoginNeeds2FA(this.pendingToken);
  final String pendingToken;
}

class LoginMustReset extends LoginOutcome {
  const LoginMustReset(this.resetToken);
  final String resetToken;
}

class LoginError extends LoginOutcome {
  const LoginError(this.message);
  final String message;
}

class PasswordAuthService {
  PasswordAuthService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  Future<LoginOutcome> login(String email, String password) {
    return _post('/api/auth/login', {
      'email': email,
      'password': password,
      'client_id': _clientId,
    });
  }

  Future<LoginOutcome> verifyTwoFactor(String pendingToken, String code) {
    return _post('/verify-2fa', {
      'pending_token': pendingToken,
      'code': code,
      'client_id': _clientId,
    });
  }

  Future<LoginOutcome> _post(String path, Map<String, dynamic> body) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '$accountsBaseUrl$path',
        data: body,
        options: Options(contentType: Headers.jsonContentType),
      );
      return _parse(res.data ?? const {});
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        final msg = data['error'] as String?;
        if (msg != null && msg.isNotEmpty) return LoginError(msg);
      }
      return LoginError('Request failed (${e.response?.statusCode ?? '?'})');
    } catch (e) {
      return LoginError(e.toString());
    }
  }

  LoginOutcome _parse(Map<String, dynamic> body) {
    if (body['requires_2fa'] == true && body['pending_token'] is String) {
      return LoginNeeds2FA(body['pending_token'] as String);
    }
    if (body['must_change_password'] == true && body['reset_token'] is String) {
      return LoginMustReset(body['reset_token'] as String);
    }
    final token = body['access_token'] as String?;
    if (token != null && token.isNotEmpty) {
      return LoginOk(
        token,
        refreshToken: body['refresh_token'] as String?,
        expiresIn: (body['expires_in'] as num?)?.toInt(),
      );
    }
    return LoginError(body['error'] as String? ?? 'Unexpected response');
  }
}
