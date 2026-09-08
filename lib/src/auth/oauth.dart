// OAuth/PKCE flow against accounts-api. Mirrors the desktop app:
// client_id "construct_app", redirect "construct://oauth/callback".
// The same client_id works for mobile because URL schemes are scoped
// per-OS — no collision between iOS/Android and macOS/Windows/Linux.
//
// Sequence:
//   1. Build a PKCE code_verifier + S256 code_challenge.
//   2. Open https://api.construct.space/oauth/authorize?... in an in-app
//      browser (SFAuthenticationSession on iOS, Custom Tabs on Android)
//      via flutter_web_auth_2.
//   3. accounts redirects to construct://oauth/callback?code=… which the
//      OS routes back to the app and the plugin returns to us.
//   4. POST /oauth/token with grant_type=authorization_code + verifier;
//      response includes access_token (cat_*).

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';

// See note in auth/password.dart — point at the gateway, not api.construct.space.
const String accountsBaseUrl = String.fromEnvironment(
  'CONSTRUCT_ACCOUNTS_URL',
  defaultValue: 'https://my.construct.space',
);
const String _clientId = 'construct_app';
const String _redirectUri = 'construct://oauth/callback';
const String _callbackScheme = 'construct';

class OAuthResult {
  OAuthResult({required this.accessToken, this.refreshToken, this.expiresIn});
  final String accessToken;
  final String? refreshToken;
  final int? expiresIn;
}

class OAuthService {
  OAuthService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  /// Run the full authorization-code-with-PKCE flow. Throws on cancel
  /// or any server-side error; returns the access token on success.
  Future<OAuthResult> signIn() async {
    final verifier = _generateCodeVerifier();
    final challenge = _s256(verifier);
    final state = _generateState();

    final authUrl = Uri.parse('$accountsBaseUrl/oauth/authorize').replace(queryParameters: {
      'client_id': _clientId,
      'redirect_uri': _redirectUri,
      'response_type': 'code',
      'scope': 'profile email',
      'state': state,
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    });

    final result = await FlutterWebAuth2.authenticate(
      url: authUrl.toString(),
      callbackUrlScheme: _callbackScheme,
    );

    final returned = Uri.parse(result);
    final code = returned.queryParameters['code'];
    final returnedState = returned.queryParameters['state'];
    if (code == null || code.isEmpty) {
      throw Exception('OAuth: no code in callback (${returned.toString()})');
    }
    if (returnedState != state) {
      throw Exception('OAuth: state mismatch (CSRF guard)');
    }

    final tokenRes = await _dio.post<Map<String, dynamic>>(
      '$accountsBaseUrl/oauth/token',
      data: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': _redirectUri,
        'client_id': _clientId,
        'code_verifier': verifier,
      },
      options: Options(
        contentType: Headers.formUrlEncodedContentType,
      ),
    );
    final body = tokenRes.data ?? const {};
    final token = body['access_token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('OAuth: no access_token in response');
    }
    return OAuthResult(
      accessToken: token,
      refreshToken: body['refresh_token'] as String?,
      expiresIn: (body['expires_in'] as num?)?.toInt(),
    );
  }
}

String _generateCodeVerifier() {
  // RFC 7636: 43-128 chars from URL-safe alphabet. 64 random bytes →
  // base64url gives 86 chars, well within range.
  final bytes = _randomBytes(64);
  return _base64UrlNoPad(bytes);
}

String _s256(String verifier) {
  final digest = sha256.convert(utf8.encode(verifier));
  return _base64UrlNoPad(Uint8List.fromList(digest.bytes));
}

String _generateState() {
  return _base64UrlNoPad(_randomBytes(16));
}

Uint8List _randomBytes(int n) {
  final r = Random.secure();
  final out = Uint8List(n);
  for (var i = 0; i < n; i++) {
    out[i] = r.nextInt(256);
  }
  return out;
}

String _base64UrlNoPad(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}
