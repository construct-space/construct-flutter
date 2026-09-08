// HTTP client + auth glue. One Dio instance, one place that injects the
// cat_ identity bearer. Keep this dumb — service-specific clients
// (notifications, accounts, …) layer on top.

import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({required this.baseUrl, required this.tokenProvider})
      : dio = Dio(BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
          contentType: 'application/json',
        )) {
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final token = await tokenProvider();
        if (token != null && token.isNotEmpty) {
          opts.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(opts);
      },
    ));
  }

  /// Public origin of the gateway (e.g. https://my.construct.space).
  /// All notification endpoints live under `/api/notifications/*`.
  final String baseUrl;

  /// Async getter for the current cat_ identity bearer. Returning null
  /// causes calls to go out unauthenticated, which the server will 401 —
  /// fine, we surface it as a DioException to the UI layer.
  final Future<String?> Function() tokenProvider;

  final Dio dio;
}
