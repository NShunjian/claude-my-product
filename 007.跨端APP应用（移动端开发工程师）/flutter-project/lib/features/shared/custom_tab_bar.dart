import 'package:flutter/material.dart';

import '../../core/i18n/locale_provider.dart';

/// 移动端自定 tab bar — iOS / Android 使用。
///
/// 替换 Material `NavigationBar` 的原因:
///   - `NavigationBar.height` + 外部 Padding 让出区共享一个变量,改一处忘另一处
///     反复引发内容遮挡 / 黑条 bug。
///   - NavigationBar 内部 SafeArea 处理 + 外部 Padding 让出区的"双计算"路径
///     不直观,debug 多次。
///   - 自定版本布局、尺寸、颜色全部显式控制,不再被 M3 spec 的内部 padding 干扰。
///
/// Web / Desktop 继续用 `NavigationBar`(在 _TabScaffold.build 里三元切换)。
///
/// 视觉总高 = `kContentHeight + MediaQuery.padding.bottom`(iPhone 14 Pro = 49 + 34 = 83dp),
/// 跟 Apple HIG TabBar 一致。
class MobileTabBar extends StatelessWidget {
  const MobileTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  /// 当前选中的 tab index(0..4)。
  final int currentIndex;

  /// 点击 tab 触发。调用方负责 `tabRefreshSignalProvider(i).state++` 和
  /// `navigationShell.goBranch(i, ...)`。
  final ValueChanged<int> onTap;

  // ponytail: 内容区 57dp(总视觉高 = 57 content + 34 safeArea.bottom = 91dp,
  //          用户指定 2026-09-12)。safeArea.bottom 由 Container 高度包含,
  //          内部 SafeArea 不要重复吃。
  static const double _kContentHeight = 57.0;
  static const double _kIconSize = 24.0;
  static const double _kLabelFontSize = 11.0;

  // ponytail: 颜色从 PNG 实采样得到(2026-09-12,/tmp/sample_colors.py),
  //          之前写 0xFF2E7DE6(蓝)是臆造,跟 active PNG 实际描边色 0xFFD01000(红)对不上
  //          — label 蓝色 + icon 红色两边都错。inactive 0xFF505050 也是从 PNG 采的,
  //          之前写的 0xFF5F6368 偏蓝灰。后续要主题联动再升级到 AppColors.tabActive / tabInactive。
  static const Color _kActiveColor = Color(0xFFD01000);
  static const Color _kInactiveColor = Color(0xFF505050);

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      // ponytail: 高度 = content + safeArea.bottom,这样 Container 自带白底
      //          画到 home indicator 底部,iOS 真机不会出黑条。
      height: _kContentHeight + safeAreaBottom,
      color: Colors.white,
      child: SafeArea(
        // ponytail: top 留;bottom 不让 SafeArea 加 inset — Container 高度
        //          已经包含了 safeArea.bottom,这里只要把 content 居中即可。
        top: false,
        child: SizedBox(
          height: _kContentHeight,
          child: Row(
            children: List.generate(_kTabs.length, (i) {
              final tab = _kTabs[i];
              final selected = i == currentIndex;
              return Expanded(
                child: _TabBarItem(
                  tab: tab,
                  label: lang.t(tab.labelKey),
                  selected: selected,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

/// 单个 tab item — icon + label 垂直居中,选中变蓝。
///
/// ponytail: GestureDetector 而非 InkWell — 跟 [[month_picker.dart:80-82]]
///          注释一致,Flutter web CanvasKit 上 InkWell + Material 的嵌套
///          splash 在某些 Chrome 版本会拦截 pointer 事件,GestureDetector 干净。
class _TabBarItem extends StatelessWidget {
  const _TabBarItem({
    required this.tab,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _TabSpec tab;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? MobileTabBar._kActiveColor
        : MobileTabBar._kInactiveColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        // ponytail: 合规底线 — 给屏幕阅读器一个明确角色。
        container: true,
        selected: selected,
        label: label,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              selected ? tab.activeAsset : tab.inactiveAsset,
              width: MobileTabBar._kIconSize,
              height: MobileTabBar._kIconSize,
              // ponytail: PNG 本身有黑色描边,用 color 叠加变色会污染描边 —
              //          所以保留 PNG 原始颜色,只通过 asset 切换 active/inactive。
              //          5F6368 / 2E7DE6 的颜色是 PNG 文件本身定义好的。
            ),
            const SizedBox(height: 2),
            // ponytail: 包 DefaultTextStyle.merge 去掉 M3 默认给选中 tab label
            //          加的下划线 + 高亮(选中时文字下方有黄色下划线)。
            //          decoration: TextDecoration.none 显式覆盖 Theme 透传
            //          的下划线;backgroundColor: transparent 兜底;selectionColor
            //          是 Text 自己的属性,设 transparent 去掉高亮。
            //          fontSize 跟图片里的 label 视觉一致(11dp,uniapp 截图)。
            DefaultTextStyle.merge(
              style: TextStyle(
                fontSize: MobileTabBar._kLabelFontSize,
                color: color,
                decoration: TextDecoration.none,
                backgroundColor: Colors.transparent,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // ponytail: selectionColor 是 Text widget 的属性 — 选中文字
                //          的高亮背景,默认是 _kSelectionColor(黄色)。设
                //          Colors.transparent 去掉 M3 NavigationBar 给选中
                //          tab label 加的黄色方块。
                selectionColor: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 5 个 tab 的静态配置 — 稳定数据,做成文件内 const 比 prop 更直接。
class _TabSpec {
  const _TabSpec({
    required this.labelKey,
    required this.activeAsset,
    required this.inactiveAsset,
  });
  final String labelKey;
  final String activeAsset;
  final String inactiveAsset;
}

const _kTabs = <_TabSpec>[
  _TabSpec(
    labelKey: 'tabbar.home',
    activeAsset: 'assets/tabbar/home_active.png',
    inactiveAsset: 'assets/tabbar/home.png',
  ),
  _TabSpec(
    labelKey: 'tabbar.transactions',
    activeAsset: 'assets/tabbar/transactions_active.png',
    inactiveAsset: 'assets/tabbar/transactions.png',
  ),
  _TabSpec(
    labelKey: 'tabbar.reports',
    activeAsset: 'assets/tabbar/reports_active.png',
    inactiveAsset: 'assets/tabbar/reports.png',
  ),
  _TabSpec(
    labelKey: 'tabbar.accounts',
    activeAsset: 'assets/tabbar/accounts_active.png',
    inactiveAsset: 'assets/tabbar/accounts.png',
  ),
  _TabSpec(
    labelKey: 'tabbar.settings',
    activeAsset: 'assets/tabbar/settings_active.png',
    inactiveAsset: 'assets/tabbar/settings.png',
  ),
];
