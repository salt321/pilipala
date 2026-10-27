import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/models/offline_playlist.dart';
import 'package:pilipala/pages/offline_media/controller.dart';
import 'package:pilipala/pages/offline_media/playlist_editor.dart';
import 'package:pilipala/pages/offline_media/media_selector.dart';
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

  Future<void> _showCreatePlaylist() async {
    final items = await showDialog<List<OfflineMediaItem>>(
      context: context,
      builder: (_) =>
          OfflineMediaSelector(items: List.of(_controller.mediaList)),
    );
    if (items == null || !mounted) return;
    final nameController = TextEditingController();
    try {
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('新建本地播放列表'),
          content: TextField(
              controller: nameController,
              maxLength: 40,
              decoration: const InputDecoration(labelText: '列表名称')),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消')),
            FilledButton(
                onPressed: () {
                  if (nameController.text.trim().isNotEmpty)
                    Navigator.pop(context, nameController.text.trim());
                },
                child: const Text('创建')),
          ],
        ),
      );
      if (name != null && mounted)
        await _controller.createPlaylist(name, items.map((e) => e.cacheKey));
    } catch (_) {
      Get.snackbar('创建失败', '未能保存列表，请重试');
    } finally {
      nameController.dispose();
    }
  }

  Future<void> _openPlaylist(OfflinePlaylist playlist) async {
    final List<OfflineMediaItem> items = _controller.itemsOf(playlist);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Close explicitly so an in-flight automatic save cannot be dismissed.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => OfflinePlaylistEditorSheet(
        playlist: playlist,
        items: items,
        availableItems: List.of(_controller.mediaList),
        onDeleteCache: _controller.delete,
        onSave: (items) => _controller.updatePlaylist(playlist, items),
        onPlay: (startIndex, items) => _controller.playPlaylist(
          playlist,
          items,
          startIndex: startIndex,
        ),
      ),
    );
  }

  Future<void> _renamePlaylist(OfflinePlaylist playlist) async {
    final TextEditingController textController =
        TextEditingController(text: playlist.name);
    final String? name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('重命名播放列表'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 40,
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, textController.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );
    textController.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await _controller.renamePlaylist(playlist, name);
    }
  }

  Future<void> _confirmDeletePlaylist(OfflinePlaylist playlist) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除播放列表'),
        content: Text('删除“${playlist.name}”？已缓存的视频文件不会被删除。'),
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
    if (confirmed == true) await _controller.deletePlaylist(playlist);
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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('离线缓存'),
          actions: [
            IconButton(
              tooltip: '新建本地播放列表',
              onPressed: _showCreatePlaylist,
              icon: const Icon(Icons.playlist_add),
            ),
            IconButton(
              tooltip: '刷新',
              onPressed: () async {
                await _controller.loadMedia();
                await _controller.loadPlaylists();
              },
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '已缓存视频'),
              Tab(text: '本地播放列表'),
            ],
          ),
        ),
        body: TabBarView(children: [_buildMediaList(), _buildPlaylists()]),
      ),
    );
  }

  Widget _buildMediaList() {
    return Obx(() {
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
    });
  }

  Widget _buildPlaylists() {
    return Obx(() {
      if (_controller.playlists.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.playlist_add, size: 48),
              const SizedBox(height: 12),
              const Text('暂无本地播放列表'),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: _showCreatePlaylist,
                icon: const Icon(Icons.add),
                label: const Text('新建播放列表'),
              ),
            ],
          ),
        );
      }
      return ListView.builder(
        itemCount: _controller.playlists.length,
        itemBuilder: (context, index) {
          final OfflinePlaylist playlist = _controller.playlists[index];
          final int availableCount = _controller.itemsOf(playlist).length;
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.queue_music)),
            title: Text(playlist.name),
            subtitle: Text('$availableCount 个离线视频'),
            onTap: () => _openPlaylist(playlist),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'rename') _renamePlaylist(playlist);
                if (value == 'delete') _confirmDeletePlaylist(playlist);
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'rename', child: Text('重命名')),
                PopupMenuItem(value: 'delete', child: Text('删除列表')),
              ],
            ),
          );
        },
      );
    });
  }
}
