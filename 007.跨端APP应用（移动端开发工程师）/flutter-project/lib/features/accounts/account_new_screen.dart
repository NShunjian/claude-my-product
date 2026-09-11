import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/models.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../shared/app_header.dart';
import '../shared/providers.dart';
import '../shared/toast_controller.dart';

/// 对齐 pages/accounts/new.vue — 新建账户表单。
class AccountNewScreen extends ConsumerStatefulWidget {
  const AccountNewScreen({super.key});

  @override
  ConsumerState<AccountNewScreen> createState() => _AccountNewScreenState();
}

/// 对齐 uniapp new.vue ACCOUNT_TYPES — picker 里的一个条目。
/// type 是上送后端的 AccountType;labelKey 是 i18n key,顺序对齐 uniapp 截图。
class _TypePickItem {
  const _TypePickItem(this.type, this.labelKey);
  final AccountType type;
  final String labelKey;
}

class _AccountNewScreenState extends ConsumerState<AccountNewScreen> {
  // ponytail: 对齐 uniapp new.vue — 账户图标是 5 个 emoji 单选,跟 AccountType
  //          是分开的两套字段(后端 Account.icon 是字符串)。用户保存时
  //          把 emoji 字符串作为 icon 上送,卡片列表渲染时**忽略**这个字段
  //          仍按 type 走 themeMap(跟 uniapp 行为 1:1)。
  static const _icons = <String>['👛', '💳', '🏦', '💰', '📱'];

  final _nameCtrl = TextEditingController();
  final _balanceCtrl = TextEditingController(text: '0.00');
  // ponytail: 对齐 uniapp new.vue ACCOUNT_TYPES 顺序 — 微信支付 / 支付宝 /
  //          现金 / 银行卡 / 信用卡 / 投资账户 / 其他。_typeLabelIndex 同时
  //          管 picker 选中态和展示区 label,保证两侧 1:1 同步。
  static const _typeItems = <_TypePickItem>[
    _TypePickItem(AccountType.wallet, 'accountAdd.type.wechat'),
    _TypePickItem(AccountType.wallet, 'accountAdd.type.alipay'),
    _TypePickItem(AccountType.cash, 'accountAdd.type.cash'),
    _TypePickItem(AccountType.debit, 'accountAdd.type.bank'),
    _TypePickItem(AccountType.credit, 'accountAdd.type.credit'),
    _TypePickItem(AccountType.investment, 'accountAdd.type.investment'),
    _TypePickItem(AccountType.other, 'accountAdd.type.other'),
  ];
  // 默认进 picker 之前,展示区显示第一项"微信支付";_type 同步为 wallet
  // 让 picker 滚到 wechat 那一行(initialIndex 0)。
  int _typeLabelIndex = 0;
  AccountType get _type => _typeItems[_typeLabelIndex].type;
  set _type(AccountType t) {
    final i = _typeItems.indexWhere((it) => it.type == t);
    if (i >= 0) _typeLabelIndex = i;
  }
  String _icon = _icons.first;
  bool _isDefault = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _balanceCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    // V1.2 金额核算审计:解析失败不再静默退化为 0(inputFormatters 已经过滤了大部分垃圾),
    // NaN / Infinity 显式拒绝。
    final raw = _balanceCtrl.text.trim();
    final bal = double.tryParse(raw);
    if (bal == null || !bal.isFinite) {
      ref.read(toastControllerProvider.notifier).show(lang.t('accountNew.invalidBalance'));
      return;
    }
    if (bal > 999999999999.99) {
      ref.read(toastControllerProvider.notifier).show(lang.t('accountNew.balanceTooLarge'));
      return;
    }
    // 信用卡允许负余额;现金/借记/钱包/投资/其他不接受负数
    if (bal < 0 && _type != AccountType.credit) {
      ref.read(toastControllerProvider.notifier).show(lang.t('accountNew.negativeBalance'));
      return;
    }
    setState(() => _submitting = true);
    try {
      // ponytail: 显式传当前 bookId 下去 —— 不传后端会落到默认账本,
      //          如果用户当前在非默认账本看账户页,新建的账户不在当前
      //          列表里 = 用户感觉"没保存成功"。
      final bookId = ref.read(currentBookIdProvider);
      await ref.read(accountsApiProvider).createAccount(
            CreateAccountInput(
              name: name,
              type: _type,
              icon: _icon,
              initialBalance: bal,
              currency: 'CNY',
              isDefault: _isDefault,
              bookId: bookId.isEmpty ? null : bookId,
            ),
          );
      if (!mounted) return;
      ref.read(toastControllerProvider.notifier).show(lang.t('accountAdd.submitAccount'));
      // ponytail: 不再推 tabRefreshSignalProvider(3) — accounts_screen 的
      //          onAdd 用 await context.push + _reload 拿确定性顺序,无需
      //          跨页信号。信号机制留下 race(window: save→signal++ 与
      //          context.pop 间隔几毫秒,正好被 IndexedStack + push 路由
      //          的 FutureBuilder rebuild 时序吃掉)。
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/accounts');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      // ponytail: catch 时识别 ApiException 取 .message,而不是 toString()
      //          — Dio 原始 toString() 会把 RequestOptions/validateStatus
      //          一堆英文噪音全显示,改成后端友好文案(比如 "图标长度超出限制")。
      final msg = e is ApiException ? e.message : '$e';
      ref.read(toastControllerProvider.notifier).show(
            '${lang.t('accountAdd.saveFailPrefix')} $msg',
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final c = context.appColors;
    return Scaffold(
      appBar: AppHeader(title: lang.t('accountAdd.title'), back: true),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: c.bgCard,
              border: Border.all(color: c.divider),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 账户名称
                _Field(
                  label: lang.t('accountAdd.name'),
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.divider)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.primary)),
                      hintText: lang.t('accountAdd.namePlaceholder'),
                      hintStyle: TextStyle(color: c.textVariant),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // 账户类型(下拉)
                _Field(
                  label: lang.t('accountAdd.type'),
                  child: InkWell(
                    onTap: _pickType,
                    child: Container(
                      // ponytail: 垂直居中 — InputDecorator 默认 contentPadding
                      //          偏紧,文本贴底。换 Container + 自己控 padding,
                      //          文本用 Center 强制垂直居中,符合截图样式。
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: c.divider),
                        ),
                      ),
                      child: Row(
                        children: [
                          // ponytail: 展示区 label 用 picker 列表里第 i 项的
                          //          labelKey,而不是 _typeLabel(_type) ——
                          //          uniapp ACCOUNT_TYPES 里 wechat/alipay 都
                          //          共享 wallet type,旧逻辑会显示 .wallet =
                          //          "电子钱包",picker 里却是"微信支付",两侧
                          //          不一致。
                          Expanded(
                            child: Text(
                              lang.t(_typeItems[_typeLabelIndex].labelKey),
                              style: TextStyle(color: c.text, fontSize: 14),
                            ),
                          ),
                          Icon(Icons.expand_more, color: c.textVariant),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // 初始余额
                _Field(
                  label: lang.t('accountAdd.balance'),
                  child: TextField(
                    controller: _balanceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true, // 信用卡允许负余额
                    ),
                    // V1.2 金额核算审计:inputFormatters 拒绝粘贴板/IME 边角非法输入。
                    // 12 位整数 + . + 2 位小数 = 15 字符上限。
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^-?\d{0,12}(\.\d{0,2})?')),
                      LengthLimitingTextInputFormatter(16), // 13(12 + -) + . + 2
                    ],
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.divider)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: c.primary)),
                      prefixText: '¥ ',
                      prefixStyle: TextStyle(color: c.textVariant, fontSize: 14),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // 账户图标(5 个 emoji 单选)
                _Field(
                  label: lang.t('accountAdd.icon'),
                  child: Wrap(
                    spacing: AppSpacing.md,
                    runSpacing: AppSpacing.md,
                    children: [
                      for (final ic in _icons)
                        _IconRadio(
                          glyph: ic,
                          selected: ic == _icon,
                          onTap: () => setState(() => _icon = ic),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // 设为默认账户(开关)
                Divider(color: c.divider, height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              lang.t('accountAdd.isDefault'),
                              style: TextStyle(
                                color: c.text,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              lang.t('accountAdd.isDefaultHint'),
                              style: TextStyle(color: c.textVariant, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isDefault,
                        onChanged: (v) => setState(() => _isDefault = v),
                        activeThumbColor: c.primary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                // 取消 / 保存账户
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _submitting
                            ? null
                            : () {
                                if (context.canPop()) {
                                  context.pop();
                                } else {
                                  context.go('/accounts');
                                }
                              },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          side: BorderSide(color: c.divider),
                          foregroundColor: c.text,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(lang.t('accountAdd.cancel')),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submitting ? null : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          backgroundColor: _submitting ? c.primary.withValues(alpha: 0.5) : c.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        child: Text(lang.t('accountAdd.submitAccount')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickType() async {
    final lang = I18n.of(context);
    // ponytail: 对齐 uniapp new.vue ACCOUNT_TYPES — 7 个独立 label key,
    //          顺序:微信支付/支付宝/现金/银行卡/信用卡/投资账户/其他。
    //          注意:微信支付+支付宝 都映射到 AccountType.wallet(后端 type
    //          只有 6 个),银行卡用 .bank(不是 .debit)。所以 picker 列表
    //          不是 AccountType.values,而是独立的 (type, labelKey) 元组。
    const items = <_TypePickItem>[
      _TypePickItem(AccountType.wallet, 'accountAdd.type.wechat'),
      _TypePickItem(AccountType.wallet, 'accountAdd.type.alipay'),
      _TypePickItem(AccountType.cash, 'accountAdd.type.cash'),
      _TypePickItem(AccountType.debit, 'accountAdd.type.bank'),
      _TypePickItem(AccountType.credit, 'accountAdd.type.credit'),
      _TypePickItem(AccountType.investment, 'accountAdd.type.investment'),
      _TypePickItem(AccountType.other, 'accountAdd.type.other'),
    ];
    final initialIndex = items.indexWhere((it) => it.type == _type);
    final picked = await showModalBottomSheet<AccountType>(
      context: context,
      // ponytail: 对齐 uniapp picker 弹起的滚轮样式 — ListWheelScrollView +
      //          中间高亮上下两条横线(去掉高亮背景)。Flutter web 无原生
      //          picker,手撸一个 iOS-style 滚轮,点"完成"提交选中。
      backgroundColor: Theme.of(context).extension<AppThemeExt>()!.colors.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return _WheelPickerSheet<_TypePickItem>(
          items: items,
          initialIndex: initialIndex < 0 ? 0 : initialIndex,
          labelOf: (it) => lang.t(it.labelKey),
          onConfirm: (i) => Navigator.of(ctx).pop(items[i].type),
        );
      },
    );
    if (picked != null) {
      setState(() => _type = picked);
    }
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: c.text, fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: AppSpacing.sm),
        child,
      ],
    );
  }
}

class _IconRadio extends StatelessWidget {
  const _IconRadio({
    required this.glyph,
    required this.selected,
    required this.onTap,
  });
  final String glyph;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // ponytail: uniapp .icon-btn.selected { border-color: var(--c-primary);
          //          background: var(--c-primary-light) }
          border: Border.all(
            color: selected ? c.primary : c.divider,
            width: selected ? 2 : 1,
          ),
          color: selected ? c.primaryLight : Colors.transparent,
        ),
        alignment: Alignment.center,
        child: Text(
          glyph,
          style: TextStyle(
            fontSize: 22,
            height: 1,
            color: selected ? c.primary : c.textVariant,
          ),
        ),
      ),
    );
  }
}

/// 模仿 uniapp <picker mode="selector"> 的滚轮样式 — 5 行可见,中间一行高亮
/// 加上下淡出,顶栏"取消 / 完成"两个按钮。点完成才提交,中间滚动实时选中。
class _WheelPickerSheet<T> extends StatefulWidget {
  const _WheelPickerSheet({
    required this.items,
    required this.initialIndex,
    required this.labelOf,
    required this.onConfirm,
  });
  final List<T> items;
  final int initialIndex;
  final String Function(T) labelOf;
  final void Function(int index) onConfirm;

  @override
  State<_WheelPickerSheet<T>> createState() => _WheelPickerSheetState<T>();
}

class _WheelPickerSheetState<T> extends State<_WheelPickerSheet<T>> {
  late final FixedExtentScrollController _ctrl =
      FixedExtentScrollController(initialItem: widget.initialIndex);
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialIndex;
    // ponytail: 滚动时实时更新 _selected,build 期间根据 _selected 判断中间
    //          行的粗细/颜色。ListWheelScrollView 默认只在 stop 时通知
    //          selectedItemChanged;为了滚动过程中文字实时高亮,这里监听
    //          position,圆整到最近 item 后 setState。
    _ctrl.addListener(_onScroll);
  }

  void _onScroll() {
    // FixedExtentScrollPhysics 滚动会自然停在整数 item 上,圆整即可
    final next = _ctrl.selectedItem;
    if (next != _selected) {
      setState(() => _selected = next);
    }
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onScroll);
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppThemeExt>()!.colors;
    // 5 行可见,中间行高亮;itemExtent 是每行高度。
    const double itemHeight = 40;
    const double visibleRows = 5;
    const height = itemHeight * visibleRows;
    return SafeArea(
      child: SizedBox(
        height: height + 56, // 顶栏 56
        child: Column(
          children: [
            // 顶栏:取消 / 完成
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: c.divider)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('取消', style: TextStyle(color: c.text)),
                  ),
                  TextButton(
                    // 用 _selected(实时)而不是 _ctrl.selectedItem,惯性滚动停止
                    // 后 selectedItem 才同步,这里取 _selected 是用户视觉上
                    // 选中的那一行。
                    onPressed: () => widget.onConfirm(_selected),
                    child: Text('完成', style: TextStyle(color: c.primary, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
            // 滚轮
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  // 上下两条横线作为中选视觉锚点(对齐 uniapp picker:无背景,
                  // 仅上下细线高亮),用 IgnorePointer 不挡滚轮事件。
                  Positioned(
                    top: itemHeight * 2,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: IgnorePointer(
                      child: Container(height: 1, color: c.divider),
                    ),
                  ),
                  Positioned(
                    top: itemHeight * 2 + itemHeight - 1,
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    child: IgnorePointer(
                      child: Container(height: 1, color: c.divider),
                    ),
                  ),
                  // 滚轮列表 — 选中判断用 _selected(由 listener 实时更新),
                  //          不读 _ctrl.selectedItem,build 期间 selectedItem
                  //          在惯性滚动中可能滞后一帧。
                  ListWheelScrollView.useDelegate(
                    controller: _ctrl,
                    itemExtent: itemHeight,
                    physics: const FixedExtentScrollPhysics(),
                    perspective: 0.003,
                    diameterRatio: 1.8,
                    childDelegate: ListWheelChildBuilderDelegate(
                      childCount: widget.items.length,
                      builder: (ctx, i) {
                        final selected = i == _selected;
                        return Center(
                          child: Text(
                            widget.labelOf(widget.items[i]),
                            style: TextStyle(
                              color: selected ? c.text : c.textVariant,
                              fontSize: selected ? 17 : 15,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
