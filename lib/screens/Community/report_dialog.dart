import 'package:flutter/material.dart';

const _reportReasons = [
  'Spam or advertising',
  'Off-topic / not about coffee farming',
  'Abusive or harassing',
  'Misinformation',
  'Something else',
];

/// Shows a reason picker and returns the chosen reason, or null if the user
/// cancelled. Kept as a single shared dialog rather than duplicating this
/// per post/comment widget.
Future<String?> showReportDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('Report this content'),
      children: [
        for (final reason in _reportReasons)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, reason),
            child: Text(reason),
          ),
      ],
    ),
  );
}
