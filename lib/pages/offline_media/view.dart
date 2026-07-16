import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/pages/offline_media/controller.dart';
import 'package:pilipala/utils/utils.dart';

class OfflineMediaPage extends StatefulWidget {
  const OfflineMediaPage({super.key});

  @override
  State<OfflineMediaPage> createState() => _OfflineMediaPageState();
}

class _OfflineMediaPageState extends State<OfflineMediaPage> {
  late final OfflineMediaController _controller;

  @override
  void initState() {
    super.initState();
    _controller = Get.put(OfflineMediaController());
  }

  @override
  void dispose() {
    Get.delete<OfflineMediaController>();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final double kibibytes = bytes / 1024;
    if (kibibytes < 1024) return '${kibibytes.toStringAsFixed(1)} KB';
    final double mebibytes = kibibytes / 1024;
    if (mebibytes < 1024) return '${mebibytes.toStringAsFixed(1)} MB';
    return '${(mebibytes / 1024).toStringAsFixed(2)} GB';
  }

  Future<void> _confirmDelete(OfflineMediaItem item) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除离线缓存'),
        content: Text('确定删除“${item.title}”吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _controller.delete(item);
  }

  Widget _buildCover(BuildContext context, OfflineMediaItem item) {
    final File cover = File(item.coverPath);
    if (item.coverPath.isEmpty || !cover.existsSync()) {
      return Container(
        width: 128,
        height: 72,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        alignment: Alignment.center,
        child: const Icon(Icons.video_file_outlined),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        cover,
        width: 128,
        height: 72,
        fit: BoxFit.cover,
        cacheWidth: 384,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('离线缓存'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _controller.loadMedia,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (_controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (_controller.mediaList.isEmpty) {
          return const Center(child: Text('暂无离线缓存'));
        }
        return ListView.builder(
          itemCount: _controller.mediaList.length,
          itemBuilder: (context, index) {
            final OfflineMediaItem item = _controller.mediaList[index];
            return InkWell(
              onTap: () => _controller.play(item),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    _buildCover(context, item),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            item.ownerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${item.qualityLabel} · '
                            '${Utils.timeFormat(item.durationSeconds)} · '
                            '${_formatBytes(item.sizeBytes)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => _confirmDelete(item),
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }),
    );
  }
}
