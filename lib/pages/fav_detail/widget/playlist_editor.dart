import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/user/fav_detail.dart';

class PlaylistEditorSheet extends StatefulWidget {
  const PlaylistEditorSheet({
    required this.items,
    required this.onPlay,
    super.key,
  });

  final List<FavDetailItemData> items;
  final Future<void> Function(
    int startIndex,
    List<FavDetailItemData> items,
  ) onPlay;

  @override
  State<PlaylistEditorSheet> createState() => _PlaylistEditorSheetState();
}

class _PlaylistEditorSheetState extends State<PlaylistEditorSheet> {
  late final List<FavDetailItemData> _original = List.of(widget.items);
  late List<FavDetailItemData> _items = List.of(widget.items);
  int _startIndex = 0;
  bool _starting = false;

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final selectedItem = _items[_startIndex];
      final item = _items.removeAt(oldIndex);
      _items.insert(newIndex, item);
      _startIndex = _items.indexOf(selectedItem);
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

  void _shuffle() {
    setState(() {
      _items.shuffle(Random());
      _startIndex = 0;
    });
  }

  void _reset() {
    setState(() {
      _items = List.of(_original);
      _startIndex = 0;
    });
  }

  Future<void> _play() async {
    if (_items.isEmpty || _starting) return;
    setState(() => _starting = true);
    try {
      await widget.onPlay(_startIndex, List.of(_items));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: Column(
          children: [
            ListTile(
              title: Text('播放队列 · ${_items.length}'),
              subtitle: const Text('拖动排序，点选开始位置；移除只影响本次播放'),
              trailing: IconButton(
                tooltip: '关闭',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  TextButton.icon(
                    onPressed: _items.length > 1 ? _shuffle : null,
                    icon: const Icon(Icons.shuffle, size: 18),
                    label: const Text('随机排序'),
                  ),
                  TextButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.restart_alt, size: 18),
                    label: const Text('恢复顺序'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('播放队列为空'))
                  : ReorderableListView.builder(
                      buildDefaultDragHandles: false,
                      itemCount: _items.length,
                      onReorder: _reorder,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        final selected = index == _startIndex;
                        return ListTile(
                          key: ValueKey('${item.id}-$index'),
                          selected: selected,
                          onTap: () => setState(() => _startIndex = index),
                          leading: SizedBox(
                            width: 88,
                            child: NetworkImgLayer(
                              src: item.pic ?? '',
                              width: 88,
                              height: 50,
                            ),
                          ),
                          title: Text(
                            item.title ?? '未命名视频',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: selected ? const Text('从这里开始') : null,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: '从队列移除',
                                onPressed: () => _remove(index),
                                icon: const Icon(Icons.remove_circle_outline),
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
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: FilledButton.icon(
                onPressed: _items.isEmpty || _starting ? null : _play,
                icon: _starting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _items.isEmpty ? '没有可播放项目' : '从第 ${_startIndex + 1} 项播放',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
