import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/notification_service.dart';

class NotificationTile extends StatelessWidget {
  final NotificationModel model;
  final VoidCallback? onTap;
  final Future<void> Function()? onMarkRead;
  final Future<void> Function()? onDelete;
  final bool isAdmin;

  const NotificationTile({Key? key, required this.model, this.onTap, this.onMarkRead, this.onDelete, this.isAdmin = false}) : super(key: key);

  String _timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final unread = !model.read;
    final leadingIcon = model.orderId != null ? Icons.receipt_long_outlined : Icons.notifications_outlined;
    return Slidable(
      key: ValueKey(model.id),
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          SlidableAction(
            onPressed: (ctx) async {
              if (onMarkRead != null) await onMarkRead!();
            },
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            icon: Icons.mark_email_read,
            label: model.read ? 'Unread' : 'Mark read',
          ),
          SlidableAction(
            onPressed: (ctx) async {
              if (onDelete != null) await onDelete!();
            },
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete_forever,
            label: 'Delete',
          ),
        ],
      ),
      child: Material(
        color: unread ? Theme.of(context).colorScheme.primary.withOpacity(0.03) : null,
        child: ListTile(
          leading: CircleAvatar(child: Icon(leadingIcon, size: 18), backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
          title: Row(children: [
            Expanded(child: Text(model.title, style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w600))),
            const SizedBox(width: 8),
            Text(_timeAgo(model.createdAt), style: Theme.of(context).textTheme.bodySmall)
          ]),
          subtitle: Text(model.body, maxLines: 2, overflow: TextOverflow.ellipsis),
          trailing: PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'read' && onMarkRead != null) await onMarkRead!();
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'read', child: Text(model.read ? 'Mark unread' : 'Mark read')),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
