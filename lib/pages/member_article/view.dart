import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/skeleton/skeleton.dart';
import 'package:pilipala/common/widgets/http_error.dart';
import 'package:pilipala/common/widgets/network_img_layer.dart';
import 'package:pilipala/common/widgets/no_data.dart';
import 'package:pilipala/utils/utils.dart';

import 'controller.dart';

class MemberArticlePage extends StatefulWidget {
  const MemberArticlePage({super.key});

  @override
  State<MemberArticlePage> createState() => _MemberArticlePageState();
}

class _MemberArticlePageState extends State<MemberArticlePage> {
  late MemberArticleController _memberArticleController;
  late Future _futureBuilderFuture;
  late ScrollController scrollController;
  late int mid;

  @override
  void initState() {
    super.initState();
    mid = int.parse(Get.parameters['mid']!);
    final String heroTag = Utils.makeHeroTag(mid);
    _memberArticleController = Get.put(MemberArticleController(), tag: heroTag);
    _futureBuilderFuture = _memberArticleController.getMemberArticle('init');
    scrollController = _memberArticleController.scrollController;

    scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (scrollController.position.pixels >=
        scrollController.position.maxScrollExtent - 200) {
      EasyThrottle.throttle(
          'member_archives', const Duration(milliseconds: 500), () {
        _memberArticleController.getMemberArticle('onLoad');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: const Text('Ta的图文', style: TextStyle(fontSize: 16)),
      ),
      body: FutureBuilder(
        future: _futureBuilderFuture,
        builder: (BuildContext context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            if (snapshot.hasError) {
              return _buildError('专栏页面异常\n'
                  '${snapshot.error.runtimeType}: ${snapshot.error}');
            }
            if (snapshot.data is Map) {
              return _buildContent(snapshot.data as Map);
            } else {
              return _buildError('专栏接口没有返回有效数据');
            }
          } else {
            return ListView.builder(
              itemCount: 10,
              itemBuilder: (BuildContext context, int index) {
                return _buildSkeleton();
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildContent(Map data) {
    RxList list = _memberArticleController.articleList;
    if (data['status']) {
      return Obx(
        () => list.isNotEmpty
            ? ListView.separated(
                controller: scrollController,
                itemCount: list.length,
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(
                    height: 10,
                    color:
                        Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  );
                },
                itemBuilder: (BuildContext context, int index) {
                  return _buildListItem(list[index]);
                },
              )
            : const CustomScrollView(
                physics: NeverScrollableScrollPhysics(),
                slivers: [
                  NoData(),
                ],
              ),
      );
    } else {
      return _buildError(data['msg']);
    }
  }

  Widget _buildListItem(dynamic item) {
    return ListTile(
      onTap: () {
        Get.toNamed('/opus', parameters: {
          'title': item.content,
          'id': item.opusId,
          'articleType': 'opus',
        });
      },
      leading: NetworkImgLayer(
        width: 50,
        height: 50,
        type: 'emote',
        src: item.cover?['url']?.toString() ?? '',
      ),
      title: Text(
        item.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          '${item.stat?["like"] ?? 0}人点赞',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.outline,
          ),
        ),
      ),
    );
  }

  Widget _buildError(String errMsg) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        HttpError(
          errMsg: errMsg,
          fn: () {
            setState(() {
              _futureBuilderFuture =
                  _memberArticleController.getMemberArticle('init');
            });
          },
        ),
      ],
    );
  }

  Widget _buildSkeleton() {
    return Skeleton(
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onInverseSurface,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Container(
          height: 16,
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
        subtitle: Container(
          height: 11,
          color: Theme.of(context).colorScheme.onInverseSurface,
        ),
      ),
    );
  }
}
