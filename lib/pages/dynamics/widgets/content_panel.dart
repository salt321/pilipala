import 'package:flutter/material.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/models/dynamics/result.dart';
import 'package:pilipala/plugin/pl_gallery/index.dart';

import 'rich_node_panel.dart';

/// 动态正文。兼容旧版 desc、DRAW 以及新版 OPUS 字段。
class Content extends StatelessWidget {
  const Content({
    super.key,
    required this.item,
    this.source,
  });

  final DynamicItemModel item;
  final String? source;

  bool get _expanded => source == 'detail' || source == 'member';

  @override
  Widget build(BuildContext context) {
    final data = item.modules?.moduleDynamic;
    if (data == null) return const SizedBox.shrink();
    final nodes = data.desc?.richTextNodes?.isNotEmpty == true
        ? data.desc!.richTextNodes
        : data.major?.opus?.summary?.richTextNodes;
    final plainText = _contentText(data);
    final images = _opusImages(data);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.topic?.name?.isNotEmpty == true)
            Text(
              '#${data.topic!.name}',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          if (nodes?.isNotEmpty == true)
            IgnorePointer(
              ignoring: !_expanded,
              child: Text.rich(
                richNode(item, context),
                maxLines: _expanded ? null : 3,
                overflow:
                    _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
              ),
            )
          else if (plainText.isNotEmpty)
            Text(
              plainText,
              maxLines: _expanded ? null : 3,
              overflow:
                  _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
            ),
          if (images.isNotEmpty) ...[
            const SizedBox(height: 6),
            _images(context, images),
          ],
        ],
      ),
    );
  }

  String _contentText(ModuleDynamicModel data) {
    final parts = <String>[];
    final values = <String?>[
      data.major?.opus?.title,
      data.desc?.text,
      data.major?.opus?.summary?.text,
    ];
    for (final value in values) {
      final normalized = value?.trim() ?? '';
      if (normalized.isNotEmpty && !parts.contains(normalized)) {
        parts.add(normalized);
      }
    }
    return parts.join('\n');
  }

  List<_DynamicImage> _opusImages(ModuleDynamicModel data) {
    return (data.major?.opus?.pics ?? const <OpusPicsModel>[])
        .map(
          (pic) => _DynamicImage(
            url: pic.url ?? pic.src ?? '',
            width: pic.width,
            height: pic.height,
          ),
        )
        .where((pic) => pic.url.isNotEmpty)
        .toList();
  }

  Widget _images(BuildContext context, List<_DynamicImage> images) {
    final urls = images.map((image) => image.url).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 24;
        if (images.length == 1) {
          final image = images.first;
          final ratio = _ratio(image);
          final imageWidth = width / 2;
          final imageHeight = (imageWidth / ratio).clamp(100.0, 360.0);
          return GestureDetector(
            onTap: () => _preview(context, urls, 0),
            child: NetworkImgLayer(
              src: image.url,
              width: imageWidth,
              height: imageHeight,
              origAspectRatio: ratio,
            ),
          );
        }
        final columns = images.length < 3 ? 2 : 3;
        final tileSize = (width - (columns - 1) * 4) / columns;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: images.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) => GestureDetector(
            onTap: () => _preview(context, urls, index),
            child: NetworkImgLayer(
              src: images[index].url,
              width: tileSize,
              height: tileSize,
              origAspectRatio: _ratio(images[index]),
            ),
          ),
        );
      },
    );
  }

  double _ratio(_DynamicImage image) {
    final width = image.width ?? 0;
    final height = image.height ?? 0;
    return width > 0 && height > 0 ? width / height : 1;
  }

  void _preview(BuildContext context, List<String> urls, int index) {
    Navigator.of(context).push(
      HeroDialogRoute<void>(
        builder: (_) => InteractiveviewerGallery(
          sources: urls,
          initIndex: index,
          onPageChanged: (_) {},
        ),
      ),
    );
  }
}

class _DynamicImage {
  const _DynamicImage({required this.url, this.width, this.height});

  final String url;
  final int? width;
  final int? height;
}
