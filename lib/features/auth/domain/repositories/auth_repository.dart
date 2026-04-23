import 'package:fpdart/fpdart.dart';
import '../../../../core/error/failures.dart';

abstract class AuthRepository {
  Future<Either<Failure, void>> sendOtp(String phoneNumber);
  Future<Either<Failure, Map<String, dynamic>>> verifyOtp(String phoneNumber, String code);
  Future<Either<Failure, void>> logout();
  Future<Either<Failure, bool>> checkAuthStatus();
}
