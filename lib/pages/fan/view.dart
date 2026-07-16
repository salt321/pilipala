import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/http_error.dart';
import 'package:pilipala/common/widgets/no_data.dart';
import 'package:pilipala/models/fans/result.dart';

import 'controller.dart';
import 'widgets/fan_item.dart';

class FansPage extends StatefulWidget {
  const FansPage({super.key});

  @override
  State<FansPage> createState() => _FansPageState();
}

class _FansPageState extends State<FansPage> {
  late String mid;
  late FansController _fansController;
  final ScrollController scrollController = ScrollController();
  Future? _futureBuilderFuture;

  @override
  void initState() {
    super.initState();
    mid = Get.parameters['mid']!;
    _fansController = Get.put(FansController(), tag: mid);
    _futureBuilderFuture = _fansController.queryFans('init');
    scrollController.addListener(
      () async {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          EasyThrottle.throttle('follow', const Duration(seconds: 1), () {
            _fansController.queryFans('onLoad');
          });
        }
      },
    );
  }

  @override
  void dispose() {
    scrollController.removeListener(() {});
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 0,
        title: Text(
          _fansController.isOwner.value ? '我的粉丝' : '${_fansController.name}的粉丝',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final Future<dynamic> future = _fansController.queryFans('init');
          setState(() => _futureBuilderFuture = future);
          await future;
        },
        child: FutureBuilder(
          future: _futureBuilderFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return CustomScrollView(
                  slivers: [
                    HttpError(
                      errMsg: '粉丝页面异常\n'
                          '${snapshot.error.runtimeType}: ${snapshot.error}',
                      fn: _reload,
                    ),
                  ],
                );
              }
              final dynamic data = snapshot.data;
              if (data is Map && data['status'] == true) {
                List<FansItemModel> list = _fansController.fansList;
                return Obx(
                  () => list.isNotEmpty
                      ? ListView.builder(
                          controller: scrollController,
                          itemCount: list.length + 1,
                          itemBuilder: (BuildContext context, int index) {
                            if (index == list.length) {
                              return Container(
                                height:
                                    MediaQuery.of(context).padding.bottom + 60,
                                padding: EdgeInsets.only(
                                    bottom:
                                        MediaQuery.of(context).padding.bottom),
                                child: Center(
                                  child: Obx(
                                    () => Text(
                                      _fansController.loadingText.value,
                                      style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .outline,
                                          fontSize: 13),
                                    ),
                                  ),
                                ),
                              );
                            } else {
                              return fanItem(item: list[index]);
                            }
                          },
                        )
                      : const CustomScrollView(
                          slivers: [NoData()],
                        ),
                );
              } else {
                return CustomScrollView(
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: [
                    HttpError(
                      errMsg: data is Map
                          ? data['msg']?.toString()
                          : '粉丝列表没有返回有效数据',
                      fn: _reload,
                    )
                  ],
                );
              }
            } else {
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
    );
  }

  void _reload() {
    setState(() {
      _futureBuilderFuture = _fansController.queryFans('init');
    });
  }
}
