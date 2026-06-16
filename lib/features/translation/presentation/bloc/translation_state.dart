import 'package:equatable/equatable.dart';

import '../../domain/entities/translation_subscription.dart';

/// Coarse, `Equatable` translation state — drives the CC-button highlight,
/// denial snackbars, and "translation unavailable" badges. Does NOT contain
/// [Caption] data; the high-frequency caption hot path lives in
/// `TranslationCubit`'s `ValueNotifier`s (data-model.md §5).
class TranslationState extends Equatable {
  /// Keyed by `speakerId`. Absence == [TranslationStatus.off].
  final Map<String, TranslationSubscription> subscriptions;

  const TranslationState({this.subscriptions = const {}});

  TranslationState copyWith({Map<String, TranslationSubscription>? subscriptions}) {
    return TranslationState(subscriptions: subscriptions ?? this.subscriptions);
  }

  @override
  List<Object?> get props => [subscriptions];
}
