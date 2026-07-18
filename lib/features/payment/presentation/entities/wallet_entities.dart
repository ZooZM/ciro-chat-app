import 'package:flutter/material.dart';

enum WalletUserStatus { verified, pending }

enum WalletTransactionDirection { incoming, outgoing }

enum PaymentMethodType { applePay, googlePay, creditCard, bankTransfer }

enum PaymentResultStatus { success, failed }

class WalletUser {
  final String displayName;
  final String phoneNumber;
  final String ciroId;
  final String? avatarUrl;
  final WalletUserStatus status;
  final String registrationDate;
  final String lastSeen;
  final String country;
  final String countryFlagAsset;
  final String associatedBank;

  const WalletUser({
    required this.displayName,
    required this.phoneNumber,
    required this.ciroId,
    this.avatarUrl,
    required this.status,
    required this.registrationDate,
    required this.lastSeen,
    required this.country,
    required this.countryFlagAsset,
    required this.associatedBank,
  });
}

class WalletBalance {
  final double totalBalance;
  final double currentBalance;
  final String currency;
  final bool isVisible;

  const WalletBalance({
    required this.totalBalance,
    required this.currentBalance,
    required this.currency,
    required this.isVisible,
  });
}

class WalletTransaction {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String avatarInitials;
  final Color avatarColor;
  final String dateLabel;
  final double amount;
  final String currency;
  final WalletTransactionDirection direction;
  final String typeLabel;

  const WalletTransaction({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    required this.avatarInitials,
    required this.avatarColor,
    required this.dateLabel,
    required this.amount,
    required this.currency,
    required this.direction,
    required this.typeLabel,
  });
}

class WalletContact {
  final String displayName;
  final String phoneNumber;
  final String ciroId;
  final String? avatarUrl;

  const WalletContact({
    required this.displayName,
    required this.phoneNumber,
    required this.ciroId,
    this.avatarUrl,
  });
}

class PaymentMethod {
  final PaymentMethodType type;
  final String displayName;
  final String? logoAsset;

  const PaymentMethod({
    required this.type,
    required this.displayName,
    this.logoAsset,
  });
}

class WalletNotification {
  final String id;
  final String title;
  final String message;
  final String time;
  final bool isRead;

  const WalletNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.time,
    this.isRead = false,
  });
}

class PaymentResult {
  final PaymentResultStatus status;
  final double amount;
  final String currency;
  final String recipientName;
  final String? failureReason;
  final String referenceId;

  const PaymentResult({
    required this.status,
    required this.amount,
    required this.currency,
    required this.recipientName,
    this.failureReason,
    required this.referenceId,
  });
}
