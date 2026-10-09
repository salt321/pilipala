import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/constants.dart';
import 'package:pilipala/models/live/item.dart';
import 'package:pilipala/utils/image_save.dart';
import 'package:pilipala/utils/utils.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';

// 视频卡片 - 垂直布局
class LiveCardV extends StatelessWidget {
  final LiveItemModel liveItem;
  final int crossAxisCount;

  const LiveCardV({
    Key? key,
    required this.liveItem,
    required this.crossAxisCount,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final int? roomId = liveItem.roomId;
    final String heroTag = Utils.makeHeroTag(roomId ?? 'invalid-live-room');
    return InkWell(
      onLongPress: () => imageSaveDialog(
        context,
        liveItem,
        SmartDialog.dismiss,
      ),
      borderRadius: BorderRadius.circular(16),
      onTap: () async {
        if (roomId == null || roomId <= 0) {
          SmartDialog.showToast('直播间信息不完整，请刷新后重试');
          return;
        }
        Get.toNamed('/liveRoom?roomid=$roomId',
            arguments: {'liveItem': liveItem, 'heroTag': heroTag});
      },
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.all(StyleString.imgRadius),
            child: AspectRatio(
              aspectRatio: StyleString.aspectRatio,
              child: LayoutBuilder(builder: (context, boxConstraints) {
                double maxWidth = boxConstraints.maxWidth;
                double maxHeight = boxConstraints.maxHeight;
                return Stack(
                  children: [
                    Hero(
                      tag: heroTag,
                      child: NetworkImgLayer(
                        src: liveItem.cover,
                        width: maxWidth,
                        height: maxHeight,
                      ),
                    ),
                    if (crossAxisCount != 1)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: AnimatedOpacity(
                          opacity: 1,
                          duration: const Duration(milliseconds: 200),
                          child: VideoStat(
                            liveItem: liveItem,
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),
          ),
          LiveContent(liveItem: liveItem, crossAxisCount: crossAxisCount)
        ],
      ),
    );
  }
}

class LiveContent extends StatelessWidget {
  final dynamic liveItem;
  final int crossAxisCount;
  const LiveContent(
      {Key? key, required this.liveItem, required this.crossAxisCount})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: crossAxisCount == 1 ? 0 : 1,
      child: Padding(
        padding: crossAxisCount == 1
            ? const EdgeInsets.fromLTRB(9, 9, 9, 4)
            : const EdgeInsets.fromLTRB(5, 8, 5, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              liveItem.title ?? '未命名直播',
              textAlign: TextAlign.start,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                letterSpacing: 0.3,
              ),
              maxLines: crossAxisCount == 1 ? 1 : 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (crossAxisCount == 1) const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Text(
                    liveItem.uname ?? '未知主播',
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.labelMedium!.fontSize,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (crossAxisCount == 1) ...[
                  Text(
                    ' • ${liveItem.areaName ?? '未知分区'}',
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.labelMedium!.fontSize,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  Text(
                    ' • ${liveItem.watchedShow?['text_small'] ?? '观看人数未知'}',
                    style: TextStyle(
                      fontSize:
                          Theme.of(context).textTheme.labelMedium!.fontSize,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ]
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class VideoStat extends StatelessWidget {
  final LiveItemModel? liveItem;

  const VideoStat({
    Key? key,
    required this.liveItem,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String areaName = liveItem?.areaName ?? '未知分区';
    final String watchedText =
        liveItem?.watchedShow?['text_small']?.toString() ?? '观看人数未知';
    return Container(
      height: 50,
      padding: const EdgeInsets.only(top: 26, left: 10, right: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black54,
          ],
          tileMode: TileMode.mirror,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            areaName,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
          Text(
            watchedText,
            style: const TextStyle(fontSize: 11, color: Colors.white),
          ),
        ],
      ),

      // child: RichText(
      //   maxLines: 1,
      //   textAlign: TextAlign.justify,
      //   softWrap: false,
      //   text: TextSpan(
      //     style: const TextStyle(fontSize: 11, color: Colors.white),
      //     children: [
      //       TextSpan(text: liveItem!.areaName!),
      //       TextSpan(text: liveItem!.watchedShow!['text_small']),
      //     ],
      //   ),
      // ),
    );
  }
}
