import 'package:easy_debounce/easy_throttle.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/constants.dart';
import 'package:pilipala/common/widgets/http_error.dart';
import 'package:pilipala/common/widgets/no_data.dart';
import 'controller.dart';
import 'widgets/item.dart';

class MemberSeasonsPage extends StatefulWidget {
  const MemberSeasonsPage({super.key});

  @override
  State<MemberSeasonsPage> createState() => _MemberSeasonsPageState();
}

class _MemberSeasonsPageState extends State<MemberSeasonsPage> {
  late MemberSeasonsController _memberSeasonsController;
  late Future _futureBuilderFuture;
  late ScrollController scrollController;
  late String category;

  @override
  void initState() {
    super.initState();
    category = Get.parameters['category']!;
    final tag = '${Get.parameters['mid']}:$category:'
        '${Get.parameters['seasonId'] ?? Get.parameters['seriesId']}';
    _memberSeasonsController = Get.put(MemberSeasonsController(), tag: tag);
    _futureBuilderFuture = category == '0'
        ? _memberSeasonsController.getSeasonDetail('onRefresh')
        : _memberSeasonsController.getSeriesDetail('onRefresh');
    scrollController = _memberSeasonsController.scrollController;
    scrollController.addListener(
      () {
        if (scrollController.position.pixels >=
            scrollController.position.maxScrollExtent - 200) {
          EasyThrottle.throttle(
              'member_archives', const Duration(milliseconds: 500), () {
            _memberSeasonsController.onLoad();
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Text(Get.parameters['seasonName']!,
            style: Theme.of(context).textTheme.titleMedium),
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          left: StyleString.safeSpace,
          right: StyleString.safeSpace,
        ),
        child: SingleChildScrollView(
          controller: _memberSeasonsController.scrollController,
          child: FutureBuilder(
            future: _futureBuilderFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (snapshot.hasError) {
                  return _error('合集详情页面异常\n'
                      '${snapshot.error.runtimeType}: ${snapshot.error}');
                }
                if (snapshot.data is Map) {
                  Map data = snapshot.data as Map;
                  List list = _memberSeasonsController.seasonsList;
                  if (data['status']) {
                    return Obx(
                      () => list.isNotEmpty
                          ? LayoutBuilder(
                              builder: (context, boxConstraints) {
                                return GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: StyleString.safeSpace,
                                    mainAxisSpacing: StyleString.safeSpace,
                                    childAspectRatio: 0.94,
                                  ),
                                  physics: const NeverScrollableScrollPhysics(),
                                  shrinkWrap: true,
                                  itemCount: _memberSeasonsController
                                      .seasonsList.length,
                                  itemBuilder: (context, i) {
                                    return MemberSeasonsItem(
                                      seasonItem: _memberSeasonsController
                                          .seasonsList[i],
                                    );
                                  },
                                );
                              },
                            )
                          : const SizedBox(
                              height: 500,
                              child: CustomScrollView(slivers: [NoData()]),
                            ),
                    );
                  } else {
                    return _error(data['msg']?.toString() ?? '合集详情请求异常');
                  }
                } else {
                  return _error('合集详情接口没有返回有效数据');
                }
              } else {
                return const Padding(
                  padding: EdgeInsets.only(top: 120),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _error(String message) {
    return SizedBox(
      height: 500,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          HttpError(
            errMsg: message,
            fn: () {
              setState(() {
                _futureBuilderFuture = category == '0'
                    ? _memberSeasonsController.getSeasonDetail('onRefresh')
                    : _memberSeasonsController.getSeriesDetail('onRefresh');
              });
            },
          ),
        ],
      ),
    );
  }
}
