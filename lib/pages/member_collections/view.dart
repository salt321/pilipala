import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/common/widgets/http_error.dart';
import 'package:pilipala/common/widgets/no_data.dart';
import 'package:pilipala/http/member.dart';
import 'package:pilipala/models/member/seasons.dart';
import 'package:pilipala/pages/member/widgets/seasons.dart';

class MemberCollectionsPage extends StatefulWidget {
  const MemberCollectionsPage({super.key});

  @override
  State<MemberCollectionsPage> createState() => _MemberCollectionsPageState();
}

class _MemberCollectionsPageState extends State<MemberCollectionsPage> {
  late final int mid;
  late Future<dynamic> future;

  @override
  void initState() {
    super.initState();
    mid = int.parse(Get.parameters['mid']!);
    future = _load();
  }

  Future<dynamic> _load() => MemberHttp.getMemberSeasons(mid, 1, 50);

  void _retry() {
    setState(() => future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        centerTitle: false,
        title: Text('Ta的合集', style: Theme.of(context).textTheme.titleMedium),
      ),
      body: FutureBuilder<dynamic>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return _error('合集页面异常\n'
                '${snapshot.error.runtimeType}: ${snapshot.error}');
          }
          if (snapshot.data is! Map) {
            return _error('合集接口没有返回有效数据');
          }
          final Map data = snapshot.data as Map;
          if (data['status'] != true) {
            return _error(data['msg']?.toString() ?? '合集请求异常');
          }
          final MemberSeasonsDataModel result = data['data'];
          if ((result.seasonsList ?? []).isEmpty) {
            return const CustomScrollView(slivers: [NoData()]);
          }
          return RefreshIndicator(
            onRefresh: () async => _retry(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: MemberSeasonsPanel(data: result),
            ),
          );
        },
      ),
    );
  }

  Widget _error(String message) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [HttpError(errMsg: message, fn: _retry)],
    );
  }
}
