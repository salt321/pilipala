import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pilipala/models/dynamics/result.dart';
import 'package:pilipala/pages/dynamics/index.dart';

import 'action_panel.dart';
import 'author_panel.dart';
import 'content_panel.dart';
import 'forward_panel.dart';

/// 所有动态页面共用的渲染入口。
class DynamicPanel extends StatelessWidget {
  const DynamicPanel({
    required this.item,
    this.source,
    this.openDetailOnTap = true,
    this.showActions,
    this.nested = false,
    super.key,
  });

  final DynamicItemModel item;
  final String? source;
  final bool openDetailOnTap;
  final bool? showActions;
  final bool nested;

  bool get _showActions => showActions ?? source == null;

  @override
  Widget build(BuildContext context) {
    final hasContent = item.modules?.moduleDynamic != null;
    _ensureStats();
    return Container(
      padding: source == 'detail'
          ? const EdgeInsets.only(bottom: 12)
          : EdgeInsets.zero,
      decoration: nested
          ? null
          : BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: 8,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                ),
              ),
            ),
      child: Material(
        elevation: 0,
        color: nested
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : null,
        clipBehavior: Clip.hardEdge,
        child: InkWell(
          onTap: openDetailOnTap ? _openDetail : null,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: AuthorPanel(item: item),
              ),
              if (hasContent) Content(item: item, source: source),
              _attachment(context),
              const SizedBox(height: 2),
              if (_showActions && _hasCompleteStats) ActionPanel(item: item),
            ],
          ),
        ),
      ),
    );
  }

  void _ensureStats() {
    final modules = item.modules;
    if (modules == null || modules.moduleStat != null) return;
    modules.moduleStat = ModuleStatModel(
      comment: Comment(count: null, forbidden: false),
      forward: ForWard(count: null, forbidden: false),
      like: Like(count: null, forbidden: false, status: false),
    );
  }

  bool get _hasCompleteStats =>
      item.idStr?.isNotEmpty == true && item.modules?.moduleStat != null;

  void _openDetail() {
    if (source == 'member') {
      Get.toNamed(
        '/dynamicDetail',
        arguments: {'item': item, 'floor': 1},
      );
      return;
    }
    Get.put(DynamicsController()).pushDetail(item, 1);
  }

  Widget _attachment(BuildContext context) {
    if (item.type == 'DYNAMIC_TYPE_FORWARD') {
      final original = item.orig;
      if (original == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: DynamicPanel(
          item: DynamicItemModel(
            basic: original.basic,
            idStr: original.isStr,
            modules: original.modules,
            type: original.type,
            visible: original.visible,
          ),
          source: source,
          openDetailOnTap: false,
          showActions: false,
          nested: true,
        ),
      );
    }

    try {
      // 附件统一交给原有渲染器；模型层负责兼容新版接口字段。
      return forWard(item, context, null, source);
    } catch (error) {
      debugPrint('DynamicPanel attachment skipped: $error');
      return const SizedBox.shrink();
    }
  }
}
