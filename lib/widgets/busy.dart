import 'package:flutter/material.dart';

/// Показывает индикатор на время [task]; ошибки выводит снэкбаром.
/// Возвращает true, если задача завершилась без ошибки.
Future<bool> runBusy(
    BuildContext context, String message, Future<void> Function() task) async {
  final nav = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(children: [
          const CircularProgressIndicator(),
          const SizedBox(width: 20),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 17))),
        ]),
      ),
    ),
  );
  try {
    await task();
    return true;
  } catch (e) {
    final text = '$e'.replaceFirst(RegExp(r'^Exception: '), '');
    messenger.showSnackBar(SnackBar(
        content: Text('Ошибка: $text'), duration: const Duration(seconds: 6)));
    return false;
  } finally {
    nav.pop();
  }
}
