# Socket Contracts: Multi-Device Read Suppression

**Feature**: 008-multidevice-read-suppression
**Date**: 2026-05-19

## Statement

This feature introduces **no new socket events, no new payload fields, and no changes to existing socket event semantics on the backend**. Per clarification Q2 (answered: A), the gating is enforced client-side at the source of emission. The backend continues to treat the existing `markRead` emit and `messageRead` broadcast exactly as it does today.

## Existing Events (unchanged, listed for confidence)

| Event | Direction | Change |
|-------|-----------|--------|
| `markRead` (emit from client) | Flutter → backend | No payload change. Triggered only when `ChatCubit._isDeliberatelyOpen == true`. |
| `messageRead` (broadcast) | backend → Flutter (sender's device) | No payload change. Sender's UI continues to promote messages from `delivered` to `read` exactly as today. |
| `markDelivered` (emit from client) | Flutter → backend | No payload change. Emitted unconditionally on receipt per FR-007 — explicitly NOT gated by the new flag. |
| `messageDelivered` (broadcast) | backend → Flutter (sender's device) | No payload change. |

## Idempotency Note (Constitution §IV)

The existing idempotency of `markRead` (server treats duplicate acks for the same `(user, messageId)` pair as a no-op) is the property that makes Q2 option A work without backend changes. When two of a user's devices independently satisfy the deliberate-open gate and both emit `markRead`, the backend records the first and silently absorbs the second — consistent with the per-user, not per-device, read tracking documented in RD-4.

## §IV-A (Safe-Cast Pattern) Audit

No new socket handler is added in this feature. The existing `messageRead` and `messageDelivered` handlers in `lib/core/network/socket_service.dart` are untouched. The Constitution §IV-A safe-cast pattern is preserved.

## Backend Repository

No backend repository changes are required.

| Path | Change |
|------|--------|
| `src/modules/chat/chat.gateway.ts` | None |
| `src/modules/chat/chat.service.ts` | None |
| `src/modules/chat/chat.controller.ts` | None |
