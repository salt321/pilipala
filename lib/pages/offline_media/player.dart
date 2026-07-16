import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/offline_media.dart';
import 'package:pilipala/plugin/pl_player/index.dart';

class OfflinePlayerPage extends StatefulWidget {
  const OfflinePlayerPage({super.key});

  @override
  State<OfflinePlayerPage> createState() => _OfflinePlayerPageState();
}

class _OfflinePlayerPageState extends State<OfflinePlayerPage> {
  late final OfflineMediaItem _item;
  late final PlPlayerController _playerController;
  late final Future<void> _initialization;

  @override
  void initState() {
    super.initState();
    _item = Get.arguments as OfflineMediaItem;
    _playerController = PlPlayerController();
    _initialization = _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final File video = File(_item.videoPath);
    if (!await video.exists()) throw StateError('离线视频文件不存在');
    if (_item.hasAudio && !await File(_item.audioPath).exists()) {
      throw StateError('离线音频文件不存在');
    }
    await _playerController.setDataSource(
      DataSource(
        videoSource: _item.videoPath,
        audioSource: _item.audioPath,
        type: DataSourceType.file,
      ),
      autoplay: true,
      duration: Duration(seconds: _item.durationSeconds),
      enableHeart: false,
      bvid: '',
      cid: 0,
    );
  }

  @override
  void dispose() {
    _playerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          _item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: FutureBuilder<void>(
            future: _initialization,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    '无法播放：${snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              return PLVideoPlayer(controller: _playerController);
            },
          ),
        ),
      ),
    );
  }
}
