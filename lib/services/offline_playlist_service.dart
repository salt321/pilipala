import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/models/offline_playlist.dart';

class OfflinePlaylistService {
  OfflinePlaylistService._()
      : _fileOverride = null,
        _replaceFile = null;

  /// Isolated storage and a replacement fault seam for persistence tests.
  OfflinePlaylistService.forTesting(File file,
      {Future<void> Function(File, String)? replaceFile})
      : _fileOverride = file,
        _replaceFile = replaceFile;

  final File? _fileOverride;
  final Future<void> Function(File, String)? _replaceFile;

  static final OfflinePlaylistService instance = OfflinePlaylistService._();
  static const String _fileName = 'playlists.json';

  final RxInt revision = 0.obs;
  final List<OfflinePlaylist> _playlists = [];
  Future<void>? _initialization;
  Future<void> _writeTail = Future<void>.value();
  int _idSequence = 0;

  Future<void> ensureInitialized() {
    return _initialization ??= _load().onError<Object>((error, stack) {
      _initialization = null;
      Error.throwWithStackTrace(error, stack);
    });
  }

  Future<File> _getFile() async {
    final override = _fileOverride;
    if (override != null) return override;
    final Directory documents = await getApplicationDocumentsDirectory();
    final Directory directory = Directory(
      '${documents.path}${Platform.pathSeparator}offline_media',
    );
    await directory.create(recursive: true);
    return File('${directory.path}${Platform.pathSeparator}$_fileName');
  }

  Future<void> _load() async {
    final File file = await _getFile();
    if (!await file.exists()) return;
    final dynamic decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<dynamic> ||
        decoded.any((item) =>
            item is! Map ||
            item['id'] is! String ||
            (item['id'] as String).isEmpty)) {
      throw const FormatException('Invalid playlist document');
    }
    // Decode completely before publishing; corrupt data must not be overwritten.
    final loaded = decoded
        .map((json) =>
            OfflinePlaylist.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
    _playlists
      ..clear()
      ..addAll(loaded);
  }

  Future<List<OfflinePlaylist>> listPlaylists() async {
    await ensureInitialized();
    final List<OfflinePlaylist> result = _playlists
        .map((item) =>
            item.copyWith(cacheKeys: List.unmodifiable(item.cacheKeys)))
        .toList();
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<OfflinePlaylist> create({
    required String name,
    required Iterable<String> cacheKeys,
  }) async {
    final DateTime now = DateTime.now();
    final OfflinePlaylist playlist = OfflinePlaylist(
      id: '${now.microsecondsSinceEpoch}_${_idSequence++}',
      name: _normalizeName(name),
      cacheKeys: _uniqueKeys(cacheKeys),
      createdAt: now,
      updatedAt: now,
    );
    return _mutate((next) {
      next.add(playlist);
      return playlist;
    });
  }

  Future<void> update({
    required String id,
    String? name,
    Iterable<String>? cacheKeys,
    OfflinePlayMode? playMode,
  }) async {
    final keys = cacheKeys == null ? null : _uniqueKeys(cacheKeys);
    await _mutate<void>((next) {
      final int index = next.indexWhere((item) => item.id == id);
      if (index < 0) throw StateError('Playlist no longer exists');
      next[index] = next[index].copyWith(
        name: name == null ? null : _normalizeName(name),
        cacheKeys: keys,
        updatedAt: DateTime.now(),
        playMode: playMode,
      );
    });
  }

  Future<void> delete(String id) async {
    await _mutate<void>((next) => next.removeWhere((item) => item.id == id));
  }

  Future<void> removeCacheKey(String cacheKey) async {
    await _mutate<void>((next) {
      for (int index = 0; index < next.length; index++) {
        final OfflinePlaylist playlist = next[index];
        if (!playlist.cacheKeys.contains(cacheKey)) continue;
        next[index] = playlist.copyWith(
          cacheKeys:
              playlist.cacheKeys.where((key) => key != cacheKey).toList(),
          updatedAt: DateTime.now(),
        );
      }
    });
  }

  List<OfflineMediaItem> resolveItems(
    OfflinePlaylist playlist,
    Iterable<OfflineMediaItem> media,
  ) {
    final Map<String, OfflineMediaItem> byKey = {
      for (final OfflineMediaItem item in media) item.cacheKey: item,
    };
    return playlist.cacheKeys
        .map((key) => byKey[key])
        .whereType<OfflineMediaItem>()
        .toList(growable: false);
  }

  String _normalizeName(String name) {
    final String trimmed = name.trim();
    return trimmed.isEmpty ? '未命名播放列表' : trimmed;
  }

  List<String> _uniqueKeys(Iterable<String> keys) {
    return List.unmodifiable(
        LinkedHashSet<String>.from(keys.where((key) => key.isNotEmpty)));
  }

  Future<T> _mutate<T>(T Function(List<OfflinePlaylist>) change) {
    final operation = _writeTail.then((_) async {
      await ensureInitialized();
      final next = List<OfflinePlaylist>.of(_playlists);
      final result = change(next);
      // Mutations replace immutable entries; unchanged identities mean no write.
      var changed = next.length != _playlists.length;
      for (var index = 0; !changed && index < next.length; index++) {
        changed = !identical(next[index], _playlists[index]);
      }
      if (!changed) return result;
      await _writeSnapshot(next.map((item) => item.toJson()).toList());
      _playlists
        ..clear()
        ..addAll(next);
      revision.value++;
      return result;
    });
    // The caller receives the original failure; only the scheduling tail recovers.
    _writeTail =
        operation.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return operation;
  }

  Future<void> _writeSnapshot(List<Map<String, dynamic>> snapshot) async {
    final File file = await _getFile();
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(snapshot), flush: true);
    final replace = _replaceFile;
    if (replace != null) {
      await replace(temporary, file.path);
    } else {
      // Same-directory rename: never delete the last valid file on failure.
      await temporary.rename(file.path);
    }
  }
}
