/// Domain-safe cancellation handle for [ReelsRepository.uploadReel]
/// (v3, FR-060). Keeps `package:dio`'s `CancelToken` out of the domain
/// layer (constitution I) — the data-layer implementation adapts this to a
/// real `CancelToken` internally.
class UploadCancelToken {
  bool _cancelled = false;
  final List<void Function()> _listeners = [];

  bool get isCancelled => _cancelled;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final listener in _listeners) {
      listener();
    }
  }

  void onCancel(void Function() listener) => _listeners.add(listener);
}
