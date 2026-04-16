import 'package:injectable/injectable.dart';
import '../../domain/repositories/payment_repository.dart';
import '../datasources/payment_remote_data_source.dart';

@LazySingleton(as: PaymentRepository)
class PaymentRepositoryImpl implements PaymentRepository {
  final PaymentRemoteDataSource _remoteDataSource;

  PaymentRepositoryImpl(this._remoteDataSource);

  @override
  Future<void> payWithWallet(String provider, String tokenData, double amount) async {
    await _remoteDataSource.chargeToken(provider, tokenData, amount);
  }

  @override
  Future<void> payWithCard(String number, String expiryDate, String cvv, String cardHolderName, double amount) async {
    await _remoteDataSource.chargeCard(number, expiryDate, cvv, cardHolderName, amount);
  }
}
