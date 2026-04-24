# Phase 0: Outline & Research

## Decision: Targeted Cubit Rebuilds
**Rationale**: `ChatCubit` currently rebuilds the entire UI on every socket event, causing lag. Using `buildWhen` in `BlocBuilder` and splitting state changes (e.g., typing updates vs. new messages) will ensure only relevant widgets rebuild.
**Alternatives considered**: Using `ValueNotifier` or `ChangeNotifier` for fine-grained states, but this violates the constitution which mandates `flutter_bloc` (Cubit).

## Decision: Separate Call State Management
**Rationale**: The prompt requires Voice and Video calls to not interrupt text chat. We will manage call states in a separate Cubit and display active/incoming calls using an overlay (e.g., `OverlayEntry` or a global stack in the root widget) that floats above the `ChatPage`.
**Alternatives considered**: Routing to a new `CallPage`, but this interrupts the text chat flow and drops the active text entry state.

## Decision: Core Assets Utilization
**Rationale**: To meet codebase consistency constraints, all strings, colors, icons, and theme data in the chat UI must be sourced exclusively from `lib/core/`.
**Alternatives considered**: Creating local `constants.dart` in the chat feature, but this fragments the UI guidelines.