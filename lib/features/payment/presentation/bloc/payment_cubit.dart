import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'payment_state.dart';
import '../../domain/repositories/payment_repository.dart';

@injectable
class PaymentCubit extends Cubit<PaymentState> {
  final PaymentRepository _repository;

  PaymentCubit(this._repository) : super(const PaymentInitial());

  /// Process Apple Pay / Google Pay result cleanly
  Future<void> processWalletPayment(String provider, Map<String, dynamic> paymentResult, double amount) async {
    emit(const PaymentProcessing());
    try {
      // paymentResult contains securely retrieved tokenization data 
      // encoded as JSON. Stringify it safely for the backend pipeline.
      final tokenData = jsonEncode(paymentResult);
      
      await _repository.payWithWallet(provider, tokenData, amount);
      emit(const PaymentSuccess());
    } catch (e) {
      emit(PaymentFailure(e.toString()));
    }
  }

  /// Process standard Credit Card inputs safely
  Future<void> processCardPayment(String number, String expiry, String cvv, String cardHolder, double amount) async {
    emit(const PaymentProcessing());
    try {
      await _repository.payWithCard(number, expiry, cvv, cardHolder, amount);
      emit(const PaymentSuccess());
    } catch (e) {
      emit(PaymentFailure(e.toString()));
    }
  }
}
