# Research: Digital Wallet UI (025)

**Feature**: Digital Wallet UI
**Date**: 2026-07-17
**Phase**: Phase 0 — Research & Decision Log

---

## Decisions

### D-001: Feature Module Location

**Decision**: Extend the existing `lib/features/payment/` module rather than creating a new top-level `wallet` feature.

**Rationale**: `lib/features/payment/` already exists with `data/`, `domain/`, and `presentation/` sub-layers and a `PaymentCubit`/`PaymentState`. Wallet is a payment concept; co-locating keeps the architecture coherent and avoids module proliferation.

**Alternatives considered**:
- Create `lib/features/wallet/` as a standalone feature — rejected because it would duplicate DI registrations and create confusion between "wallet" and the existing "payment" feature that already owns Apple/Google Pay.

---

### D-002: State Management for Wallet UI

**Decision**: Use `StatefulWidget` + `setState` for local UI state. No new Cubit is required.

**Rationale**: The spec explicitly mandates UI & mock data only — no real payment gateway, no database, no complex state management. The existing `PaymentCubit` manages real payment flows; the wallet UI screens are display-only and use ephemeral state (balance visibility toggle, numpad input, search filter text, payment status variant).

**Alternatives considered**:
- Create a `WalletCubit` — rejected as over-engineering for a pure mock UI. If real API integration is added in a future spec, a Cubit can be introduced at that point.

---

### D-003: QR Code Widget

**Decision**: Use `qr_flutter ^4.1.0` (already in `pubspec.yaml`) for QR code rendering with a centered brand logo `EmbeddedImageStyle`.

**Rationale**: `qr_flutter` is already declared as a dependency (line 80 of `pubspec.yaml`). No additional dependency needed. The `QrImageView` widget supports `embeddedImage` for the brand logo overlay.

**Alternatives considered**:
- Use a static mock image — rejected because a real QR widget makes the UI functional for demos.

---

### D-004: Custom Numpad

**Decision**: Implement a `WalletNumpad` stateless widget that renders a `GridView` of `InkWell`/`GestureDetector` containers. `keyboardType` on any text input is explicitly NOT used.

**Rationale**: The spec (FR-028) explicitly forbids the native device keyboard. A custom widget gives full control over layout, haptic feedback, and green "next" button spanning the full cell.

**Alternatives considered**:
- Flutter's built-in `RawKeyboardListener` — rejected because it still requires a `TextField` focus node which may invoke the soft keyboard.

---

### D-005: Confetti / Particle Decoration on Payment Status Screen

**Decision**: Use static `CustomPaint` + `Positioned` dots drawn with a `List<_ConfettiDot>` model, no animation package.

**Rationale**: Spec scope is UI-only. Importing `confetti` or `lottie` would add a new dependency. Static colored dots around the status icon faithfully replicate the screenshot aesthetic within the mock-data-only constraint.

**Alternatives considered**:
- `confetti` package animation — deferred to a future iteration when real payment flows require celebration animations.

---

### D-006: Routing Integration

**Decision**: Add 6 new route names to `AppRouterName` in `app_router.dart` under the `/wallet` prefix. Routes use `go_router` `GoRoute` entries without sub-router nesting (consistent with existing pattern).

**Route map**:
| Route Name Constant | Path | Screen |
|---------------------|------|--------|
| `wallet` | `/wallet` | `WalletHomeScreen` |
| `walletProfile` | `/wallet/profile` | `WalletProfileScreen` |
| `walletSend` | `/wallet/send` | `WalletSendScreen` |
| `walletReceive` | `/wallet/receive` | `WalletReceiveScreen` |
| `walletAddAmount` | `/wallet/add-amount` | `WalletAddAmountScreen` |
| `walletPaymentStatus` | `/wallet/payment-status` | `WalletPaymentStatusScreen` |

**Rationale**: Flat route structure matches the existing pattern (all payment routes live under `/profile/payments_*`). The `/wallet` root is distinct from `/profile` to make the wallet a first-class navigable section.

---

### D-007: Localization Strategy

**Decision**: Add a `wallet` key object to both `assets/translations/en.json` and `assets/translations/ar.json`. All 57 keys defined in the spec will be nested under `"wallet": { ... }` using `easy_localization`'s dot-notation access (e.g. `'wallet.title'.tr()`).

**Rationale**: The project already uses `easy_localization ^3.0.8` (confirmed in `pubspec.yaml`, line 67) with `en.json` and `ar.json`. Nesting under a `wallet` key groups keys logically and avoids naming collisions with existing flat keys.

---

### D-008: AppColors Tokens

**Decision**: Use existing `AppColors.primary` (`#4CA02A`) as `brandGreen`. Add two new constants to `AppColors`: `walletGradientEnd` (`#1A8FC0`) for the balance card gradient end color, and reuse `AppColors.error` (`#D32F2F`) for the failed state icon.

**Rationale**: The brand green in screenshots is slightly lighter than `#4CA02A` but the difference is negligible at mobile resolution and maintaining a single source of truth in `AppColors` is the established convention.

---

### D-009: Balance Card Gradient

**Decision**: `LinearGradient(colors: [AppColors.primary, AppColors.walletGradientEnd], begin: Alignment.centerLeft, end: Alignment.centerRight)` rendered inside a `Container` with `borderRadius: BorderRadius.circular(16)` and `BoxDecoration`.

**Rationale**: Matches the screenshot gradient direction (green left → blue right) using Flutter's built-in `BoxDecoration.gradient`.

---

### D-010: Mock Data Source

**Decision**: Define mock data as `const List<...>` in a `wallet_mock_data.dart` helper file inside `lib/features/payment/presentation/`.

**Rationale**: Keeps mock data in one place, easily replaceable with real repository calls in a future spec without touching widget code.

---

## NEEDS CLARIFICATION — All Resolved

No open clarifications remain. All spec items were concrete enough to make informed decisions above.

---

## Technology Verification

| Dependency | Status | Version in pubspec.yaml |
|------------|--------|------------------------|
| easy_localization | ✅ Present | ^3.0.8 |
| qr_flutter | ✅ Present | ^4.1.0 |
| go_router | ✅ Present | ^17.2.0 |
| flutter_bloc | ✅ Present | ^9.1.1 |
| share_plus | ✅ Present | ^11.0.0 |
| gal | ✅ Present | ^2.3.0 |
| cached_network_image | ✅ Present | ^3.4.1 |
| image_picker | ✅ Present | ^1.1.2 |
| file_picker | ✅ Present | ^8.1.2 |

No new dependencies required.
