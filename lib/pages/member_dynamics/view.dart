import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/pages/member_dynamics/index.dart';
import 'package:pilipala/utils/utils.dart';

import '../../common/widgets/http_error.dart';
import '../../common/widgets/no_data.dart';
import '../../models/dynamics/result.dart';
import '../dynamics/widgets/dynamic_panel.dart';

class MemberDynamicsPage extends StatefulWidget {
  const MemberDynamicsPage({super.key});

  @override
  State<MemberDynamicsPage> createState() => _MemberDynamicsPageState();
}

class _MemberDynamicsPageState extends State<MemberDynamicsPage> {
  late MemberDynamicsController _memberDynamicController;
  late Future _futureBuilderFuture;
  late ScrollController scrollController;
  late int mid;

  @override
  void initState() {
    super.initState();
    mid = int.parse(Get.parameters['mid']!);
    final String heroTag = Utils.makeHeroTag(mid);
    _memberDynamicController =
        Get.put(MemberDynamicsController(), tag: heroTag);
    _futureBuilderFuture =
        _memberDynamicController.getMemberDynamic('onRefresh');
    scrollController = _memberDynamicController.scrollController;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          EasyThrottle.throttle(
              'member_dynamics', const Duration(milliseconds: 1000), () {
            _memberDynamicController.onLoad();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _memberDynamicController.scrollController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Text('他的动态', style: Theme.of(context).textTheme.titleMedium),
      ),
      body: CustomScrollView(
        controller: _memberDynamicController.scrollController,
        slivers: [
          FutureBuilder(
            future: _futureBuilderFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  return HttpError(
                    errMsg: '用户动态页面异常\n'
                        '${snapshot.error.runtimeType}: ${snapshot.error}',
                    fn: _retry,
                  );
                }
                if (snapshot.data is Map) {
                  Map data = snapshot.data as Map;
                  RxList<DynamicItemModel> list =
                      _memberDynamicController.dynamicsList;
                  if (data['status']) {
                    return Obx(
                      () => list.isNotEmpty
                          ? SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  if (index == 0) {
                                    final model = data['data'];
                                    return Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                          16, 10, 16, 4),
                                      child: Text(
                                        '接口获取 ${model?.rawItemCount ?? list.length} 条，'
                                        '成功显示 ${list.length} 条',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                    );
                                  }
                                  return DynamicPanel(
                                    item: list[index - 1],
                                    source: 'member',
                                    showActions: true,
                                  );
                                },
                                childCount: list.length + 1,
                              ),
                            )
                          : const NoData(),
                    );
                  } else {
                    return HttpError(
                      errMsg: snapshot.data['msg'],
                      fn: _retry,
                    );
                  }
                } else {
                  return HttpError(
                    errMsg: '用户动态接口没有返回有效数据',
                    fn: _retry,
                  );
                }
              } else {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _retry() {
    setState(() {
      _futureBuilderFuture =
          _memberDynamicController.getMemberDynamic('onRefresh');
    });
  }
}
