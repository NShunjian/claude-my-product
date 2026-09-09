import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';

class QuickAddState {
  QuickAddState({required this.show, required this.kind, required this.savedAt});
  final bool show;
  final RecordType kind;
  final int savedAt;

  QuickAddState copyWith({bool? show, RecordType? kind, int? savedAt}) => QuickAddState(
        show: show ?? this.show,
        kind: kind ?? this.kind,
        savedAt: savedAt ?? this.savedAt,
      );
}

/// 对齐 stores/quick-add.ts — show / kind / savedAt。
class QuickAddController extends Notifier<QuickAddState> {
  @override
  QuickAddState build() =>
      QuickAddState(show: false, kind: RecordType.expense, savedAt: 0);

  void open([RecordType k = RecordType.expense]) {
    state = state.copyWith(show: true, kind: k);
  }

  void close() {
    state = state.copyWith(show: false);
  }

  void notifySaved() {
    state = state.copyWith(savedAt: state.savedAt + 1);
  }

  /// 关弹窗 + 通知已保存,合成**一次** state 变更。
  /// 比 `close(); notifySaved();` 可靠 — 监听器只会收到一次 fire:
  ///   prev = (show:true,  savedAt:N)
  ///   next = (show:false, savedAt:N+1)
  /// 一次性看到 savedAt 变化,避免连续两次 state= 之间 listener 被吞掉、
  /// 或只看到其中一次而漏触发刷新。
  void closeAndNotify() {
    state = QuickAddState(
      show: false,
      kind: state.kind,
      savedAt: state.savedAt + 1,
    );
  }
}

final quickAddControllerProvider =
    NotifierProvider<QuickAddController, QuickAddState>(QuickAddController.new);
