import 'dart:async';

/// Debounced, serialised autosave.
///
/// * [schedule] marks the draft dirty and (re)starts the debounce timer.
/// * Only ONE [send] is ever in flight; edits made meanwhile coalesce into a
///   single follow-up send, which reads the latest state when it runs - so a
///   plan id returned by the first response is already known to the second
///   request and no duplicate drafts are created.
/// * [flush] resolves once nothing is pending (used before leaving / publishing).
/// * Failures are remembered in [lastError] and reported through [onState]; the
///   draft stays dirty so the next edit or [flush] retries.
class DraftSaver {
  DraftSaver({required this.send, this.delay = const Duration(milliseconds: 600), this.onState});

  final Future<void> Function() send;
  final Duration delay;
  final void Function(DraftSaveState state)? onState;

  Timer? _timer;
  Future<void>? _running;
  bool _dirty = false;
  bool _disposed = false;
  Object? lastError;
  DraftSaveState state = DraftSaveState.idle;

  bool get hasPending => _dirty || _running != null;

  void schedule() {
    if (_disposed) return;
    _dirty = true;
    _timer?.cancel();
    _timer = Timer(delay, () {
      _pump();
    });
  }

  Future<void> _pump() => _running ??= _drain().whenComplete(() => _running = null);

  Future<void> _drain() async {
    while (_dirty && !_disposed) {
      _dirty = false;
      _set(DraftSaveState.saving);
      try {
        await send();
        lastError = null;
        if (!_dirty) _set(DraftSaveState.saved);
      } catch (e) {
        lastError = e;
        _dirty = true;
        _set(DraftSaveState.failed);
        return;
      }
    }
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    var guard = 0;
    while ((_dirty || _running != null) && guard++ < 4) {
      await _pump();
      if (lastError != null) return;
    }
  }

  void _set(DraftSaveState s) {
    state = s;
    if (!_disposed) onState?.call(s);
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
  }
}

enum DraftSaveState { idle, saving, saved, failed }
