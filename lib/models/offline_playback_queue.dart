import 'dart:math';

import 'package:pilipala/models/offline_playlist.dart';

/// Session-only ordering; history records successfully opened media only.
class OfflinePlaybackQueue {
  OfflinePlaybackQueue({
    required this.length,
    required int startIndex,
    required this.mode,
    Random? random,
  }) : _random = random ?? Random() {
    if (length <= 0 || startIndex < 0 || startIndex >= length) {
      throw ArgumentError('Invalid offline queue length or start index');
    }
    _history.add(startIndex);
    if (mode == OfflinePlayMode.shuffle) {
      _remaining.addAll(List.generate(length, (index) => index)
        ..remove(startIndex)
        ..shuffle(_random));
    }
  }

  final int length;
  final OfflinePlayMode mode;
  final Random _random;
  final List<int> _remaining = [];
  final List<int> _history = [];
  int _cursor = 0;

  int get current => _history[_cursor];

  int? peekNext({bool automatic = false}) {
    if (automatic && mode == OfflinePlayMode.singleRepeat) return current;
    if (_cursor + 1 < _history.length) return _history[_cursor + 1];
    if (mode == OfflinePlayMode.shuffle) {
      if (_remaining.isEmpty) _refill();
      return _remaining.last;
    }
    if (current + 1 < length) return current + 1;
    return mode == OfflinePlayMode.listRepeat ? 0 : null;
  }

  int? peekPrevious() {
    if (_cursor > 0) return _history[_cursor - 1];
    if (mode == OfflinePlayMode.shuffle) return null;
    if (current > 0) return current - 1;
    return mode == OfflinePlayMode.listRepeat ? length - 1 : null;
  }

  void commitNext({bool automatic = false}) {
    final target = peekNext(automatic: automatic);
    if (target == null || (automatic && mode == OfflinePlayMode.singleRepeat))
      return;
    if (_cursor + 1 < _history.length) {
      _cursor++;
      return;
    }
    if (mode == OfflinePlayMode.shuffle) _remaining.removeLast();
    _history.add(target);
    _cursor++;
  }

  void commitPrevious() {
    final target = peekPrevious();
    if (target == null) return;
    if (_cursor > 0) {
      _cursor--;
    } else {
      _history.insert(0, target);
    }
  }

  void _refill() {
    _remaining
        .addAll(List.generate(length, (index) => index)..shuffle(_random));
    // Avoid an immediate repeat at a round boundary when another item exists.
    if (length > 1 && _remaining.last == current) {
      final first = _remaining.first;
      _remaining[0] = _remaining.last;
      _remaining[length - 1] = first;
    }
  }
}
