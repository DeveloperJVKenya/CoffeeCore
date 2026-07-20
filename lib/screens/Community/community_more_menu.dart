import 'package:flutter/material.dart';

/// Shared overflow menu for a post or comment: the author sees "Delete",
/// everyone else sees "Report" — never both, so there's no risk of an
/// author accidentally reporting their own content instead of deleting it.
class CommunityMoreMenu extends StatelessWidget {
  final bool isOwn;
  final VoidCallback onDelete;
  final VoidCallback onReport;

  const CommunityMoreMenu({
    super.key,
    required this.isOwn,
    required this.onDelete,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 18),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'delete') onDelete();
        if (value == 'report') onReport();
      },
      itemBuilder: (context) => [
        if (isOwn)
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          )
        else
          const PopupMenuItem(
            value: 'report',
            child: Text('Report'),
          ),
      ],
    );
  }
}
