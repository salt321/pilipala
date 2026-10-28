import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/models/offline_playlist.dart';
import 'package:pilipala/pages/offline_media/media_selector.dart';
import 'package:pilipala/plugin/pl_player/controller.dart';

class OfflinePlaylistEditorSheet extends StatefulWidget {
  const OfflinePlaylistEditorSheet({
    required this.playlist,
    required this.items,
    required this.onSave,
    required this.onPlay,
    required this.onModeChanged,
    this.availableItems = const [],
    this.onDeleteCache,
    super.key,
  });

  final OfflinePlaylist playlist;
  final List<OfflineMediaItem> availableItems;
  final Future<void> Function(OfflineMediaItem)? onDeleteCache;
  final List<OfflineMediaItem> items;
  final Future<void> Function(List<OfflineMediaItem> items) onSave;
  final void Function(
          int startIndex, List<OfflineMediaItem> items, OfflinePlayMode mode)
      onPlay;
  final Future<void> Function(OfflinePlayMode mode) onModeChanged;

  @override
  State<OfflinePlaylistEditorSheet> createState() =>
      _OfflinePlaylistEditorSheetState();
}

class _OfflinePlaylistEditorSheetState
    extends State<OfflinePlaylistEditorSheet> {
  late final List<OfflineMediaItem> _items = List.of(widget.items);
  int _startIndex = 0;
  bool _saving = false;
  late OfflinePlayMode _playMode = widget.playlist.playMode;

  Future<void> _changePlayMode(OfflinePlayMode? mode) async {
    if (mode == null || mode == _playMode || _saving) return;
    setState(() => _saving = true);
    try {
      await widget.onModeChanged(mode);
      if (mounted) setState(() => _playMode = mode);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('播放模式保存失败，请重新打开列表检查')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _manageItems(String action) async {
    if (_saving) return;
    final keys = _items.map((e) => e.cacheKey).toSet();
    final choices = action == 'add'
        ? widget.availableItems
            .where((e) => !keys.contains(e.cacheKey))
            .toList()
        : List<OfflineMediaItem>.of(_items);
    final selected = await showDialog<List<OfflineMediaItem>>(
        context: context, builder: (_) => OfflineMediaSelector(items: choices));
    if (!mounted || selected == null) return;
    if (action == 'delete' || (action == 'remove' && selected.length > 1)) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text(action == 'delete'
                      ? '删除 ${selected.length} 个缓存？'
                      : '删除 ${selected.length} 个列表项目？'),
                  content: Text(action == 'delete'
                      ? '将停止当前播放并永久删除本地文件，同时清理所有列表中的对应引用。此操作无法撤销。'
                      : '将从当前列表删除所选项目并自动保存，本地缓存文件仍保留。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(action == 'delete' ? '删除缓存' : '确认删除'))
                  ]));
      if (!mounted || confirmed != true) return;
    }
    if (action != 'delete') {
      final removed = selected.map((e) => e.cacheKey).toSet();
      final next = action == 'add'
          ? [..._items, ...selected]
          : _items.where((e) => !removed.contains(e.cacheKey)).toList();
      await _persistItems(next);
      return;
    }
    setState(() => _saving = true);
    final current = _items.isEmpty ? null : _items[_startIndex].cacheKey;
    try {
      // Stop releases the media source before deleting shared cache files.
      await PlPlayerController(videoType: 'none').videoPlayerController?.stop();
      for (final item in selected) {
        await widget.onDeleteCache!(item);
        _items.removeWhere((e) => e.cacheKey == item.cacheKey);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作未全部完成，请检查剩余项目后重试')));
      }
    } finally {
      final index = _items.indexWhere((e) => e.cacheKey == current);
      _startIndex = index < 0 ? 0 : index;
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    if (_saving) return;
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final next = List<OfflineMediaItem>.of(_items);
    next.insert(newIndex, next.removeAt(oldIndex));
    _persistItems(next);
  }

  void _remove(int index) {
    if (_saving) return;
    _persistItems(List<OfflineMediaItem>.of(_items)..removeAt(index));
  }

  /// Commit before replacing the visible list; a failed write is not success.
  Future<void> _persistItems(List<OfflineMediaItem> next) async {
    if (_saving) return;
    final current = _items.isEmpty ? null : _items[_startIndex].cacheKey;
    setState(() => _saving = true);
    try {
      await widget.onSave(List.of(next));
      if (!mounted) return;
      _items
        ..clear()
        ..addAll(next);
      final index = _items.indexWhere((item) => item.cacheKey == current);
      _startIndex = index < 0 ? 0 : index;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('自动保存失败，请重新打开列表检查')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _cover(OfflineMediaItem item) {
    final File file = File(item.coverPath);
    if (item.coverPath.isEmpty || !file.existsSync()) {
      return const SizedBox(
        width: 88,
        child: Center(child: Icon(Icons.video_file_outlined)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        file,
        width: 88,
        height: 50,
        fit: BoxFit.cover,
        cacheWidth: 264,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
        canPop: !_saving,
        child: AbsorbPointer(
            absorbing: _saving,
            child: SafeArea(
              child: SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.82,
                child: Column(
                  children: [
                    ListTile(
                      title: Text(widget.playlist.name),
                      subtitle: Text('${_items.length} 个已缓存视频 · 拖动调整顺序'),
                      trailing: IconButton(
                        tooltip: '关闭',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ),
                    const Divider(height: 1),
                    if (_saving) const LinearProgressIndicator(),
                    Wrap(children: [
                      TextButton(
                          onPressed: () => _manageItems('add'),
                          child: const Text('添加')),
                      TextButton(
                          onPressed: () => _manageItems('remove'),
                          child: const Text('删除')),
                      if (widget.onDeleteCache != null)
                        TextButton(
                            onPressed: () => _manageItems('delete'),
                            child: const Text('移除并删除缓存')),
                    ]),
                    ListTile(
                      title: const Text('播放模式'),
                      subtitle: const Text('为此列表自动保存；随机模式一轮内不重复'),
                      trailing: DropdownButton<OfflinePlayMode>(
                        value: _playMode,
                        onChanged: _changePlayMode,
                        items: [
                          for (final mode in OfflinePlayMode.values)
                            DropdownMenuItem(
                                value: mode, child: Text(mode.label)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? const Center(child: Text('播放列表为空'))
                          : ReorderableListView.builder(
                              buildDefaultDragHandles: false,
                              itemCount: _items.length,
                              onReorder: _reorder,
                              itemBuilder: (context, index) {
                                final OfflineMediaItem item = _items[index];
                                final bool selected = index == _startIndex;
                                return ListTile(
                                  key: ValueKey(item.cacheKey),
                                  selected: selected,
                                  onTap: () =>
                                      setState(() => _startIndex = index),
                                  leading: _cover(item),
                                  title: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle:
                                      selected ? const Text('从这里开始') : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: '从列表移除',
                                        onPressed: () => _remove(index),
                                        icon: const Icon(
                                            Icons.remove_circle_outline),
                                      ),
                                      ReorderableDragStartListener(
                                        index: index,
                                        child: const Padding(
                                          padding: EdgeInsets.all(12),
                                          child: Icon(Icons.drag_handle),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _items.isEmpty
                                  ? null
                                  : () {
                                      final queue =
                                          List<OfflineMediaItem>.of(_items);
                                      widget.onPlay(
                                          _startIndex, queue, _playMode);
                                    },
                              icon: const Icon(Icons.play_arrow),
                              label: Text('播放第 ${_startIndex + 1} 项'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )));
  }
}
