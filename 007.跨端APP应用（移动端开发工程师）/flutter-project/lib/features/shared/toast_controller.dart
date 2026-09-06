import 'package:flutter_riverpod/flutter_riverpod.dart';

class ToastItem {
  ToastItem({required this.id, required this.message});
  final int id;
  final String message;
}

class ToastController extends Notifier<List<ToastItem>> {
  int _seq = 0;

  @override
  List<ToastItem> build() => const [];

  void show(String message, {Duration duration = const Duration(milliseconds: 3000)}) {
    final id = ++_seq;
    state = [...state, ToastItem(id: id, message: message)];
    Future.delayed(duration, () {
      state = state.where((t) => t.id != id).toList();
    });
  }

  void dismiss(int id) {
    state = state.where((t) => t.id != id).toList();
  }
}

final toastControllerProvider =
    NotifierProvider<ToastController, List<ToastItem>>(ToastController.new);
