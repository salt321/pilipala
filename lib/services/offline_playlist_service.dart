import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:get/get.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/models/offline_playlist.dart';

class OfflinePlaylistService {
  OfflinePlaylistService._();

  static final OfflinePlaylistService instance = OfflinePlaylistService._();
  static const String _fileName = 'playlists.json';

  final RxInt revision = 0.obs;
  final List<OfflinePlaylist> _playlists = [];
  Future<void>? _initialization;
  Future<void> _writeTail = Future<void>.value();
  int _idSequence = 0;

  Future<void> ensureInitialized() {
    return _initialization ??= _load();
  }

  Future<File> _getFile() async {
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
    try {
      final dynamic decoded = jsonDecode(await file.readAsString());
      if (decoded is! List<dynamic>) return;
      _playlists
        ..clear()
        ..addAll(
          decoded
              .whereType<Map>()
              .map((json) => OfflinePlaylist.fromJson(
                    Map<String, dynamic>.from(json),
                  ))
              .where((playlist) => playlist.id.isNotEmpty),
        );
    } catch (_) {
      // 损坏的列表文件不阻断离线视频播放，下一次修改时会重建。
    }
  }

  Future<List<OfflinePlaylist>> listPlaylists() async {
    await ensureInitialized();
    final List<OfflinePlaylist> result = List.of(_playlists);
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  Future<OfflinePlaylist> create({
    required String name,
    required Iterable<String> cacheKeys,
  }) async {
    await ensureInitialized();
    final DateTime now = DateTime.now();
    final OfflinePlaylist playlist = OfflinePlaylist(
      id: '${now.microsecondsSinceEpoch}_${_idSequence++}',
      name: _normalizeName(name),
      cacheKeys: _uniqueKeys(cacheKeys),
      createdAt: now,
      updatedAt: now,
    );
    _playlists.add(playlist);
    await _persist();
    return playlist;
  }

  Future<void> update({
    required String id,
    String? name,
    Iterable<String>? cacheKeys,
    OfflinePlayMode? playMode,
  }) async {
    await ensureInitialized();
    final int index = _playlists.indexWhere((item) => item.id == id);
    if (index < 0) return;
    _playlists[index] = _playlists[index].copyWith(
      name: name == null ? null : _normalizeName(name),
      cacheKeys: cacheKeys == null ? null : _uniqueKeys(cacheKeys),
      updatedAt: DateTime.now(),
      playMode: playMode,
    );
    await _persist();
  }

  Future<void> delete(String id) async {
    await ensureInitialized();
    final int oldLength = _playlists.length;
    _playlists.removeWhere((item) => item.id == id);
    if (_playlists.length != oldLength) await _persist();
  }

  Future<void> removeCacheKey(String cacheKey) async {
    await ensureInitialized();
    bool changed = false;
    for (int index = 0; index < _playlists.length; index++) {
      final OfflinePlaylist playlist = _playlists[index];
      if (!playlist.cacheKeys.contains(cacheKey)) continue;
      _playlists[index] = playlist.copyWith(
        cacheKeys: playlist.cacheKeys.where((key) => key != cacheKey).toList(),
        updatedAt: DateTime.now(),
      );
      changed = true;
    }
    if (changed) await _persist();
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
    return LinkedHashSet<String>.from(keys.where((key) => key.isNotEmpty))
        .toList(growable: false);
  }

  Future<void> _persist() {
    final List<Map<String, dynamic>> snapshot =
        _playlists.map((item) => item.toJson()).toList(growable: false);
    _writeTail = _writeTail.then((_) => _writeSnapshot(snapshot));
    return _writeTail;
  }

  Future<void> _writeSnapshot(List<Map<String, dynamic>> snapshot) async {
    final File file = await _getFile();
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(snapshot), flush: true);
    try {
      await temporary.rename(file.path);
    } on FileSystemException {
      if (await file.exists()) await file.delete();
      await temporary.rename(file.path);
    }
    revision.value++;
  }
}
