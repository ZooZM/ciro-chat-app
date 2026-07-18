import 'package:flutter/material.dart';
import 'entities/wallet_entities.dart';

abstract class WalletMockData {
  static const WalletUser currentUser = WalletUser(
    displayName: 'Ahmed Hassan',
    phoneNumber: '+966 50 123 4567',
    ciroId: 'CIRO123456',
    avatarUrl: null,
    status: WalletUserStatus.verified,
    registrationDate: 'March 12, 2024',
    lastSeen: 'Today, 9:25 AM',
    country: 'Saudi Arabia',
    countryFlagAsset: 'assets/flags/sa.png',
    associatedBank: 'Al Rajhi Bank',
  );

  static const WalletBalance balance = WalletBalance(
    totalBalance: 12450.50,
    currentBalance: 12120.0,
    currency: 'SAR',
    isVisible: true,
  );

  static const List<WalletTransaction> recentTransactions = [
    WalletTransaction(
      id: 'tx_1',
      displayName: 'From Ahmed',
      avatarUrl: null,
      avatarInitials: 'AH',
      avatarColor: Color(0xFF4CA02A),
      dateLabel: 'Today, 9:30 AM',
      amount: 250.00,
      currency: 'SAR',
      direction: WalletTransactionDirection.incoming,
      typeLabel: 'Receive',
    ),
    WalletTransaction(
      id: 'tx_2',
      displayName: 'To Sara',
      avatarUrl: null,
      avatarInitials: 'SA',
      avatarColor: Color(0xFFF57C00),
      dateLabel: 'Yesterday, 2:15 PM',
      amount: -150.00,
      currency: 'SAR',
      direction: WalletTransactionDirection.outgoing,
      typeLabel: 'Send',
    ),
    WalletTransaction(
      id: 'tx_3',
      displayName: 'From Ali',
      avatarUrl: null,
      avatarInitials: 'AL',
      avatarColor: Color(0xFF1976D2),
      dateLabel: 'March 14, 10:00 AM',
      amount: 500.00,
      currency: 'SAR',
      direction: WalletTransactionDirection.incoming,
      typeLabel: 'Receive',
    ),
    WalletTransaction(
      id: 'tx_4',
      displayName: 'To Khalid',
      avatarUrl: null,
      avatarInitials: 'KH',
      avatarColor: Color(0xFF8E24AA),
      dateLabel: 'March 12, 4:45 PM',
      amount: -75.00,
      currency: 'SAR',
      direction: WalletTransactionDirection.outgoing,
      typeLabel: 'Send',
    ),
  ];

  static const List<WalletContact> suggestedContacts = [
    WalletContact(
      displayName: 'Ahmed Hassan',
      phoneNumber: '+966 50 111 2222',
      ciroId: 'CIRO987654',
    ),
    WalletContact(
      displayName: 'Sara Khalid',
      phoneNumber: '+966 50 333 4444',
      ciroId: 'CIRO345678',
    ),
    WalletContact(
      displayName: 'Mohamed Ali',
      phoneNumber: '+966 50 555 6666',
      ciroId: 'CIRO112233',
    ),
  ];

  static const List<WalletTransaction> recentSendTransactions = [
    WalletTransaction(
      id: 's_tx_1',
      displayName: 'Ahmed Hassan',
      avatarUrl: null,
      avatarInitials: 'AH',
      avatarColor: Color(0xFF4CA02A),
      dateLabel: 'Today, 9:30 AM',
      amount: -250.00,
      currency: 'SAR',
      direction: WalletTransactionDirection.outgoing,
      typeLabel: 'Send',
    ),
    WalletTransaction(
      id: 's_tx_2',
      displayName: 'Osama Mohamed',
      avatarUrl: null,
      avatarInitials: 'OM',
      avatarColor: Color(0xFF1976D2),
      dateLabel: 'Yesterday, 2:15 PM',
      amount: -150.00,
      currency: 'SAR',
      direction: WalletTransactionDirection.outgoing,
      typeLabel: 'Send',
    ),
    WalletTransaction(
      id: 's_tx_3',
      displayName: 'Mohamed Ali',
      avatarUrl: null,
      avatarInitials: 'MA',
      avatarColor: Color(0xFFF57C00),
      dateLabel: 'March 14, 10:00 AM',
      amount: -500.00,
      currency: 'SAR',
      direction: WalletTransactionDirection.outgoing,
      typeLabel: 'Send',
    ),
  ];

  static const PaymentMethod defaultPaymentMethod = PaymentMethod(
    type: PaymentMethodType.applePay,
    displayName: 'Apple Pay',
    logoAsset: null, // Will use text or generic icon if logo is null
  );

  static const List<WalletNotification> notifications = [
    WalletNotification(
      id: 'notif_1',
      title: 'Payment Received',
      message: 'You have received 250.00 SAR from Ahmed Hassan.',
      time: 'Today, 9:30 AM',
      isRead: false,
    ),
    WalletNotification(
      id: 'notif_2',
      title: 'Account Verified',
      message: 'Your account has been successfully verified.',
      time: 'Yesterday, 10:00 AM',
      isRead: true,
    ),
    WalletNotification(
      id: 'notif_3',
      title: 'Payment Sent',
      message: 'You sent 150.00 SAR to Sara.',
      time: 'Yesterday, 8:30 AM',
      isRead: true,
    ),
  ];
}
