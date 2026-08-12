import 'package:flutter/material.dart';

Future<bool> confirmYesNo(
  BuildContext context, {
  required String title,
  required String message,
  String noLabel = 'No',
  String yesLabel = 'Yes',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text(noLabel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(yesLabel),
        ),
      ],
    ),
  );
  return result == true;
}
