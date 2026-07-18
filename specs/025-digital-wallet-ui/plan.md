# Implementation Plan: Digital Wallet UI (025)

**Branch**: `025-digital-wallet-ui` | **Date**: 2026-07-17 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/025-digital-wallet-ui/spec.md`

---

## Summary

Build a complete **Digital Wallet UI** within the existing `payment` feature module. The feature delivers 6 screens: Main Wallet, Wallet Profile, Send Money, Receive Money, Add Amount (custom numpad), and a reusable Payment Status screen (Success/Failed). All screens are **UI and mock data only** — no real payment gateway, no database, no complex state management. All text uses `easy_localization` dot-notation keys. Styling is anchored to the brand green (`AppColors.primary`) with a green-to-blue gradient balance card, a custom 12-key numpad, and a confetti-decorated payment status screen.

---

## Technical Context

**Language/Version**: Dart / Flutter (existing project, SDK ^3.9.2)
**Primary Dependencies**: `easy_localization ^3.0.8`, `go_router ^17.2.0`, `qr_flutter ^4.1.0`, `share_plus ^11.0.0`, `gal ^2.3.0` — all already in `pubspec.yaml`
**Storage**: N/A (mock data only, `WalletMockData` constants)
**Testing**: Manual widget inspection per Verification Plan
**Target Platform**: iOS and Android mobile
**Project Type**: Mobile app (Flutter)
**Performance Goals**: 60 fps UI, < 1 frame numpad input latency
**Constraints**: No new `pubspec.yaml` dependencies; pure UI, `StatefulWidget`+`setState` only
**Scale/Scope**: 6 new page files, 10+ new widget files, 1 mock data file, 1 entity file, 57 new translation keys

---

## Constitution Check

- [x] **I. Clean Architecture**: UI-only. All new files in `presentation/pages/` and `presentation/widgets/`. No domain or data layer additions beyond mock entity definitions.
- [x] **II. State Management**: No Cubit/Bloc — spec explicitly forbids it. `StatefulWidget` + `setState` for balance toggle, numpad input, search query.
- [x] **III. Offline-First**: N/A — no data persistence.
- [x] **IV. Socket.io**: N/A — no real-time communication.
- [x] **V. Teardown**: All `TextEditingController` instances disposed in `dispose()`. No stream subscriptions.
- [x] **Code Quality**: `snake_case` files, `PascalCase` classes, `const` constructors, `AppColors` tokens used throughout.
- [x] **Error Handling**: N/A — no network calls. Input validation (minimum amount) shown inline.

---

## Project Structure

### New Files

```
lib/features/payment/presentation/
    wallet_mock_data.dart                       [NEW] Mock data constants
    entities/
        wallet_entities.dart                    [NEW] All wallet entity classes & enums
    pages/
        wallet_home_screen.dart                 [NEW] Screen 1 — Main Wallet
        wallet_profile_screen.dart              [NEW] Screen 2 — Wallet Profile
        wallet_send_screen.dart                 [NEW] Screen 3 — Send Money
        wallet_receive_screen.dart              [NEW] Screen 4 — Receive Money
        wallet_add_amount_screen.dart           [NEW] Screen 5 — Add Amount (Numpad)
        wallet_payment_status_screen.dart       [NEW] Screen 6 — Payment Status (reusable)
    widgets/
        wallet_balance_card.dart                [NEW] Gradient balance card
        wallet_quick_action_button.dart         [NEW] Add/Send/Receive/QR action tile
        wallet_transaction_tile.dart            [NEW] Recent transaction list item
        wallet_profile_info_card.dart           [NEW] Key-value info card rows
        wallet_barcode_action_card.dart         [NEW] Share/View barcode card
        wallet_settings_tile.dart               [NEW] Settings row with icon+arrow
        wallet_contact_tile.dart                [NEW] Suggested contact list item
        wallet_send_transaction_tile.dart       [NEW] Recent send transaction item
        wallet_qr_card.dart                     [NEW] QR code + security info card
        wallet_numpad.dart                      [NEW] Custom 12-key dialpad
        wallet_payment_status_icon.dart         [NEW] Confetti + status icon widget
        wallet_reference_id_card.dart           [NEW] Reference ID card

specs/025-digital-wallet-ui/
    wallet_ui_contracts.md                      [NEW] UI contract (screen interface spec)
```

### Modified Files

```
lib/core/routing/app_router.dart               [MODIFY] Add 6 wallet route constants + GoRoute entries
lib/core/theme/app_colors.dart                 [MODIFY] Add walletGradientEnd color token
assets/translations/en.json                    [MODIFY] Add "wallet" key block (57 keys)
assets/translations/ar.json                    [MODIFY] Add "wallet" key block (57 Arabic keys)
```

---

## Phase 1: Detailed Component Design

### Entity File

**File**: `lib/features/payment/presentation/entities/wallet_entities.dart`

Defines:
- `WalletUserStatus` enum (`verified`, `pending`)
- `WalletTransactionDirection` enum (`incoming`, `outgoing`)
- `PaymentMethodType` enum (`applePay`, `googlePay`, `creditCard`, `bankTransfer`)
- `PaymentResultStatus` enum (`success`, `failed`)
- `WalletUser` class (immutable, `const` constructor)
- `WalletBalance` class (immutable)
- `WalletTransaction` class (immutable)
- `WalletContact` class (immutable)
- `PaymentMethod` class (immutable)
- `PaymentResult` class (immutable)

---

### Mock Data File

**File**: `lib/features/payment/presentation/wallet_mock_data.dart`

`abstract class WalletMockData` with static `const` fields:
- `currentUser` — WalletUser (Ahmed Hassan, verified)
- `balance` — WalletBalance (12,450.50 SAR total, 12,120 SAR current)
- `recentTransactions` — 4 transactions: +250 From Ahmed, -150 To Sara, +500 From Ali, -75 To Khalid
- `suggestedContacts` — 3 contacts: Ahmed Hassan, (unnamed), Mohamed Ali
- `recentSendTransactions` — 3 send records: AH -250, OM -150, MA -500
- `defaultPaymentMethod` — Apple Pay

---

### Widget 1: WalletBalanceCard

**File**: `lib/features/payment/presentation/widgets/wallet_balance_card.dart`

StatelessWidget. Parameters:
- `balance`: WalletBalance
- `isVisible`: bool
- `onToggleVisibility`: VoidCallback

Layout:
- `Container` with `LinearGradient(colors: [AppColors.primary, AppColors.walletGradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight)`, `borderRadius: BorderRadius.circular(16)`, padding `EdgeInsets.all(20)`
- Row: "Total Balance" text (white 14sp) + `Spacer` + `IconButton(Icons.remove_red_eye_outlined)` (white)
- Amount row: `isVisible ? '12,450.50 SAR' : '•••• SAR'` — white 28sp bold
- `DashedDivider` widget (custom: `Row` of `Containers` alternating 8px gap with 4px filled)
- "Current Balance" label (white 13sp) + amount (white 20sp bold)

---

### Widget 2: WalletQuickActionButton

**File**: `lib/features/payment/presentation/widgets/wallet_quick_action_button.dart`

StatelessWidget. Parameters: `icon`, `label`, `onTap`.

Layout:
- `GestureDetector` wrapping `Container(width: 80, height: 80, decoration: BoxDecoration(color: white, borderRadius: 16, boxShadow: [light grey]))`
- Centered `Column`: `Icon(icon, color: AppColors.primary, size: 28)` + `SizedBox(height: 6)` + `Text(label, style: 12sp textPrimary)`

---

### Widget 3: WalletTransactionTile

**File**: `lib/features/payment/presentation/widgets/wallet_transaction_tile.dart`

StatelessWidget. Parameter: `transaction`: WalletTransaction.

Layout (ListTile-equivalent using Row):
- Leading: 48dp circular `CachedNetworkImage` or initials `CircleAvatar(backgroundColor: transaction.avatarColor)`
- Middle Column: `Text(displayName)` 14sp w500 + `Text(dateLabel)` 12sp grey
- Trailing: `Text(amount)` — green if incoming, textPrimary if outgoing; amount formatted as `+250.00 SAR` / `-150.00 SAR`

---

### Widget 4: WalletProfileInfoCard

**File**: `lib/features/payment/presentation/widgets/wallet_profile_info_card.dart`

StatelessWidget. Renders a rounded border container with divider-separated `_InfoRow` widgets.

`_InfoRow` parameters: `label`, `value`, `trailing` (Widget? — for copy icon, flag image, or verified badge).

Rows rendered:
1. Ciro ID — value + `IconButton(Icons.copy_outlined)`
2. Status — "Verified" + green `Icon(Icons.check_circle, color: AppColors.primary)`
3. Registration Date — text value
4. Last Seen — text value
5. Country — "Saudi Arabia" + `Image.asset(flagAsset, width: 24)`
6. Associated Bank — value + `IconButton(Icons.copy_outlined)`

---

### Widget 5: WalletBarcodeActionCard

**File**: `lib/features/payment/presentation/widgets/wallet_barcode_action_card.dart`

StatelessWidget. Parameters: `icon`, `title`, `subtitle`, `onTap`.

Layout: `GestureDetector` → `Container(border: rounded, padding: 12)` → Row with icon container (48dp, grey bg, borderRadius 12) + Column(title bold + subtitle grey)

---

### Widget 6: WalletSettingsTile

**File**: `lib/features/payment/presentation/widgets/wallet_settings_tile.dart`

StatelessWidget. Parameters: `icon`, `label`, `onTap`.

Renders a `ListTile` with `leading: Icon(icon)`, `title: Text(label)`, `trailing: Icon(Icons.chevron_right)`.

---

### Widget 7: WalletContactTile

**File**: `lib/features/payment/presentation/widgets/wallet_contact_tile.dart`

StatelessWidget. Parameter: `contact`: WalletContact, `onTap`.

Layout: 48dp circular avatar → Column(displayName 14sp w500, phoneNumber 12sp grey, ciroId 12sp grey) → `Icon(Icons.chevron_right)`

---

### Widget 8: WalletSendTransactionTile

**File**: `lib/features/payment/presentation/widgets/wallet_send_transaction_tile.dart`

StatelessWidget. Parameter: `transaction`: WalletTransaction, `onTap`.

Layout: 48dp `CircleAvatar(backgroundColor: avatarColor)` with bold white initials → Column(displayName, "Send" green label 12sp, dateLabel grey) → "-250.00 SAR" + chevron

---

### Widget 9: WalletQrCard

**File**: `lib/features/payment/presentation/widgets/wallet_qr_card.dart`

StatelessWidget. Parameter: `user`: WalletUser.

Layout: Rounded container → Column:
1. 64dp avatar with verified badge
2. `Text(user.displayName)` 18sp bold
3. Row: "Ciro ID: " + `Text(ciroId, color: AppColors.primary)` + `IconButton(Icons.copy_outlined)`
4. `QrImageView(data: user.ciroId, size: 200, embeddedImage: AssetImage('assets/AppLogo.png'), embeddedImageStyle: QrEmbeddedImageStyle(size: Size(40, 40)))`
5. Row: `Icon(Icons.security, color: AppColors.primary)` + Column("Secure payments" bold + desc grey)
6. Refresh banner: light green bg container, `Icon(Icons.refresh, color: AppColors.primary)` + `RichText`("The code refreshes automatically every **60** seconds")

---

### Widget 10: WalletNumpad

**File**: `lib/features/payment/presentation/widgets/wallet_numpad.dart`

StatelessWidget. Parameters: `onDigitTap(String digit)`, `onBackspace()`, `onNext()`.

Layout: `GridView` (3 columns, shrinkWrap, physics: NeverScrollableScrollPhysics):
- Rows 1-3: digits 1-9, each in a white container (radius 12, shadow)
- Row 4: backspace (grey #F0F0F0 bg) | 0 | green arrow button

Key widget: `_NumpadKey(StatelessWidget)` → `GestureDetector` + `Container` + centered content.
Green next key: spans full cell, `Icon(Icons.arrow_forward_rounded, color: white)`, `color: AppColors.primary`.
Backspace key: `Icon(Icons.backspace_outlined, size: 22, color: AppColors.textPrimary)`.

---

### Widget 11: WalletPaymentStatusIcon

**File**: `lib/features/payment/presentation/widgets/wallet_payment_status_icon.dart`

StatelessWidget. Parameters: `isSuccess`: bool.

Layout: `SizedBox(width: 200, height: 200)` with `Stack`:
- `CustomPaint(painter: _ConfettiPainter())` — draws 20 static colored dots at fixed angles/distances around center
- Centered: `Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: isSuccess ? AppColors.primary : AppColors.error, boxShadow: [spread shadow same color at 0.3 opacity]))` + centered `Icon(isSuccess ? Icons.check_rounded : Icons.close_rounded, color: white, size: 52)`

`_ConfettiPainter`: `CustomPainter` with predefined list of dot positions (polar coords converted to cartesian), colors cycling through [green, blue, yellow, pink, orange, purple].

---

### Widget 12: WalletReferenceIdCard

**File**: `lib/features/payment/presentation/widgets/wallet_reference_id_card.dart`

StatelessWidget. Parameter: `referenceId`: String.

Layout: Rounded border `Container` → Column: 48dp icon container (light green bg, `Icons.receipt_long`) + `Text('wallet.payment.referenceId'.tr(), 12sp grey)` + `Text(referenceId, 16sp bold)`

---

### Screen 1: WalletHomeScreen

**File**: `lib/features/payment/presentation/pages/wallet_home_screen.dart`

StatefulWidget. State: `_isBalanceVisible = true`.

```
Scaffold(
  backgroundColor: AppColors.background,
  appBar: _WalletAppBar (custom widget: ciro wallet logo centered, bell icon + avatar trailing),
  body: SingleChildScrollView(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Column([
      SizedBox(h:16),
      WalletBalanceCard(balance: WalletMockData.balance, isVisible: _isBalanceVisible, onToggleVisibility: () => setState(() => _isBalanceVisible = !_isBalanceVisible)),
      SizedBox(h:24),
      Row(quick actions: AddMoney → walletAddAmount, Send → walletSend, Receive → walletReceive, QrCode → walletReceive),
      SizedBox(h:24),
      Row(Text('wallet.recentTransactions'.tr()) + Spacer + TextButton('wallet.viewAll'.tr())),
      SizedBox(h:8),
      Card(child: Column(WalletMockData.recentTransactions.map(WalletTransactionTile))),
      SizedBox(h:80), // FAB clearance
    ]),
  ),
  floatingActionButton: FloatingActionButton(
    backgroundColor: AppColors.primary,
    child: Icon(Icons.qr_code_scanner, color: white),
    onPressed: () => context.push(AppRouterName.walletReceive),
  ),
  floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
)
```

---

### Screen 2: WalletProfileScreen

**File**: `lib/features/payment/presentation/pages/wallet_profile_screen.dart`

StatelessWidget.

```
Scaffold(
  appBar: AppBar(
    title: Text('wallet.profile.title'.tr()),
    actions: [IconButton(trash), IconButton(edit)],
  ),
  body: SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: Column([
      _ProfileHeader(user: WalletMockData.currentUser),    // avatar + badge + name + phone
      SizedBox(h:16),
      WalletProfileInfoCard(user: WalletMockData.currentUser),
      SizedBox(h:16),
      Row(
        WalletBarcodeActionCard(share, onTap: shareAction),
        SizedBox(w:12),
        WalletBarcodeActionCard(view, onTap: () => context.push(walletReceive)),
      ),
      SizedBox(h:24),
      Text('wallet.profile.settings'.tr(), 14sp bold textSecondary),
      SizedBox(h:8),
      Card(child: Column([
        WalletSettingsTile(Icons.person_outline, 'wallet.profile.accountInfo'.tr()),
        Divider(),
        WalletSettingsTile(Icons.shield_outlined, 'wallet.profile.verificationSecurity'.tr()),
        Divider(),
        WalletSettingsTile(Icons.credit_card_outlined, 'wallet.profile.paymentMethod'.tr()),
        Divider(),
        WalletSettingsTile(Icons.notifications_outlined, 'wallet.profile.notification'.tr()),
      ])),
    ]),
  ),
)
```

---

### Screen 3: WalletSendScreen

**File**: `lib/features/payment/presentation/pages/wallet_send_screen.dart`

StatefulWidget. State: `_searchQuery = ''`, `_filteredContacts = WalletMockData.suggestedContacts`.

```
Scaffold(
  appBar: AppBar(title: Text('wallet.send.title'.tr())),
  body: SingleChildScrollView(
    child: Column([
      Padding(SearchBar with TextField, onChanged: _onSearchChanged),
      SizedBox(h:16),
      Row(3 action shortcut buttons: Contact Ciro, Scan QR, Upload QR),
      SizedBox(h:16),
      Text('wallet.send.suggestedPeople'.tr(), bold),
      Card(child: Column(filteredContacts.isEmpty ? EmptyState : filteredContacts.map(WalletContactTile(onTap: () => context.push(walletAddAmount))))),
      SizedBox(h:16),
      Text('wallet.send.recentTransaction'.tr(), bold),
      Card(child: Column(WalletMockData.recentSendTransactions.map(WalletSendTransactionTile))),
    ]),
  ),
)

void _onSearchChanged(String q) {
  setState(() {
    _searchQuery = q;
    _filteredContacts = q.isEmpty
      ? WalletMockData.suggestedContacts
      : WalletMockData.suggestedContacts.where((c) =>
          c.displayName.toLowerCase().contains(q.toLowerCase()) ||
          c.phoneNumber.contains(q) ||
          c.ciroId.toLowerCase().contains(q.toLowerCase())
        ).toList();
  });
}
```

---

### Screen 4: WalletReceiveScreen

**File**: `lib/features/payment/presentation/pages/wallet_receive_screen.dart`

StatefulWidget. State: `_isBannerVisible = true`.

```
Scaffold(
  appBar: AppBar(title: Text('wallet.receive.title'.tr())),
  body: Column([
    Expanded(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column([
          WalletQrCard(user: WalletMockData.currentUser),
          SizedBox(h:16),
          Row(3 action buttons: ShareQR, Download, Customize) — each GestureDetector → 80x80 white container
        ]),
      ),
    ),
    if (_isBannerVisible)
      _SecurityBanner(onClose: () => setState(() => _isBannerVisible = false)),
  ]),
)
```

`_SecurityBanner`: `Container(color: AppColors.primaryLight, padding: 12)` → Row: `Icon(Icons.verified_user_outlined, green)` + `Column(title bold 13sp + subtitle 12sp grey)` + `IconButton(Icons.close, onPressed: onClose)`

---

### Screen 5: WalletAddAmountScreen

**File**: `lib/features/payment/presentation/pages/wallet_add_amount_screen.dart`

StatefulWidget. State: `_amount = '0'`, `_selectedMethod = WalletMockData.defaultPaymentMethod`.

```
Scaffold(
  appBar: _WalletLogoAppBar (same as HomeScreen: ciro wallet logo centered, back arrow),
  body: Column([
    Padding(
      child: Column([
        Text('wallet.addAmount.title'.tr(), 18sp bold),
        Text('wallet.addAmount.subtitle'.tr(), 13sp grey),
        SizedBox(h:16),
        Container(border: rounded, padding: 16, child: Column([
          Text('wallet.addAmount.enterAmount'.tr(), 13sp grey hint),
          Row([
            Text(_amount == '0' ? '0' : _amount, 36sp bold),
            SizedBox(w:6),
            Text('SAR', 16sp AppColors.primary bold),
          ]),
          Text('wallet.addAmount.minimumHint'.tr(), 12sp grey),
          Divider(),
          Row([
            _ApplePayLogo(),
            SizedBox(w:8),
            Text(_selectedMethod.displayName, 14sp),
            Spacer(),
            TextButton(Text('wallet.addAmount.change'.tr(), AppColors.primary)),
          ]),
        ])),
      ]),
    ),
    Spacer(),
    WalletNumpad(
      onDigitTap: (d) => setState(() {
        if (_amount == '0') _amount = d;
        else _amount = _amount + d;
      }),
      onBackspace: () => setState(() {
        if (_amount.length <= 1) _amount = '0';
        else _amount = _amount.substring(0, _amount.length - 1);
      }),
      onNext: () {
        final value = double.tryParse(_amount) ?? 0;
        if (value < 10) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Minimum 10 SAR')));
          return;
        }
        context.push(AppRouterName.walletPaymentStatus, extra: PaymentResult(
          status: PaymentResultStatus.success,
          amount: value,
          currency: 'SAR',
          recipientName: 'Ahmed',
          referenceId: 'CIRO-938475',
        ));
      },
    ),
  ]),
)
```

---

### Screen 6: WalletPaymentStatusScreen

**File**: `lib/features/payment/presentation/pages/wallet_payment_status_screen.dart`

StatelessWidget. Receives `PaymentResult result` via GoRouter `extra`.

```
Scaffold(
  body: SafeArea(
    child: Column([
      Spacer(),
      WalletPaymentStatusIcon(isSuccess: result.status == PaymentResultStatus.success),
      SizedBox(h:24),
      Text(result.status == success ? 'wallet.payment.success.title'.tr() : 'wallet.payment.failed.title'.tr(), 24sp bold),
      SizedBox(h:8),
      // Success: "150 SAR sent to Ahmed 🎊"
      // Failed: two lines — subtitle grey + reason red
      _SubtitleWidget(result),
      SizedBox(h:24),
      WalletReferenceIdCard(referenceId: result.referenceId),
      Spacer(),
      Padding(
        horizontal: 24,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: StadiumBorder()),
            onPressed: () => context.go(AppRouterName.wallet),
            child: Text('wallet.payment.done'.tr(), 16sp bold white),
          ),
        ),
      ),
      SizedBox(h:24),
    ]),
  ),
)
```

---

### Routing Changes

**File**: `lib/core/routing/app_router.dart`

New constants in `AppRouterName`:
```dart
static const String wallet              = '/wallet';
static const String walletProfile       = '/wallet/profile';
static const String walletSend          = '/wallet/send';
static const String walletReceive       = '/wallet/receive';
static const String walletAddAmount     = '/wallet/add-amount';
static const String walletPaymentStatus = '/wallet/payment-status';
```

New `GoRoute` entries added in the router's `routes` list:
```dart
GoRoute(path: AppRouterName.wallet,              builder: (_, __) => const WalletHomeScreen()),
GoRoute(path: AppRouterName.walletProfile,       builder: (_, __) => const WalletProfileScreen()),
GoRoute(path: AppRouterName.walletSend,          builder: (_, __) => const WalletSendScreen()),
GoRoute(path: AppRouterName.walletReceive,       builder: (_, __) => const WalletReceiveScreen()),
GoRoute(path: AppRouterName.walletAddAmount,     builder: (_, __) => const WalletAddAmountScreen()),
GoRoute(
  path: AppRouterName.walletPaymentStatus,
  builder: (context, state) => WalletPaymentStatusScreen(result: state.extra as PaymentResult),
),
```

---

### AppColors Changes

**File**: `lib/core/theme/app_colors.dart`

Add under the Brand section:
```dart
/// Wallet balance card gradient end — blue
static const Color walletGradientEnd = Color(0xFF1A8FC0);
```

---

### Translation Keys

**Files**: `assets/translations/en.json` and `assets/translations/ar.json`

Add a `"wallet"` top-level object containing all 57 keys from the spec. The Arabic translations mirror the English structure with full RTL-appropriate strings.

Sample English structure:
```json
"wallet": {
  "title": "Ciro Wallet",
  "totalBalance": "Total Balance",
  "currentBalance": "Current Balance",
  "balanceHidden": "••••",
  "addMoney": "Add Money",
  "send": "Send",
  "receive": "Receive",
  "qrCode": "QR Code",
  "recentTransactions": "Recent Transaction",
  "viewAll": "View All",
  "profile": { ... },
  "send_screen": { ... },
  "receive": { ... },
  "addAmount": { ... },
  "payment": { ... }
}
```

---

## UI Contract

See `specs/025-digital-wallet-ui/wallet_ui_contracts.md` for the full screen interface contract (parameter types, navigation triggers, preconditions).

---

## Verification Plan

### Manual Verification Steps

1. Navigate to `/wallet` — branded header, gradient balance card renders; eye toggle masks balance.
2. Tap each quick action — correct screen navigation for Add Money, Send, Receive, QR Code.
3. Recent transactions list shows 4 items with correct green/black coloring.
4. FAB scanner button visible at bottom; tapping opens Receive screen.
5. Navigate to `/wallet/profile` — all 6 info card rows visible; copy icons respond with SnackBar.
6. "View Barcode" → navigates to Receive screen.
7. Navigate to `/wallet/send` — type "Ahmed" in search → list filters to matching contacts; type "zzz" → empty state.
8. Tap a suggested contact → navigates to Add Amount screen.
9. Navigate to `/wallet/receive` — QR card visible with brand logo embedded; security banner dismisses on X tap.
10. Navigate to `/wallet/add-amount` — custom numpad only (no native keyboard); digits append; backspace deletes; entering < 10 SAR + Next → SnackBar validation.
11. Enter valid amount → navigates to Payment Status in Success state — green checkmark, confetti dots, reference ID card, Done button.
12. Trigger Failed state — red cross, failure reason in red, Done returns to `/wallet`.
13. All text sourced from `easy_localization` keys (no hardcoded strings visible).
14. RTL test: switch locale to Arabic — layout mirrors correctly; amounts remain LTR.

### Automated Tests

No automated tests in this scope (UI + mock data only). Future: widget tests for `WalletNumpad` and `WalletBalanceCard`.
