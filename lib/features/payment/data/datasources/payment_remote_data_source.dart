import 'package:injectable/injectable.dart';
import '../../../../core/network/dio_client.dart';

abstract class PaymentRemoteDataSource {
  Future<void> chargeToken(String provider, String tokenData, double amount);
  Future<void> chargeCard(String number, String expiryDate, String cvv, String cardHolderName, double amount);
}

@LazySingleton(as: PaymentRemoteDataSource)
class PaymentRemoteDataSourceImpl implements PaymentRemoteDataSource {
  final DioClient _dioClient;

  PaymentRemoteDataSourceImpl(this._dioClient);

  @override
  Future<void> chargeToken(String provider, String tokenData, double amount) async {
    await _dioClient.dio.post('/payment/charge', data: {
      'method': 'wallet',
      'provider': provider, // 'apple_pay' or 'google_pay'
      'token': tokenData,
      'amount': amount,
    });
  }

  @override
  Future<void> chargeCard(String number, String expiryDate, String cvv, String cardHolderName, double amount) async {
    // SECURITY NOTE: We format the payload rigorously before transmitting
    await _dioClient.dio.post('/payment/charge', data: {
      'method': 'card',
      'cardNumber': number.replaceAll(' ', ''),
      'expiryDate': expiryDate,
      'cvv': cvv,
      'cardHolder': cardHolderName,
      'amount': amount,
    });
  }
}
