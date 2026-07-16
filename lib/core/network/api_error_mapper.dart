import 'package:dio/dio.dart';

/// Maps any error caught from an API call into a short, safe, user-facing
/// message. Never surfaces: raw exception text (`DioException.toString()`),
/// stack traces, HTML/server response bodies, tokens, request headers,
/// internal routes, or storage keys. Every UI screen displaying an
/// API-related error must go through this mapper rather than `e.toString()`.
class ApiErrorMapper {
  static String map(Object error) {
    if (error is DioException) {
      return _mapDioException(error);
    }

    return genericMessage;
  }

  static String mapStatusCode(int? statusCode) {
    switch (statusCode) {
      case 401:
        return 'Your credentials are incorrect or your session has expired. Please sign in again.';
      case 403:
        return 'This action is not authorized.';
      case 404:
        return 'The requested item is unavailable.';
      case 422:
        return 'Some information could not be validated. Please check your entries and try again.';
      case 429:
        return 'Too many requests. Please wait a moment and try again.';
      case 500:
        return 'A temporary server problem occurred. Please try again shortly.';
      case 503:
        return 'The service is temporarily unavailable. Please try again later.';
      default:
        return genericMessage;
    }
  }

  static String _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.badResponse:
        return mapStatusCode(error.response?.statusCode);
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return connectionProblemMessage;
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
    }
  }

  static const String genericMessage = 'Something went wrong. Please try again.';

  static const String connectionProblemMessage =
      'A connection problem occurred. Check your internet connection and try again.';
}
