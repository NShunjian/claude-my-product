import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/i18n/lang.dart';
import '../../core/i18n/locale_provider.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/category_presentation.dart';
import '../../core/utils/date_util.dart';
import '../../core/utils/finance.dart';
import '../shared/providers.dart';
import '../shared/quick_add_controller.dart';
import '../shared/toast_controller.dart';
import '../shared/wheel_date_picker.dart';

/// 对齐 components/QuickAddModal.vue — 顶部悬浮式快捷记一笔。
/// 结构(head + 金额 + 分类 4 列网格 + 账户 chips + 日期/备注 + 数字键盘)
/// 严格按 uniapp .qa-* 类来,色板/字号/间距走 tokens.dart。
class QuickAddModal extends ConsumerStatefulWidget {
  const QuickAddModal({super.key});

  @override
  ConsumerState<QuickAddModal> createState() => _QuickAddModalState();
}

class _QuickAddModalState extends ConsumerState<QuickAddModal>
    with SingleTickerProviderStateMixin {
  late Future<_QuickAddData> _future;
  // 最近一次成功加载的数据 — 切 tab 时保留旧 grid 可见,避免一闪 loading。
  _QuickAddData? _data;
  RecordType _kind = RecordType.expense;
  // 每个 tab 独立的选中态 — 切走再切回来会保留上次的选项;
  // 新分类列表里若不再包含该 tab 的旧选中,只清掉当前 tab 的 entry。
  final Map<RecordType, Category?> _selectedByKind = {
    RecordType.expense: null,
    RecordType.income: null,
  };
  Account? _account;
  String _recordDate = todayLocal();
  final _noteCtrl = TextEditingController();
  bool _submitting = false;
  bool _showSuccess = false;
  // 数字键盘表达式(对齐 uniapp .qa-keypad:digits/. + back/+/−/✓)。
  // 最多 12 字符;_computeAmount() 解析 '+' 分段求和。
  String _expression = '';
  // 金额光标闪烁动画
  late final AnimationController _cursorCtrl;
  // 监听 quickAddControllerProvider 用 — 每次弹窗由 false → true 打开瞬间,
  // 把 _recordDate 重置为今天(用户要求:每次进入弹窗页面日期都是今年今月今日)。
  late final ProviderSubscription<QuickAddState> _modalSub;

  @override
  void initState() {
    super.initState();
    final s = ref.read(quickAddControllerProvider);
    _kind = s.kind;
    _future = _loadAll();
    _cursorCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
    _modalSub = ref.listenManual<QuickAddState>(
      quickAddControllerProvider,
      (prev, next) {
        final wasHidden = !(prev?.show ?? false);
        if (wasHidden && next.show && mounted) {
          setState(() {
            _recordDate = todayLocal();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _modalSub.close();
    _noteCtrl.dispose();
    _cursorCtrl.dispose();
    super.dispose();
  }

  Future<_QuickAddData> _loadAll() async {
    final bookId = ref.read(currentBookIdProvider);
    final accs = await ref
        .read(accountsApiProvider)
        .listAccounts(bookId: bookId.isEmpty ? null : bookId);
    // 一次性把两类分类都拉下来 — 切 tab 时不需要再请求,纯内存切换,
    // 选中态改变只在新页面的列表上发生,旧页面不再可见,避免「提前高亮」。
    final all = await ref.read(categoriesApiProvider).listCategories();
    final data = _QuickAddData(
      expenseCategories:
          all.where((c) => c.type == CategoryType.expense).toList(),
      incomeCategories:
          all.where((c) => c.type == CategoryType.income).toList(),
      accounts: accs,
    );
    if (mounted) {
      _data = data;
      // 只清掉「在新列表里找不到」的旧选中,其他 tab 的选中态保留。
      for (final kind in RecordType.values) {
        final sel = _selectedByKind[kind];
        final list = data.categoriesFor(kind);
        if (sel != null && !list.any((c) => c.id == sel.id)) {
          _selectedByKind[kind] = null;
        }
      }
    }
    return data;
  }

  void _setKind(RecordType kind) {
    if (_kind == kind) return;
    setState(() {
      // 只换当前 tab;分类数据在 init 时一次性全量加载,这里纯内存切换。
      // _selectedByKind 里两个 kind 的选中态各自保留 — 切走再切回来会恢复。
      // 旧 tab 立刻不可见,所以也不会出现「在旧页面上提前改变选中态」。
      _kind = kind;
    });
  }

  Future<void> _submit() async {
    final lang = I18n.of(context);
    final amount = _computeAmount();
    if (amount <= 0) {
      ref
          .read(toastControllerProvider.notifier)
          .show(lang.t('recordExpense.amountPrompt'));
      return;
    }
    if (_selectedByKind[_kind] == null) {
      ref
          .read(toastControllerProvider.notifier)
          .show(lang.t('recordExpense.categoryRequired'));
      return;
    }
    if (_account == null) {
      ref
          .read(toastControllerProvider.notifier)
          .show(lang.t('recordExpense.accountRequired'));
      return;
    }
    setState(() => _submitting = true);
    try {
      final api = ref.read(recordsApiProvider);
      final note = _noteCtrl.text.trim();
      final catId = _selectedByKind[_kind]!.id;
      final accId = _account!.id;
      if (_kind == RecordType.income) {
        await api.createRecord(CreateIncomeInput(
          amount: amount,
          accountId: accId,
          categoryId: catId,
          recordDate: _recordDate,
          note: note.isEmpty ? null : note,
        ),
      );
      } else {
        await api.createRecord(
          CreateExpenseInput(
            amount: amount,
            accountId: accId,
            categoryId: catId,
            recordDate: _recordDate,
            note: note.isEmpty ? null : note,
          ),
        );
      }
      if (!mounted) return;
      // 成功态:展示对勾 + 文案,1.2s 后关闭弹窗并通知首页刷新。
      setState(() => _showSuccess = true);
      Future.delayed(const Duration(milliseconds: 1200), () {
        if (!mounted) return;
        // 一次性关闭 + 通知 — 见 QuickAddController.closeAndNotify 的注释,
        // 避免 close()/notifySaved() 分两次 state= 漏 fire 监听器。
        ref.read(quickAddControllerProvider.notifier).closeAndNotify();
        _reset();
      });
    } catch (e) {
      if (!mounted) return;
      ref
          .read(toastControllerProvider.notifier)
          .show('${lang.t('common.submitFailed')} ($e)');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _reset() {
    _noteCtrl.clear();
    setState(() {
      _selectedByKind[RecordType.expense] = null;
      _selectedByKind[RecordType.income] = null;
      _expression = '';
      _recordDate = todayLocal();
      _showSuccess = false;
    });
  }

  // ===== 数字键盘表达式(对齐 uniapp pressKey + computeAmount) =====

  double _computeAmount() {
    if (_expression.isEmpty) return 0;
    if (!_expression.contains('+')) {
      final n = double.tryParse(_expression) ?? 0;
      return n.isFinite ? n : 0;
    }
    return _expression
        .split('+')
        .fold<double>(0, (s, x) => s + (double.tryParse(x) ?? 0));
  }

  void _pressKey(String key) {
    setState(() {
      if (key == 'back') {
        if (_expression.isNotEmpty) {
          _expression = _expression.substring(0, _expression.length - 1);
        }
        return;
      }
      if (key == '+' || key == '−') {
        if (_expression.isEmpty) {
          _expression = '0+';
        } else {
          final last = _expression[_expression.length - 1];
          if (last == '+' || last == '-') {
            _expression = '${_expression.substring(0, _expression.length - 1)}+';
          } else {
            _expression = '$_expression+';
          }
        }
        return;
      }
      if (key == '.') {
        final seg = _expression.split(RegExp(r'[+\-]')).last;
        if (!seg.contains('.')) _expression = '$_expression.';
        return;
      }
      if (key == '✓') {
        // 提交按键 — 复用 _submit 流程。
        _submit();
        return;
      }
      // 数字
      if (_expression.length >= 12) return;
      _expression = '$_expression$key';
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = I18n.of(context);
    final visible = ref.watch(quickAddControllerProvider.select((s) => s.show));

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: visible
          ? _buildModal(lang)
          : const SizedBox.shrink(key: ValueKey('quick-add-hidden')),
    );
  }

  Widget _buildModal(Lang lang) {
    // uniapp .qa-overlay 背景 = #141E3C(顶部 navy 实心,跟 sheet 顶圆角衔接)。
    // 注意:外面 app.dart 已经 Positioned.fill(child: QuickAddModal()) 了一层,
    // 这里不能再 Positioned.fill — 否则 Positioned 会落在 AnimatedSwitcher 的
    // FadeTransition 之下,而 FadeTransition 不是 Stack 祖先,触发
    // ParentDataWidget 类型不兼容。直接返回 Material 即可,Material 默认填满父级。
    const navy = Color(0xFF141E3C);
    return Material(
      key: const ValueKey('quick-add-shown'),
      color: navy,
      child: SafeArea(
          top: false,
          child: FutureBuilder<_QuickAddData>(
            future: _future,
            builder: (context, snap) {
              // 加载中用上次缓存的 _data,切 tab 时旧 grid 保持可见,
              // 不会出现「分类加载中...」一闪。新数据到位后这里会换成新数据。
              final data = snap.data ?? _data;
              if (data == null) {
                return Center(
                  child: Text(
                    lang.t('recordModal.categoryLoading'),
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
              // 默认账户(账户列表不随 kind 变,首次填一次即可)
              if (_account == null && data.accounts.isNotEmpty) {
                _account = data.accounts.first;
              }
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // 成功态全屏覆盖
                  if (_showSuccess)
                    _SuccessOverlay(
                      isExpense: _kind == RecordType.expense,
                      lang: lang,
                    )
                  else
                    _SheetForm(
                      data: data,
                      kind: _kind,
                      category: _selectedByKind[_kind],
                      account: _account,
                      recordDate: _recordDate,
                      noteCtrl: _noteCtrl,
                      expression: _expression,
                      submitting: _submitting,
                      cursorCtrl: _cursorCtrl,
                      lang: lang,
                      onClose: () => _submitting
                          ? null
                          : ref
                              .read(quickAddControllerProvider.notifier)
                              .close(),
                      onSetKind: _setKind,
                      onPickCategory: (c) => setState(() => _selectedByKind[_kind] = c),
                      onPickAccount: (a) => setState(() => _account = a),
                      onPickDate: () => _pickDate(),
                      onKey: _pressKey,
                    ),
                ],
              );
            },
          ),
        ),
    );
  }

  Future<void> _pickDate() async {
    // iOS 风格滚轮 picker(对齐 uniapp `<picker mode="date">`):
    // 取消/完成 header + 年/月/日 三列滚轮。
    // QuickAddModal 现在挂在 _TabScaffold.body Stack 里,GoRouter 的 Navigator 是
    // 它的祖先 — context 直接拿来给 showModalBottomSheet 即可,bottom sheet 会叠在 Modal 之上。
    // 默认初始日期固定为今天 — 不复用上次的 _recordDate,保证每次弹出都是"今年今月今日"。
    final initial = DateTime.now();
    final picked = await WheelDatePicker.show(
      context,
      initial: initial,
    );
    if (picked != null) {
      setState(() {
        _recordDate =
            '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }
}

class _QuickAddData {
  _QuickAddData({
    required this.expenseCategories,
    required this.incomeCategories,
    required this.accounts,
  });
  final List<Category> expenseCategories;
  final List<Category> incomeCategories;
  final List<Account> accounts;

  /// 切 tab 时按当前 kind 选对应列表 — 纯内存,无网络/loading。
  List<Category> categoriesFor(RecordType kind) =>
      kind == RecordType.income ? incomeCategories : expenseCategories;
}

/// Sheet 主体(head + scrollable 中段 + sticky keypad)。
class _SheetForm extends StatelessWidget {
  const _SheetForm({
    required this.data,
    required this.kind,
    required this.category,
    required this.account,
    required this.recordDate,
    required this.noteCtrl,
    required this.expression,
    required this.submitting,
    required this.cursorCtrl,
    required this.lang,
    required this.onClose,
    required this.onSetKind,
    required this.onPickCategory,
    required this.onPickAccount,
    required this.onPickDate,
    required this.onKey,
  });

  final _QuickAddData data;
  final RecordType kind;
  final Category? category;
  final Account? account;
  final String recordDate;
  final TextEditingController noteCtrl;
  final String expression;
  final bool submitting;
  final AnimationController cursorCtrl;
  final Lang lang;
  final VoidCallback? onClose;
  final ValueChanged<RecordType> onSetKind;
  final ValueChanged<Category> onPickCategory;
  final ValueChanged<Account> onPickAccount;
  final VoidCallback onPickDate;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      // 顶部两角 12dp 圆角,底部抵屏边直角 — 对齐 uniapp .qa-sheet
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
        border: Border.all(color: c.divider),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.96,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Head(
            kind: kind,
            lang: lang,
            onClose: onClose,
            onSetKind: onSetKind,
          ),
          // 中段整体不允许上下滑动 — 严格按截图,所有分类+账户+日期直接完整展示。
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AmountDisplay(
                kind: kind,
                expression: expression,
                cursorCtrl: cursorCtrl,
                lang: lang,
              ),
              _CategoryGrid(
                categories: data.categoriesFor(kind),
                selected: category,
                lang: lang,
                onTap: onPickCategory,
              ),
              _AccountChips(
                accounts: data.accounts,
                selected: account,
                lang: lang,
                onTap: onPickAccount,
              ),
              _MetaRow(
                recordDate: recordDate,
                noteCtrl: noteCtrl,
                lang: lang,
                onPickDate: onPickDate,
              ),
            ],
          ),
          _KeypadGrid(
            isExpense: kind == RecordType.expense,
            submitting: submitting,
            onKey: onKey,
          ),
        ],
      ),
    );
  }
}

/// 顶部:X 关闭 + 支出/收入 tabs + 右侧 spacer
/// 对齐 uniapp .qa-head + .qa-close + .qa-tabs + .qa-tab.active
class _Head extends StatelessWidget {
  const _Head({
    required this.kind,
    required this.lang,
    required this.onClose,
    required this.onSetKind,
  });

  final RecordType kind;
  final Lang lang;
  final VoidCallback? onClose;
  final ValueChanged<RecordType> onSetKind;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          // 关闭 X — 56rpx 触控区(uniapp)
          SizedBox(
            width: 28,
            height: 28,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(14),
              child: Center(
                child: Text(
                  '✕',
                  style: TextStyle(
                    color: c.textVariant,
                    fontSize: 16,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
          // tabs 容器:surface bg + 4dp 内边距,内部两个 tab
          Expanded(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _Tab(
                      label: lang.t('recordModal.expense'),
                      active: kind == RecordType.expense,
                      onTap: () => onSetKind(RecordType.expense),
                    ),
                    _Tab(
                      label: lang.t('recordModal.income'),
                      active: kind == RecordType.income,
                      onTap: () => onSetKind(RecordType.income),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 右侧 spacer(与左侧 X 宽度一致,保持 tabs 居中)
          const SizedBox(width: 28),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: active ? c.bgCard : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: active
              ? [
                  const BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 2,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? c.primary : c.textVariant,
            fontSize: 13,
            fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 金额显示:小字 hint + ¥ 数字 |(光标闪烁)+ 数字下加 2dp 主色下划线
class _AmountDisplay extends StatelessWidget {
  const _AmountDisplay({
    required this.kind,
    required this.expression,
    required this.cursorCtrl,
    required this.lang,
  });

  final RecordType kind;
  final String expression;
  final AnimationController cursorCtrl;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final amount = _compute(expression);
    return Container(
      // uniapp .qa-amount 整段是 c.surface(更暗一档)做底,跟 sheet 区分
      color: c.bg,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Text(
            kind == RecordType.expense
                ? lang.t('recordExpense.amountPrompt')
                : lang.t('recordIncome.amountPrompt'),
            style: TextStyle(color: c.textVariant, fontSize: 11),
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '¥',
                style: TextStyle(
                  color: c.textVariant,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(width: 4),
              // 数字 + 2dp 主色下划线 — 光标放在外面,只让数字本身加底线
              // (对齐 uniapp .qa-amount-num { border-bottom } + .qa-cursor 紧贴右侧)
              Container(
                constraints: const BoxConstraints(minWidth: 100),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: c.primary, width: 2),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  amount == 0 ? '0.00' : formatAmount(amount).replaceFirst('¥', ''),
                  style: TextStyle(
                    color: c.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // 闪烁光标 — 独立元素,在下划线 Container 右侧,本身不带下划线
              FadeTransition(
                opacity: cursorCtrl.drive(const _BlinkTween(0.4, 1.0)),
                child: Text(
                  '|',
                  style: TextStyle(
                    color: c.text,
                    fontSize: 20,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  double _compute(String expr) {
    if (expr.isEmpty) return 0;
    if (!expr.contains('+')) {
      final n = double.tryParse(expr) ?? 0;
      return n.isFinite ? n : 0;
    }
    return expr
        .split('+')
        .fold<double>(0, (s, x) => s + (double.tryParse(x) ?? 0));
  }
}

class _BlinkTween extends Animatable<double> {
  const _BlinkTween(this.begin, this.end);
  final double begin;
  final double end;
  @override
  double transform(double t) => begin + (end - begin) * t;
}

/// 分类 4 列网格(uniapp .qa-cats-grid)。每个 cell = 圆形(cat 色调 14% alpha / 选中
/// 时填实色)+ emoji + 文字;选中时文字加粗变色。
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.lang,
    required this.onTap,
  });

  final List<Category> categories;
  final Category? selected;
  final Lang lang;
  final ValueChanged<Category> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (categories.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Center(
          child: Text(
            lang.t('recordModal.categoryLoading'),
            style: TextStyle(color: c.textVariant, fontSize: 13),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          // 行/列间距都收到最小档 — 截图里图标贴得很紧
          mainAxisSpacing: 2,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.0,
        ),
        itemCount: categories.length,
        itemBuilder: (context, i) {
          final cat = categories[i];
          return _CategoryCell(
            cat: cat,
            selected: cat.id == selected?.id,
            onTap: () => onTap(cat),
          );
        },
      ),
    );
  }
}

class _CategoryCell extends StatelessWidget {
  const _CategoryCell({
    required this.cat,
    required this.selected,
    required this.onTap,
  });

  final Category cat;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pres = presentCategory(cat);
    final tint = _parseTint(pres.color);
    final color = _parseHex(pres.color);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: selected ? color : tint,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? color : Colors.transparent,
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              pres.icon,
              style: TextStyle(
                fontSize: 22,
                height: 1,
                color: selected ? Colors.white : color,
                fontStyle: FontStyle.normal,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            cat.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? color : c.text,
              fontSize: 11,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// 账户 chips(uniapp .qa-accounts):左 label + 右横向 scroll 一排胶囊,选中态主色填。
class _AccountChips extends StatelessWidget {
  const _AccountChips({
    required this.accounts,
    required this.selected,
    required this.lang,
    required this.onTap,
  });

  final List<Account> accounts;
  final Account? selected;
  final Lang lang;
  final ValueChanged<Account> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (accounts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Text(
            lang.t('recordModal.accountLabel'),
            style: TextStyle(color: c.textVariant, fontSize: 11),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final a in accounts) ...[
                    _AccountChip(
                      account: a,
                      active: a.id == selected?.id,
                      onTap: () => onTap(a),
                    ),
                    const SizedBox(width: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountChip extends StatelessWidget {
  const _AccountChip({
    required this.account,
    required this.active,
    required this.onTap,
  });

  final Account account;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: active ? c.primary : c.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('💳', style: TextStyle(fontSize: 11, height: 1)),
            const SizedBox(width: 4),
            Text(
              account.name,
              style: TextStyle(
                color: active ? Colors.white : c.text,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 日期 + 备注行(uniapp .qa-meta)。两个 chip 风格:日期带 📅,备注 placeholder。
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.recordDate,
    required this.noteCtrl,
    required this.lang,
    required this.onPickDate,
  });

  final String recordDate;
  final TextEditingController noteCtrl;
  final Lang lang;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Row(
        children: [
          InkWell(
            onTap: onPickDate,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('📅', style: TextStyle(fontSize: 12, height: 1)),
                  const SizedBox(width: 4),
                  Text(
                    recordDate,
                    style: TextStyle(color: c.text, fontSize: 12),
                  ),
                  const SizedBox(width: 4),
                  // 末尾 ▾ — 显式告诉用户这是个 picker 可点(uniapp 是浏览器原生 picker,
                  // 视觉上有日历图标提示;这里给个紧凑箭头保持一致)
                  Icon(
                    Icons.expand_more,
                    size: 14,
                    color: c.textVariant,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: TextField(
              controller: noteCtrl,
              maxLength: 50,
              style: TextStyle(color: c.text, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                hintText: lang.t('recordModal.notePlaceholder'),
                hintStyle: TextStyle(color: c.textVariant, fontSize: 12),
                counterText: '',
                fillColor: c.surface,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 数字键盘 4×4 网格(uniapp .qa-keypad)。sticky 钉在 sheet 底,grid layout,
/// ✓ 按键支出=primary(蓝),收入=绿色 — 对齐 v-bind(accentBg)。
class _KeypadGrid extends StatelessWidget {
  const _KeypadGrid({
    required this.isExpense,
    required this.submitting,
    required this.onKey,
  });

  final bool isExpense;
  final bool submitting;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    final rows = <List<_KeyDef>>[
      [
        const _KeyDef('1'),
        const _KeyDef('2'),
        const _KeyDef('3'),
        const _KeyDef('⌫', kind: _KeyKind.back),
      ],
      [
        const _KeyDef('4'),
        const _KeyDef('5'),
        const _KeyDef('6'),
        const _KeyDef('+', kind: _KeyKind.op),
      ],
      [
        const _KeyDef('7'),
        const _KeyDef('8'),
        const _KeyDef('9'),
        const _KeyDef('−', kind: _KeyKind.op),
      ],
      [
        const _KeyDef('0', span: 2),
        const _KeyDef('.'),
        const _KeyDef('✓', kind: _KeyKind.confirm),
      ],
    ];
    return Container(
      color: context.appColors.bgCard,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  for (var i = 0; i < row.length; i++) ...[
                    Expanded(
                      flex: row[i].span,
                      child: _Key(
                        def: row[i],
                        isExpense: isExpense,
                        submitting: submitting,
                        onTap: () => onKey(row[i].value),
                      ),
                    ),
                    if (i < row.length - 1)
                      const SizedBox(width: AppSpacing.xs),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _KeyKind { digit, back, op, confirm }

class _KeyDef {
  const _KeyDef(this.value, {this.kind = _KeyKind.digit, this.span = 1});
  final String value;
  final _KeyKind kind;
  final int span;
}

class _Key extends StatelessWidget {
  const _Key({
    required this.def,
    required this.isExpense,
    required this.submitting,
    required this.onTap,
  });

  final _KeyDef def;
  final bool isExpense;
  final bool submitting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    Color bg;
    Color fg;
    switch (def.kind) {
      case _KeyKind.confirm:
        // 支出=primary 蓝,收入=#10B981 绿 — 跟 v-bind(accentBg) 一样
        bg = isExpense ? c.primary : const Color(0xFF10B981);
        fg = Colors.white;
        break;
      case _KeyKind.back:
      case _KeyKind.op:
        bg = c.surface;
        fg = c.textVariant;
        break;
      case _KeyKind.digit:
        bg = c.surface;
        fg = c.text;
    }
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onTap,
        child: Container(
          height: 36,
          alignment: Alignment.center,
          child: def.kind == _KeyKind.confirm && submitting
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  def.value,
                  style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: def.kind == _KeyKind.confirm
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}

/// 成功态:大圆对勾 + 文案(uniapp .qa-success)。
class _SuccessOverlay extends StatelessWidget {
  const _SuccessOverlay({required this.isExpense, required this.lang});

  final bool isExpense;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    // 收入用绿色对勾,支出用 primary 蓝
    final accent = isExpense ? c.primary : const Color(0xFF10B981);
    final accentLight = isExpense
        ? c.primaryLight
        : const Color(0x1410B981); // green @ 14% alpha
    return Container(
      // 顶两角圆角,跟 sheet 一致
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 60,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: c.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        border: Border.all(color: c.divider),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: accentLight,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              '✓',
              style: TextStyle(
                color: accent,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            isExpense
                ? lang.t('recordExpense.success')
                : lang.t('recordIncome.success'),
            style: TextStyle(
              color: c.text,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ===== 颜色工具 =====

Color _parseHex(String hex) {
  final h = hex.replaceFirst('#', '');
  return Color(int.parse('FF$h', radix: 16));
}

/// 把 #RRGGBB 转成 rgba(r,g,b,0.14) — 对应 uniapp catTint 14% alpha
Color _parseTint(String hex) {
  final h = hex.replaceFirst('#', '');
  if (h.length != 6) return _parseHex(hex).withValues(alpha: 0.14);
  final r = int.parse(h.substring(0, 2), radix: 16);
  final g = int.parse(h.substring(2, 4), radix: 16);
  final b = int.parse(h.substring(4, 6), radix: 16);
  return Color.fromARGB(36, r, g, b);
}
