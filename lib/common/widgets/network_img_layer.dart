import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:pilipala/utils/extension.dart';
import 'package:pilipala/utils/global_data_cache.dart';
import '../../utils/storage.dart';
import '../constants.dart';

Box<dynamic> setting = GStrorage.setting;

class NetworkImgLayer extends StatelessWidget {
  const NetworkImgLayer({
    super.key,
    this.src,
    required this.width,
    required this.height,
    this.type,
    this.fadeOutDuration,
    this.fadeInDuration,
    // 图片质量 默认1%
    this.quality,
    this.origAspectRatio,
  });

  final String? src;
  final double width;
  final double height;
  final String? type;
  final Duration? fadeOutDuration;
  final Duration? fadeInDuration;
  final int? quality;
  final double? origAspectRatio;

  @override
  Widget build(BuildContext context) {
    final int defaultImgQuality = GlobalDataCache().imgQuality;
    if (src == '' || src == null) {
      return placeholder(context);
    }
    final String normalizedUrl = src!.startsWith('//') ? 'https:${src!}' : src!;
    // 头像不再强制转成低质量 WebP。低质量 CDN 转码与低质量缩放叠加时，
    // 部分设备会显示白块或混色；原图仍会通过 memCacheWidth/Height 降采样。
    final String imageUrl = type == 'avatar' || normalizedUrl.contains('@')
        ? normalizedUrl
        : '$normalizedUrl@${quality ?? defaultImgQuality}q.webp';
    int? memCacheWidth, memCacheHeight;
    double aspectRatio = (width / height).toDouble();

    void setMemCacheSizes() {
      if (aspectRatio > 1) {
        memCacheHeight = height.cacheSize(context);
      } else if (aspectRatio < 1) {
        memCacheWidth = width.cacheSize(context);
      } else {
        if (origAspectRatio != null && origAspectRatio! > 1) {
          memCacheWidth = width.cacheSize(context);
        } else if (origAspectRatio != null && origAspectRatio! < 1) {
          memCacheHeight = height.cacheSize(context);
        } else {
          memCacheWidth = width.cacheSize(context);
          memCacheHeight = height.cacheSize(context);
        }
      }
    }

    setMemCacheSizes();

    if (memCacheWidth == null && memCacheHeight == null) {
      memCacheWidth = width.toInt();
    }

    return src != '' && src != null
        ? ClipRRect(
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(
              type == 'avatar'
                  ? 50
                  : type == 'emote'
                      ? 0
                      : StyleString.imgRadius.x,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: width,
              height: height,
              memCacheWidth: memCacheWidth,
              memCacheHeight: memCacheHeight,
              fit: BoxFit.cover,
              fadeOutDuration:
                  fadeOutDuration ?? const Duration(milliseconds: 120),
              fadeInDuration:
                  fadeInDuration ?? const Duration(milliseconds: 120),
              filterQuality:
                  type == 'avatar' ? FilterQuality.medium : FilterQuality.low,
              errorWidget: (BuildContext context, String url, Object error) =>
                  placeholder(context),
              placeholder: (BuildContext context, String url) =>
                  placeholder(context),
            ),
          )
        : placeholder(context);
  }

  Widget placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .onInverseSurface
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(type == 'avatar'
            ? 50
            : type == 'emote'
                ? 0
                : StyleString.imgRadius.x),
      ),
      child: type == 'bg'
          ? const SizedBox()
          : Center(
              child: Image.asset(
                type == 'avatar'
                    ? 'assets/images/noface.jpeg'
                    : 'assets/images/loading.png',
                width: width,
                height: height,
                fit: BoxFit.cover,
                cacheWidth: width.cacheSize(context),
                cacheHeight: height.cacheSize(context),
              ),
            ),
    );
  }
}
