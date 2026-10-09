import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/pages/video/detail/controller.dart';
import 'package:pilipala/utils/utils.dart';

class OfflineVideoDetailPanel extends StatelessWidget {
  const OfflineVideoDetailPanel({
    required this.controller,
    super.key,
  });

  final VideoDetailController controller;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final double kibibytes = bytes / 1024;
    if (kibibytes < 1024) return '${kibibytes.toStringAsFixed(1)} KB';
    final double mebibytes = kibibytes / 1024;
    if (mebibytes < 1024) return '${mebibytes.toStringAsFixed(1)} MB';
    return '${(mebibytes / 1024).toStringAsFixed(2)} GB';
  }

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 24),
      sliver: SliverToBoxAdapter(
        child: Obx(() {
          final OfflineMediaItem? item = controller.offlineCurrentItem.value;
          if (item == null) {
            return const Center(child: Text('离线媒体信息不可用'));
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              if (item.ownerName.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.ownerName,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  const Chip(
                    avatar: Icon(Icons.offline_pin, size: 18),
                    label: Text('本地离线文件'),
                  ),
                  if (item.qualityLabel.isNotEmpty)
                    Chip(label: Text(item.qualityLabel)),
                  Chip(label: Text(Utils.timeFormat(item.durationSeconds))),
                  Chip(label: Text(_formatBytes(item.sizeBytes))),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '离线模式不会加载 Bilibili 原始分 P、合集、评论或互动状态。'
                '点赞、投币、收藏和转发等在线操作已隐藏。',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                  height: 1.5,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}
