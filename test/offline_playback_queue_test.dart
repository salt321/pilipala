import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:pilipala/models/offline_playback_queue.dart';
import 'package:pilipala/models/offline_playlist.dart';

void main() {
  test('顺序结束停止，列表循环回到首项', () {
    for (final mode in [
      OfflinePlayMode.sequential,
      OfflinePlayMode.listRepeat
    ]) {
      final queue = OfflinePlaybackQueue(length: 3, startIndex: 2, mode: mode);
      expect(queue.peekNext(), mode == OfflinePlayMode.sequential ? null : 0);
    }
  });

  test('单曲循环仅自动完成时重复，手动切歌仍前进', () {
    final queue = OfflinePlaybackQueue(
        length: 3, startIndex: 1, mode: OfflinePlayMode.singleRepeat);
    expect(queue.peekNext(automatic: true), 1);
    queue.commitNext(automatic: true);
    expect(queue.current, 1);
    expect(queue.peekNext(), 2);
    queue.commitNext();
    expect(queue.peekPrevious(), 1);
  });

  test('随机每轮不重复，轮次边界不连续重复，上一首遵循实际历史', () {
    final queue = OfflinePlaybackQueue(
        length: 100,
        startIndex: 17,
        mode: OfflinePlayMode.shuffle,
        random: Random(7));
    final first = [queue.current];
    for (var i = 1; i < 100; i++) {
      queue.commitNext();
      first.add(queue.current);
    }
    expect(first.toSet().length, 100);
    final last = queue.current;
    final next = queue.peekNext();
    expect(queue.peekNext(), next); // Failed/uncommitted loads do not consume.
    expect(next, isNot(last));
    queue.commitNext();
    final second = [queue.current];
    queue.commitPrevious();
    expect(queue.current, last);
    queue.commitNext();
    expect(queue.current, next);
    for (var i = 1; i < 100; i++) {
      queue.commitNext();
      second.add(queue.current);
    }
    expect(second.toSet().length, 100);
  });

  test('单项随机与空队列边界', () {
    final queue = OfflinePlaybackQueue(
        length: 1, startIndex: 0, mode: OfflinePlayMode.shuffle);
    expect(queue.peekPrevious(), isNull);
    queue.commitNext();
    expect(queue.current, 0);
    expect(
        () => OfflinePlaybackQueue(
            length: 0, startIndex: 0, mode: OfflinePlayMode.sequential),
        throwsArgumentError);
  });
}
