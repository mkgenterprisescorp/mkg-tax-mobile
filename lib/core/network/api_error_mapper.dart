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
    // Avoid importing PortalException / AuthException (circular deps).
    final typeName = error.runtimeType.toString();
    if (typeName == 'PortalException' || typeName == 'AuthException') {
      final msg = error.toString().trim();
      // These exceptions' toString() returns the user message only.
      if (msg.isNotEmpty &&
          !msg.contains('Exception') &&
          msg.length < 180 &&
          !msg.contains('\n')) {
        return msg;
      }
    }
    if (error is StateError) {
      final msg = error.message.trim();
      // Prefer safe messages we throw ourselves; never raw internals.
      if (msg == loginSessionExpiredMessage ||
          msg == loginNoInternetMessage ||
          msg == loginServerUnavailableMessage ||
          msg.startsWith('This action') ||
          msg.startsWith('Some information') ||
          msg.startsWith('This information changed') ||
          msg.startsWith('Unable to') ||
          msg.startsWith('The requested') ||
          msg.startsWith('Too many') ||
          msg.startsWith('Please check') ||
          msg.startsWith('Please sign in') ||
          msg.startsWith('We’re unable') ||
          msg.startsWith("We're unable")) {
        return msg;
      }
    }

    return genericMessage;
  }

  /// Login-specific copy (client-facing). Never includes implementation details.
  static String mapLogin(Object error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.badResponse:
          return mapLoginStatusCode(error.response?.statusCode);
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.transformTimeout:
        case DioExceptionType.connectionError:
        case DioExceptionType.badCertificate:
        case DioExceptionType.unknown:
          return loginNoInternetMessage;
        case DioExceptionType.cancel:
          return loginServerUnavailableMessage;
      }
    }
    return loginServerUnavailableMessage;
  }

  static String mapLoginStatusCode(int? statusCode) {
    switch (statusCode) {
      case 401:
        return loginInvalidCredentialsMessage;
      case 403:
        // Treat forbidden login the same as invalid credentials for clients.
        return loginInvalidCredentialsMessage;
      case 429:
        return loginTooManyAttemptsMessage;
      case 500:
      case 502:
      case 503:
        return loginServerUnavailableMessage;
      default:
        return loginServerUnavailableMessage;
    }
  }

  static String mapStatusCode(int? statusCode) {
    switch (statusCode) {
      case 401:
        return loginSessionExpiredMessage;
      case 403:
        return 'This action is not authorized.';
      case 404:
        return 'The requested item is unavailable.';
      case 409:
        return 'This information changed on another device or in the client portal. Please review and try again.';
      case 422:
        return 'Some information could not be validated. Please check your entries and try again.';
      case 429:
        return 'Too many requests — wait a moment and try again.';
      case 500:
        return loginServerUnavailableMessage;
      case 503:
        return loginServerUnavailableMessage;
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
        return loginNoInternetMessage;
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
    }
  }

  static const String genericMessage = 'Something went wrong. Please try again.';

  static const String connectionProblemMessage = loginNoInternetMessage;

  static const String loginInvalidCredentialsMessage =
      'The email or password you entered is incorrect.';

  static const String loginServerUnavailableMessage =
      'We’re unable to sign you in right now. Please try again later.';

  static const String loginNoInternetMessage =
      'Please check your internet connection and try again.';

  static const String loginTooManyAttemptsMessage =
      'Too many sign-in attempts. Please wait and try again.';

  static const String loginSessionExpiredMessage =
      'Your session has expired. Please sign in again.';
}
