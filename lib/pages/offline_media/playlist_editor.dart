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
    this.availableItems = const [],
    this.onDeleteCache,
    super.key,
  });

  final OfflinePlaylist playlist;
  final List<OfflineMediaItem> availableItems;
  final Future<void> Function(OfflineMediaItem)? onDeleteCache;
  final List<OfflineMediaItem> items;
  final Future<void> Function(List<OfflineMediaItem> items) onSave;
  final void Function(int startIndex, List<OfflineMediaItem> items) onPlay;

  @override
  State<OfflinePlaylistEditorSheet> createState() =>
      _OfflinePlaylistEditorSheetState();
}

class _OfflinePlaylistEditorSheetState
    extends State<OfflinePlaylistEditorSheet> {
  late final List<OfflineMediaItem> _items = List.of(widget.items);
  int _startIndex = 0;
  bool _saving = false;
  bool _shuffle = false;

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
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('删除 ${selected.length} 个缓存？'),
                  content: const Text(
                      '将停止当前播放并永久删除本地文件，同时清理所有列表中的对应引用。已删除的缓存不能通过取消编辑恢复。'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('删除缓存'))
                  ]));
      if (!mounted || confirmed != true) return;
    }
    setState(() => _saving = true);
    final current = _items.isEmpty ? null : _items[_startIndex].cacheKey;
    try {
      if (action == 'add') {
        _items.addAll(selected);
      } else if (action == 'delete') {
        // Stop releases the media source before deleting shared cache files.
        await PlPlayerController(videoType: 'none')
            .videoPlayerController
            ?.stop();
        for (final item in selected) {
          await widget.onDeleteCache!(item);
          _items.removeWhere((e) => e.cacheKey == item.cacheKey);
        }
      } else {
        final removed = selected.map((e) => e.cacheKey).toSet();
        _items.removeWhere((e) => removed.contains(e.cacheKey));
      }
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('操作未全部完成，请检查剩余项目后重试')));
    } finally {
      final index = _items.indexWhere((e) => e.cacheKey == current);
      _startIndex = index < 0 ? 0 : index;
      if (mounted) setState(() => _saving = false);
    }
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final OfflineMediaItem? selected =
          _items.isEmpty ? null : _items[_startIndex];
      final OfflineMediaItem item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _startIndex = selected == null ? 0 : _items.indexOf(selected);
    });
  }

  void _remove(int index) {
    setState(() {
      _items.removeAt(index);
      if (_items.isEmpty) {
        _startIndex = 0;
      } else if (_startIndex >= _items.length) {
        _startIndex = _items.length - 1;
      } else if (index < _startIndex) {
        _startIndex--;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await widget.onSave(List.of(_items));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
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
                    Wrap(children: [
                      TextButton(
                          onPressed: () => _manageItems('add'),
                          child: const Text('批量添加')),
                      TextButton(
                          onPressed: () => _manageItems('remove'),
                          child: const Text('批量移除')),
                      if (widget.onDeleteCache != null)
                        TextButton(
                            onPressed: () => _manageItems('delete'),
                            child: const Text('移除并删除缓存')),
                    ]),
                    SwitchListTile(
                      title: const Text('随机播放'),
                      subtitle: const Text('打乱本次播放队列，保留保存的列表顺序'),
                      secondary: const Icon(Icons.shuffle),
                      value: _shuffle,
                      onChanged: (value) => setState(() => _shuffle = value),
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
                            child: OutlinedButton.icon(
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('保存修改'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _items.isEmpty
                                  ? null
                                  : () {
                                      final queue =
                                          List<OfflineMediaItem>.of(_items);
                                      if (_shuffle) queue.shuffle();
                                      widget.onPlay(
                                          _shuffle ? 0 : _startIndex, queue);
                                    },
                              icon: const Icon(Icons.play_arrow),
                              label: Text(_shuffle
                                  ? '随机播放'
                                  : '播放第 ${_startIndex + 1} 项'),
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
