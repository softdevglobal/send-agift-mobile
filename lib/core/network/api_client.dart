import 'package:dio/dio.dart';

import '../config/app_config.dart';
import '../errors/app_exception.dart';
import 'token_storage.dart';

/// Thin wrapper around Dio pre-configured with the API base URL, auth
/// header injection and consistent error mapping.
class ApiClient {
  ApiClient(this._tokenStorage)
    : dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 15),
          contentType: 'application/json',
        ),
      ) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _tokenStorage.accessToken;
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) {
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
  final TokenStorage _tokenStorage;

  AppException mapError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.connectionError) {
      return const NetworkException();
    }

    final statusCode = error.response?.statusCode;

    // A 401 means two different things depending on whether the request
    // carried a session token. On an authenticated call (has an Authorization
    // header) it means that token was rejected. The session really did
    // expire. On login/register (no token sent yet) it means the submitted
    // credentials themselves were wrong, and the backend's own message
    // ("invalid email or password") is what should show, not "session
    // expired". There was no session to expire.
    final hadToken = error.requestOptions.headers['Authorization'] != null;
    if (statusCode == 401 && hadToken) {
      return const UnauthorizedException();
    }

    // The API reports failures as `{ "error": "..." }`; `message` is kept as a fallback.
    final data = error.response?.data;
    final message = data is Map
        ? (data['error'] as String? ??
              data['message'] as String? ??
              'Something went wrong.')
        : 'Something went wrong.';
    return AppException(
      message,
      statusCode: statusCode,
      code: data is Map ? data['code'] as String? : null,
      details: data is Map<String, dynamic> ? data : const {},
    );
  }
}
