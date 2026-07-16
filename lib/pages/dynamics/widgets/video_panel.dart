// 视频or合集
import 'package:flutter/material.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/constants.dart';
import 'package:pilipala/common/widgets/badge.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/http/search.dart';
import 'package:pilipala/utils/id_utils.dart';
import 'package:pilipala/utils/route_push.dart';
import 'package:pilipala/utils/utils.dart';

import 'rich_node_panel.dart';

Widget videoSeasonWidget(item, context, type, {floor = 1}) {
  TextStyle authorStyle =
      TextStyle(color: Theme.of(context).colorScheme.primary);
  // type archive  ugcSeason
  // archive 视频/显示发布人
  // ugcSeason 合集/不显示发布人

  // floor 1：主动态；floor 2：转发动态中的嵌套卡片。
  Map<dynamic, dynamic> dynamicProperty = {
    'ugcSeason': item.modules.moduleDynamic.major.ugcSeason,
    'archive': item.modules.moduleDynamic.major.archive,
    'pgc': item.modules.moduleDynamic.major.pgc
  };
  dynamic content = dynamicProperty[type];
  if (content == null) return const SizedBox.shrink();

  return InkWell(
    onTap: () => _openVideo(content, type),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (floor == 2) ...[
          Row(
            children: [
              GestureDetector(
                onTap: () => Get.toNamed(
                    '/member?mid=${item.modules.moduleAuthor.mid}',
                    arguments: {'face': item.modules.moduleAuthor.face}),
                child: Text(
                  item.modules.moduleAuthor.type == null
                      ? '@${item.modules.moduleAuthor.name}'
                      : item.modules.moduleAuthor.name,
                  style: authorStyle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                item.modules.moduleAuthor.pubTs != null
                    ? Utils.dateFormat(item.modules.moduleAuthor.pubTs)
                    : item.modules.moduleAuthor.pubTime,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: Theme.of(context).textTheme.labelSmall!.fontSize),
              ),
            ],
          ),
          const SizedBox(height: 6),
        ],
        if (floor == 2 && item.modules.moduleDynamic.desc != null) ...[
          Text.rich(richNode(item, context)),
          const SizedBox(height: 6),
        ],
        LayoutBuilder(builder: (context, box) {
          final availableWidth = floor == 1 ? box.maxWidth - 24 : box.maxWidth;
          final width = availableWidth.clamp(0.0, 360.0);
          final radius = BorderRadius.circular(floor == 1 ? 8 : 6);
          return Padding(
            padding: floor == 1
                ? const EdgeInsets.symmetric(horizontal: 12)
                : EdgeInsets.zero,
            child: ClipRRect(
              borderRadius: radius,
              child: SizedBox(
                width: width,
                height: width / StyleString.aspectRatio,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    NetworkImgLayer(
                      width: width,
                      height: width / StyleString.aspectRatio,
                      src: content.cover ?? '',
                    ),
                    if (content.badge != null && content.badge['text'] != null)
                      PBadge(
                        text: content.badge['text'],
                        top: 8.0,
                        right: 10.0,
                        bottom: null,
                        left: null,
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        height: 64,
                        padding: const EdgeInsets.fromLTRB(12, 0, 10, 10),
                        clipBehavior: Clip.hardEdge,
                        decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Colors.transparent,
                                Colors.black54,
                              ],
                            ),
                            borderRadius: radius),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            DefaultTextStyle.merge(
                              style: TextStyle(
                                  fontSize: Theme.of(context)
                                      .textTheme
                                      .labelMedium!
                                      .fontSize,
                                  color: Colors.white),
                              child: Row(
                                children: [
                                  Text(content.durationText ?? ''),
                                  if (content.durationText != null)
                                    const SizedBox(width: 10),
                                  Text('${content.stat?.play ?? '0'}次围观'),
                                  const SizedBox(width: 10),
                                  Text('${content.stat?.danmaku ?? '0'}条弹幕')
                                ],
                              ),
                            ),
                            Image.asset(
                              'assets/images/play.png',
                              width: 46,
                              height: 46,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 6),
        Padding(
          padding: floor == 1
              ? const EdgeInsets.only(left: 12, right: 12)
              : EdgeInsets.zero,
          child: Text(
            content.title ?? '视频',
            maxLines: 1,
            style: const TextStyle(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Future<void> _openVideo(dynamic content, String type) async {
  if (type == 'pgc') {
    if (content.epid != null) RoutePush.bangumiPush(null, content.epid);
    return;
  }
  try {
    String bvid = content.bvid?.toString() ?? '';
    if (!bvid.startsWith('BV') && content.aid != null) {
      bvid = IdUtils.av2bv(content.aid as int);
    }
    if (!bvid.startsWith('BV')) {
      final jumpUrl = content.jumpUrl?.toString() ?? '';
      bvid = RegExp(r'BV[0-9A-Za-z]+').firstMatch(jumpUrl)?.group(0) ?? '';
    }
    if (bvid.isEmpty) {
      SmartDialog.showToast('该动态缺少视频编号');
      return;
    }
    final cid = await SearchHttp.ab2c(bvid: bvid);
    Get.toNamed(
      '/video?bvid=$bvid&cid=$cid',
      arguments: {'pic': content.cover, 'heroTag': bvid},
    );
  } catch (error) {
    SmartDialog.showToast('打开视频失败：$error');
  }
}
