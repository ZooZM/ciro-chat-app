import 'package:dio/dio.dart';
import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  ServerFailure(super.failurMsg);

  factory ServerFailure.fromDioException(DioException dioException) {
    // Ensure dioException.message is not null before using the null check operator
    final message = dioException.message ?? 'Unknown error';

    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
        return ServerFailure('Connection Timeout, please try again later');

      case DioExceptionType.sendTimeout:
        return ServerFailure('Send Timeout, please try again later');

      case DioExceptionType.receiveTimeout:
        return ServerFailure('Receive Timeout, please try again later');

      case DioExceptionType.badCertificate:
        return ServerFailure('Something happened, please try again later');

      case DioExceptionType.badResponse:
        return ServerFailure.fromResponse(
          dioException.response?.statusCode,
          dioException.response,
        );

      case DioExceptionType.cancel:
        return ServerFailure('Request was cancelled');

      case DioExceptionType.connectionError:
        return ServerFailure('Connection Error, please try again later');

      case DioExceptionType.unknown:
        if (message.contains('SocketException')) {
          return ServerFailure('No Internet Connection');
        }
        return ServerFailure('There was an Error, please try again later');
    }
  }

  factory ServerFailure.fromResponse(int? statusCode, dynamic response) {
    final dynamic responseData = response is Response
        ? response.data
        : response;

    if (statusCode == 400 || statusCode == 401 || statusCode == 403) {
      String? message;
      if (responseData is Map<String, dynamic>) {
        final dynamic raw = responseData['message'] ??
            (responseData['error'] is Map
                ? responseData['error']['message']
                : null);
        if (raw is String) {
          message = raw;
        } else if (raw is List) {
          message = raw.map((e) => e.toString()).join('\n');
        }
      }
      return ServerFailure(message ?? 'Unknown error');
    } else if (statusCode == 404) {
      return ServerFailure('Error 404: Your request not Found');
    } else {
      return ServerFailure('There was an Error, please try again later');
    }
  }
}

class VerificationFailure extends Failure {
  final String email;

  const VerificationFailure(this.email) : super('');
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No Internet Connection']);
}

class AuthFailure extends Failure {
  const AuthFailure(super.message);
}
