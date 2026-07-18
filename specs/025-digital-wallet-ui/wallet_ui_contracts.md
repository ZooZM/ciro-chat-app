# Wallet UI Contracts: Digital Wallet UI (025)

**Date**: 2026-07-17
**Feature**: specs/025-digital-wallet-ui

---

## Screen Interface Contracts

### WalletHomeScreen

| Property | Value |
|----------|-------|
| Route | `/wallet` |
| Widget type | `StatefulWidget` |
| Parameters | None (data from `WalletMockData`) |
| Navigation triggers | Quick action buttons → push to respective screens; FAB → push to `/wallet/receive` |
| Preconditions | None |

---

### WalletProfileScreen

| Property | Value |
|----------|-------|
| Route | `/wallet/profile` |
| Widget type | `StatelessWidget` |
| Parameters | None (data from `WalletMockData`) |
| Navigation triggers | "View Barcode" → push to `/wallet/receive`; settings tiles → placeholder toast |
| Preconditions | None |

---

### WalletSendScreen

| Property | Value |
|----------|-------|
| Route | `/wallet/send` |
| Widget type | `StatefulWidget` |
| Parameters | None |
| Navigation triggers | Contact/recent transaction tap → push to `/wallet/add-amount` |
| Preconditions | None |
| Local state | `_searchQuery: String`, `_filteredContacts: List<WalletContact>` |

---

### WalletReceiveScreen

| Property | Value |
|----------|-------|
| Route | `/wallet/receive` |
| Widget type | `StatefulWidget` |
| Parameters | None (data from `WalletMockData`) |
| Navigation triggers | None (terminal screen within flow) |
| Preconditions | None |
| Local state | `_isBannerVisible: bool` (default `true`) |

---

### WalletAddAmountScreen

| Property | Value |
|----------|-------|
| Route | `/wallet/add-amount` |
| Widget type | `StatefulWidget` |
| Parameters | None (recipient context optional future enhancement) |
| Navigation triggers | Green next → push to `/wallet/payment-status` with `PaymentResult` as `extra` |
| Preconditions | `_amount >= 10 SAR` to proceed |
| Local state | `_amount: String` (default `'0'`), `_selectedMethod: PaymentMethod` |

---

### WalletPaymentStatusScreen

| Property | Value |
|----------|-------|
| Route | `/wallet/payment-status` |
| Widget type | `StatelessWidget` |
| Parameters | `result: PaymentResult` (required, passed via `GoRouterState.extra`) |
| Navigation triggers | "Done" → `context.go(AppRouterName.wallet)` (clears stack) |
| Preconditions | `result` must be non-null; router caller is responsible |

---

## Widget Interface Contracts

### WalletBalanceCard

```dart
WalletBalanceCard({
  required WalletBalance balance,
  required bool isVisible,
  required VoidCallback onToggleVisibility,
})
```

---

### WalletQuickActionButton

```dart
WalletQuickActionButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
})
```

---

### WalletTransactionTile

```dart
WalletTransactionTile({
  required WalletTransaction transaction,
})
```

---

### WalletContactTile

```dart
WalletContactTile({
  required WalletContact contact,
  required VoidCallback onTap,
})
```

---

### WalletNumpad

```dart
WalletNumpad({
  required void Function(String digit) onDigitTap,
  required VoidCallback onBackspace,
  required VoidCallback onNext,
})
```

---

### WalletPaymentStatusIcon

```dart
WalletPaymentStatusIcon({
  required bool isSuccess,
})
```

---

### WalletReferenceIdCard

```dart
WalletReferenceIdCard({
  required String referenceId,
})
```

---

### WalletQrCard

```dart
WalletQrCard({
  required WalletUser user,
})
```

---

## GoRouter Extra Type

```dart
// WalletPaymentStatusScreen extra payload
class PaymentResult {
  final PaymentResultStatus status;
  final double amount;
  final String currency;
  final String recipientName;     // non-null when status == success
  final String? failureReason;    // non-null when status == failed (localization key)
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
```
