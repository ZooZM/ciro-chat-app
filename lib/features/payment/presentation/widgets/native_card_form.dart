import 'package:flutter/material.dart';
import 'package:ciro_chat_app/core/helpers/responsive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_credit_card/flutter_credit_card.dart';
import '../bloc/payment_cubit.dart';
import '../bloc/payment_state.dart';

class NativeCardForm extends StatefulWidget {
  final double amount;
  
  const NativeCardForm({super.key, required this.amount});

  @override
  State<NativeCardForm> createState() => _NativeCardFormState();
}

class _NativeCardFormState extends State<NativeCardForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  String _cardNumber = '';
  String _expiryDate = '';
  String _cardHolderName = '';
  String _cvvCode = '';
  bool _isCvvFocused = false;

  void _onCreditCardModelChange(CreditCardModel data) {
    setState(() {
      _cardNumber = data.cardNumber;
      _expiryDate = data.expiryDate;
      _cardHolderName = data.cardHolderName;
      _cvvCode = data.cvvCode;
      _isCvvFocused = data.isCvvFocused;
    });
  }

  void _submitPayment() {
    if (_formKey.currentState!.validate()) {
      // Trigger API interaction securely
      context.read<PaymentCubit>().processCardPayment(
        _cardNumber,
        _expiryDate,
        _cvvCode,
        _cardHolderName,
        widget.amount,
      );

      // CRITICAL SECURITY RULE: Overwrite sensitive fields to ensure immediate memory safety locally.
      setState(() {
        _cardNumber = '';
        _expiryDate = '';
        _cardHolderName = '';
        _cvvCode = '';
        _isCvvFocused = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<PaymentCubit, PaymentState>(
      listener: (context, state) {
        if (state is PaymentFailure) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.error), backgroundColor: Colors.red));
        } else if (state is PaymentSuccess) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment Successful!'), backgroundColor: Colors.green));
        }
      },
      builder: (context, state) {
        if (state is PaymentProcessing) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            CreditCardWidget(
              cardNumber: _cardNumber,
              expiryDate: _expiryDate,
              cardHolderName: _cardHolderName,
              cvvCode: _cvvCode,
              showBackView: _isCvvFocused,
              onCreditCardWidgetChange: (CreditCardBrand brand) {},
              isHolderNameVisible: true,
              obscureCardNumber: true,
              obscureCardCvv: true,
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    CreditCardForm(
                      formKey: _formKey,
                      cardNumber: _cardNumber,
                      expiryDate: _expiryDate,
                      cardHolderName: _cardHolderName,
                      cvvCode: _cvvCode,
                      onCreditCardModelChange: _onCreditCardModelChange,
                      obscureCvv: true,
                      obscureNumber: true,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      onPressed: _cardNumber.isNotEmpty && _cvvCode.isNotEmpty ? _submitPayment : null,
                      child: Text('Pay \$${widget.amount}', style: const TextStyle(color: Colors.white, fontSize: 16)),
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
