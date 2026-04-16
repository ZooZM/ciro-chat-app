abstract class PaymentRepository {
  Future<void> payWithWallet(String provider, String tokenData, double amount);
  Future<void> payWithCard(String number, String expiryDate, String cvv, String cardHolderName, double amount);
}
