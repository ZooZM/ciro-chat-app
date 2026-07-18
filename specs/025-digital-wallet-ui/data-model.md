# Data Model: Digital Wallet UI (025)

**Feature**: Digital Wallet UI
**Date**: 2026-07-17
**Phase**: Phase 1 — Design & Contracts

---

## Overview

All entities are **mock-only** — no persistence, no API. They are defined as Dart `class` or `enum` in `lib/features/payment/presentation/` and consumed directly by widgets via a `WalletMockData` helper. No `Either<Failure, T>` or `Repository` patterns are needed because there are no real data sources in this spec.

---

## Entities

### 1. WalletUser

Represents the authenticated wallet account holder displayed across Main, Profile, and Receive screens.

```
WalletUser {
  String  displayName       // e.g. "Ahmed Hassan"
  String  phoneNumber       // e.g. "+966 50 123 4567"
  String  ciroId            // e.g. "CIRO123456"
  String? avatarUrl         // remote URL — rendered via CachedNetworkImage; null uses initials fallback
  WalletUserStatus status   // Verified | Pending
  String  registrationDate  // formatted display string: "March 12, 2024"
  String  lastSeen          // formatted display string: "Today, 9:25 AM"
  String  country           // display name: "Saudi Arabia"
  String  countryFlagAsset  // path under assets/: "assets/flags/sa.png"
  String  associatedBank    // e.g. "Al Rajhi Bank"
}
```

**State transitions**: None (display-only).
**Validation rules**: None (mock).

---

### 2. WalletUserStatus (enum)

```
enum WalletUserStatus { verified, pending }
```

- `verified` → green badge, "Verified" label
- `pending`  → amber badge, "Pending" label

---

### 3. WalletTransaction

Represents a single line in the Recent Transaction list on the Main Wallet and Send Money screens.

```
WalletTransaction {
  String  id              // unique mock ID
  String  displayName     // "From Ahmed" / "To Sara"
  String? avatarUrl       // circular avatar; null → colored initials circle
  String  avatarInitials  // fallback: "AH"
  Color   avatarColor     // fallback background color when no avatar
  String  dateLabel       // "Today, 9:30 AM"
  double  amount          // positive = incoming, negative = outgoing
  String  currency        // always "SAR" for this spec
  WalletTransactionDirection direction
  String  typeLabel       // "Send" (shown in green on Send Money screen)
}
```

**amount sign convention**: positive → rendered green with "+" prefix; negative → rendered `AppColors.textPrimary` with "-" prefix.

---

### 4. WalletTransactionDirection (enum)

```
enum WalletTransactionDirection { incoming, outgoing }
```

---

### 5. WalletContact

Represents a payable contact on the Send Money screen.

```
WalletContact {
  String  displayName   // e.g. "Ahmed Hassan"
  String  phoneNumber   // e.g. "+966 50 123 4567"
  String  ciroId        // e.g. "CIRO0123456"
  String? avatarUrl     // circular avatar; null → initials fallback
}
```

**Search fields**: `displayName`, `phoneNumber`, `ciroId` — all searched case-insensitively.

---

### 6. WalletBalance

Represents the balance card data on the Main Wallet screen.

```
WalletBalance {
  double  totalBalance    // e.g. 12450.50
  double  currentBalance  // e.g. 12120.0
  String  currency        // "SAR"
  bool    isVisible       // toggled by eye icon; false → display "••••"
}
```

---

### 7. PaymentMethod

Represents a funding source shown on the Add Amount screen.

```
PaymentMethod {
  PaymentMethodType type
  String            displayName   // "Apple Pay"
  String?           logoAsset     // "assets/icons/apple_pay.svg"
}

enum PaymentMethodType { applePay, googlePay, creditCard, bankTransfer }
```

---

### 8. PaymentResult

Parameter passed into `WalletPaymentStatusScreen` to drive its Success or Failed rendering.

```
PaymentResult {
  PaymentResultStatus status
  double              amount        // e.g. 150.0
  String              currency      // "SAR"
  String              recipientName // "Ahmed" (Success state)
  String?             failureReason // "Insufficient balance" (Failed state — localized key)
  String              referenceId   // "CIRO-938475"
}

enum PaymentResultStatus { success, failed }
```

**Validation**: `failureReason` MUST be non-null when `status == failed`. `recipientName` MUST be non-null when `status == success`.

---

## Mock Data Source

File: `lib/features/payment/presentation/wallet_mock_data.dart`

```dart
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

  static const List<WalletTransaction> recentTransactions = [...];  // 4 items

  static const List<WalletContact> suggestedContacts = [...];        // 3 items

  static const List<WalletTransaction> recentSendTransactions = [...]; // 3 items

  static const PaymentMethod defaultPaymentMethod = PaymentMethod(
    type: PaymentMethodType.applePay,
    displayName: 'Apple Pay',
    logoAsset: 'assets/icons/apple_pay.svg',
  );
}
```

---

## State Variables (per screen)

### WalletHomeScreen (StatefulWidget)
| Variable | Type | Description |
|----------|------|-------------|
| `_isBalanceVisible` | `bool` | Eye toggle; default `true` |

### WalletSendScreen (StatefulWidget)
| Variable | Type | Description |
|----------|------|-------------|
| `_searchQuery` | `String` | Drives contact list filter |
| `_filteredContacts` | `List<WalletContact>` | Derived from mock data + query |

### WalletAddAmountScreen (StatefulWidget)
| Variable | Type | Description |
|----------|------|-------------|
| `_amount` | `String` | Numpad input buffer, starts at "0" |
| `_selectedMethod` | `PaymentMethod` | Currently selected payment method |

### WalletPaymentStatusScreen (StatelessWidget)
| Variable | Type | Description |
|----------|------|-------------|
| `result` | `PaymentResult` | Passed via GoRouter `extra`; drives Success/Failed rendering |

---

## Entity Relationships

```
WalletHomeScreen
  └─ WalletUser (header avatar)
  └─ WalletBalance (balance card)
  └─ List<WalletTransaction> (recent list)

WalletProfileScreen
  └─ WalletUser (all fields)

WalletSendScreen
  └─ List<WalletContact> (suggested, filtered)
  └─ List<WalletTransaction> (recent send history)

WalletReceiveScreen
  └─ WalletUser (QR, name, ciroId)

WalletAddAmountScreen
  └─ PaymentMethod (selected method)
  └─ _amount: String (local state)

WalletPaymentStatusScreen
  └─ PaymentResult (status, amount, recipient, reason, referenceId)
```
