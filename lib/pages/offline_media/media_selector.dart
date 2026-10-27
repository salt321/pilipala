import 'package:flutter/material.dart';
import 'package:pilipala/models/offline_media.dart';

/// Selection is a draft: filtering never discards hidden selections.
class OfflineMediaSelector extends StatefulWidget {
  const OfflineMediaSelector({required this.items, super.key});
  final List<OfflineMediaItem> items;
  @override
  State<OfflineMediaSelector> createState() => _OfflineMediaSelectorState();
}

class _OfflineMediaSelectorState extends State<OfflineMediaSelector> {
  final Set<String> _selected = {};
  String _query = '';
  int _days = 0;
  int _length = 0;

  @override
  Widget build(BuildContext context) {
    final cutoff = DateTime.now().subtract(Duration(days: _days));
    final visible = widget.items
        .where((item) =>
            item.title.toLowerCase().contains(_query) &&
            (_days == 0 || !item.createdAt.isBefore(cutoff)) &&
            (_length == 0 ||
                (_length == 1 && item.durationSeconds < 600) ||
                (_length == 2 &&
                    item.durationSeconds >= 600 &&
                    item.durationSeconds < 1800) ||
                (_length == 3 && item.durationSeconds >= 1800)))
        .toList();
    return AlertDialog(
      title: Text('选择视频（${_selected.length}）'),
      content: SizedBox(
          width: 520,
          height: MediaQuery.sizeOf(context).height * .6,
          child: Column(children: [
            TextField(
                decoration: const InputDecoration(labelText: '搜索视频名称'),
                onChanged: (value) =>
                    setState(() => _query = value.trim().toLowerCase())),
            Wrap(spacing: 8, children: [
              DropdownButton<int>(
                  value: _days,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('全部缓存时间')),
                    DropdownMenuItem(value: 7, child: Text('最近7天')),
                    DropdownMenuItem(value: 30, child: Text('最近30天')),
                  ],
                  onChanged: (value) => setState(() => _days = value ?? 0)),
              DropdownButton<int>(
                  value: _length,
                  items: const [
                    DropdownMenuItem(value: 0, child: Text('全部时长')),
                    DropdownMenuItem(value: 1, child: Text('不足10分钟')),
                    DropdownMenuItem(value: 2, child: Text('10–30分钟')),
                    DropdownMenuItem(value: 3, child: Text('至少30分钟')),
                  ],
                  onChanged: (value) => setState(() => _length = value ?? 0)),
              TextButton(
                  onPressed: () => setState(
                      () => _selected.addAll(visible.map((e) => e.cacheKey))),
                  child: const Text('全选结果')),
              TextButton(
                  onPressed: () => setState(() {
                        for (final item in visible) {
                          if (!_selected.remove(item.cacheKey))
                            _selected.add(item.cacheKey);
                        }
                      }),
                  child: const Text('反选结果')),
              TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: const Text('清空选择')),
            ]),
            Expanded(
                child: visible.isEmpty
                    ? const Center(child: Text('没有匹配的视频'))
                    : ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (context, index) {
                          final item = visible[index];
                          return CheckboxListTile(
                              value: _selected.contains(item.cacheKey),
                              title: Text(item.title,
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              subtitle: Text('${item.durationSeconds} 秒'),
                              onChanged: (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(item.cacheKey);
                                    } else {
                                      _selected.remove(item.cacheKey);
                                    }
                                  }));
                        })),
          ])),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
            onPressed: _selected.isEmpty
                ? null
                : () => Navigator.pop(
                    context,
                    widget.items
                        .where((item) => _selected.contains(item.cacheKey))
                        .toList()),
            child: const Text('确认选择'))
      ],
    );
  }
}
