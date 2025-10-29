import 'package:flutter/material.dart';
import '../models/order.dart';
import '../services/order_service.dart';
import '../services/notification_service.dart';
import '../widgets/notification_tile.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class AdminOrdersPage extends StatefulWidget {
  const AdminOrdersPage({super.key});

  @override
  State<AdminOrdersPage> createState() => _AdminOrdersPageState();
}

Color _statusColor(BuildContext context, OrderStatus s) {
  final c = Theme.of(context).colorScheme;
  switch (s) {
    case OrderStatus.pending:
      return c.secondaryContainer;
    case OrderStatus.accepted:
      return Colors.blue.shade200;
    case OrderStatus.preparing:
      return Colors.orange.shade300;
    case OrderStatus.outForDelivery:
      return Colors.indigo.shade300;
    case OrderStatus.completed:
      return Colors.green.shade300;
    case OrderStatus.cancelled:
      return Colors.red.shade300;
    case OrderStatus.refunded:
      return Colors.purple.shade300;
  }
}

Widget _statusChip(BuildContext context, OrderStatus s) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _statusColor(context, s),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(s.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
  );
}

class _AdminOrdersPageState extends State<AdminOrdersPage> {
  final _service = OrderService.instance;
  String _search = '';
  String _view = 'Board';
  final ScrollController _hScroll = ScrollController();

  @override
  void dispose() {
    _hScroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
  final screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Management'),
        actions: [
          _adminNotificationBell(),
          const SizedBox(width: 8),
          _viewSwitch(theme),
          const SizedBox(width: 8),
          LayoutBuilder(builder: (context, constraints) {
            // keep the search field constrained so AppBar actions don't overflow on narrow widths
            final maxAllowed = (screenWidth - 200).clamp(120.0, 320.0);
            return ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxAllowed, minWidth: 120),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search order id, customer, email',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            );
          }),
        ],
      ),
      body: Column(
        children: [
          _statusPills(theme),
          Expanded(
            child: _view == 'Board' ? _board(theme) : _table(theme),
          ),
        ],
      ),
    );
  }

  Widget _viewSwitch(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(.5),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(children: [
        _segBtn('Board'),
        _segBtn('Table'),
      ]),
    );
  }

  // Admin notification bell: shows unread admin notifications and opens admin notifications sheet
  Widget _adminNotificationBell() {
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountAdmin(),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(children: [
          IconButton(onPressed: _openAdminNotificationsSheet, icon: const Icon(Icons.notifications_active_outlined)),
          if (count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
                child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.center),
              ),
            )
        ]);
      },
    );
  }

  void _openAdminNotificationsSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 420,
          child: StreamBuilder<List<NotificationModel>>(
            stream: NotificationService.instance.streamAdmin(),
            builder: (context, snap) {
              if (snap.hasError) {
                // Firestore often returns an error when a composite index is required.
                // Provide a helpful UI with a link to create the index in the Firebase console.
                final indexUrl = 'https://console.firebase.google.com/v1/r/project/doughminant-8644e/firestore/indexes?create_composite=Cldwcm9qZWN0cy9kb3VnaG1pbmFudC04NjQ0ZS9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvbm90aWZpY2F0aW9ucy9pbmRleGVzL18QARoMCghmb3JBZG1pbhABGg0KCWNyZWF0ZWRBdBACGgwKCF9fbmFtZV9fEAI';
                return Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                    const SizedBox(height: 8),
                    const Text('Unable to load admin notifications — Firestore requires an index.', textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(indexUrl);
                        if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open browser')));
                        }
                      },
                      icon: const Icon(Icons.open_in_new),
                      label: const Text('Create index in Firebase Console'),
                    ),
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: indexUrl));
                        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Index URL copied to clipboard')));
                      },
                      child: const Text('Copy index URL'),
                    ),
                  ]),
                );
              }

              final notes = snap.data ?? [];
              if (notes.isEmpty) return const Center(child: Text('No notifications'));
                  return ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final n = notes[i];
                      return NotificationTile(
                        model: n,
                        isAdmin: true,
                        onMarkRead: () => NotificationService.instance.markRead(n.id),
                            onDelete: () => NotificationService.instance.delete(n.id),
                        onTap: () async {
                          await NotificationService.instance.markRead(n.id);
                          if (!mounted) return;
                          // focus the table view and search for the order id if available
                          if (n.orderId != null && n.orderId!.isNotEmpty) {
                            setState(() {
                              _view = 'Table';
                              _search = n.orderId!;
                            });
                          }
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
            },
          ),
        ),
      ),
    );
  }

  Widget _segBtn(String v) {
    final on = _view == v;
    return GestureDetector(
      onTap: () => setState(() => _view = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: on ? Colors.deepOrangeAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(v, style: TextStyle(color: on ? Colors.white : null, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _statusPills(ThemeData theme) {
    final statuses = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.outForDelivery,
      OrderStatus.completed,
      OrderStatus.cancelled,
      OrderStatus.refunded,
    ];
    return SizedBox(
      height: 54,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: statuses.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final s = statuses[i];
          return _StatusPill(status: s, search: _search);
        },
      ),
    );
  }

  Widget _board(ThemeData theme) {
    final cols = [
      OrderStatus.pending,
      OrderStatus.accepted,
      OrderStatus.preparing,
      OrderStatus.outForDelivery,
      OrderStatus.completed,
    ];
    return Scrollbar(
      controller: _hScroll,
      child: ListView(
        controller: _hScroll,
        scrollDirection: Axis.horizontal,
        children: [
          const SizedBox(width: 8),
          for (final s in cols) _BoardColumn(status: s, search: _search),
          _SideColumn(status: OrderStatus.cancelled, search: _search),
          _SideColumn(status: OrderStatus.refunded, search: _search),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _table(ThemeData theme) {
    return StreamBuilder<List<OrderModel>>(
      stream: _service.streamOrders(query: _search),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}'));
        final orders = snapshot.data ?? [];
        if (orders.isEmpty) return _empty();
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('Order #')),
              DataColumn(label: Text('Customer')),
              DataColumn(label: Text('Total')),
              DataColumn(label: Text('Payment')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('Priority')),
              DataColumn(label: Text('Created')),
              DataColumn(label: Text('ETA')),
              DataColumn(label: Text('Actions')),
            ],
            rows: [
              for (final o in orders)
                DataRow(cells: [
                  DataCell(Text(o.id)),
                  DataCell(Text(o.customerName ?? o.customerEmail ?? o.userId)),
                  DataCell(Text('₱${o.total.toStringAsFixed(2)}')),
                  DataCell(Text(PaymentStatus.values[o.paymentStatus.index].name)),
                  DataCell(_statusChip(context, o.status)),
                  DataCell(_priorityBadge(o.priority)),
                  DataCell(Text(_fmt(o.createdAt))),
                  DataCell(Text(o.eta != null ? _fmt(o.eta!) : '-')),
                  DataCell(
                    // constrain actions cell and allow wrapping to avoid RenderFlex overflow on narrow widths
                    SizedBox(
                      width: 200,
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _PrimaryProgressButton(order: o),
                          _RowMenu(order: o),
                        ],
                      ),
                    ),
                  ),
                ])
            ],
          ),
        );
      },
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
          SizedBox(height: 12),
          Text('No orders yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }


  Widget _priorityBadge(int p) {
    final label = switch (p) { 2 => 'Urgent', 1 => 'High', _ => 'Normal' };
    final color = switch (p) { 2 => Colors.red, 1 => Colors.orange, _ => Colors.grey };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(.4))),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final OrderStatus status;
  final String search;
  const _StatusPill({required this.status, required this.search});

  @override
  Widget build(BuildContext context) {
    final s = OrderService.instance;
    return StreamBuilder<List<OrderModel>>(
      stream: s.streamOrders(statuses: [status], query: search),
      builder: (context, snapshot) {
        final count = snapshot.data?.length ?? 0;
        final color = switch (status) {
          OrderStatus.pending => Colors.grey,
          OrderStatus.accepted => Colors.blue,
          OrderStatus.preparing => Colors.orange,
          OrderStatus.outForDelivery => Colors.indigo,
          OrderStatus.completed => Colors.green,
          OrderStatus.cancelled => Colors.red,
          OrderStatus.refunded => Colors.purple,
        };
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(.35)),
          ),
          child: Row(children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(_title(status)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: color.withOpacity(.2), borderRadius: BorderRadius.circular(12)),
              child: Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.w800)),
            ),
          ]),
        );
      },
    );
  }

  String _title(OrderStatus s) =>
      {
        OrderStatus.pending: 'Pending',
        OrderStatus.accepted: 'Accepted',
        OrderStatus.preparing: 'Preparing',
        OrderStatus.outForDelivery: 'Out for Delivery',
        OrderStatus.completed: 'Completed',
        OrderStatus.cancelled: 'Cancelled',
        OrderStatus.refunded: 'Refunded',
      }[s] ?? s.name;
}

class _BoardColumn extends StatelessWidget {
  final OrderStatus status;
  final String search;
  const _BoardColumn({required this.status, required this.search});

  @override
  Widget build(BuildContext context) {
    final service = OrderService.instance;
    return SizedBox(
      width: 340,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_title(status), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                _StatusDot(status: status),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: StreamBuilder<List<OrderModel>>(
                  stream: service.streamOrders(statuses: [status], query: search),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(child: Text('Error: ${snapshot.error}'));
                    }
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) {
                      return Center(child: Text('No ${_title(status)}'));
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _OrderCard(order: orders[i]),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _title(OrderStatus s) =>
      {
        OrderStatus.pending: 'Pending',
        OrderStatus.accepted: 'Accepted',
        OrderStatus.preparing: 'Preparing',
        OrderStatus.outForDelivery: 'Out for Delivery',
        OrderStatus.completed: 'Completed',
        OrderStatus.cancelled: 'Cancelled',
        OrderStatus.refunded: 'Refunded',
      }[s] ?? s.name;
}

class _SideColumn extends StatelessWidget {
  final OrderStatus status;
  final String search;
  const _SideColumn({required this.status, required this.search});

  @override
  Widget build(BuildContext context) {
    final service = OrderService.instance;
    return SizedBox(
      width: 280,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Text(_title(status), style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(width: 8), _StatusDot(status: status)]),
            const SizedBox(height: 8),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SizedBox(
                height: 250,
                child: StreamBuilder<List<OrderModel>>(
                  stream: service.streamOrders(statuses: [status], query: search),
                  builder: (context, snapshot) {
                    final orders = snapshot.data ?? [];
                    if (orders.isEmpty) return Center(child: Text('No ${_title(status)}'));
                    return ListView.separated(
                      padding: const EdgeInsets.all(8),
                      itemCount: orders.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, i) => _OrderCard(order: orders[i], compact: true),
                    );
                  },
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  String _title(OrderStatus s) =>
      {
        OrderStatus.cancelled: 'Cancelled',
        OrderStatus.refunded: 'Refunded',
      }[s] ?? s.name;
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final bool compact;
  const _OrderCard({required this.order, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _openDetails(context, order),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [Colors.white, Colors.white.withOpacity(.9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.06), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(width: 6, height: 28, decoration: BoxDecoration(color: Colors.deepOrangeAccent, borderRadius: BorderRadius.circular(6))),
              const SizedBox(width: 8),
              Expanded(child: Text('#${order.id}', style: const TextStyle(fontWeight: FontWeight.w800))),
              _PriorityChip(priority: order.priority),
              const SizedBox(width: 8),
              Text('₱${order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.person_outline, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Expanded(child: Text(order.customerName ?? order.customerEmail ?? order.userId, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(_fmt(order.createdAt), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              const SizedBox(width: 8),
              if (order.eta != null) ...[
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(_fmt(order.eta!), style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ]
            ]),
            const SizedBox(height: 10),
            Row(children: [
              // allow the status chip to flex/shrink on narrow widths
              Flexible(fit: FlexFit.loose, child: _statusChip(context, order.status)),
              const SizedBox(width: 8),
              // make the primary button flexible so it can shrink on narrow widths and avoid overflow
              Flexible(fit: FlexFit.loose, child: _PrimaryProgressButton(order: order)),
              const SizedBox(width: 8),
              _RowMenu(order: order),
            ])
          ],
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, OrderModel o) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => HeroMode(
        enabled: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (context, controller) => _OrderDetailsSheet(order: o, controller: controller),
        ),
      ),
    );
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

class _PrimaryProgressButton extends StatelessWidget {
  final OrderModel order;
  const _PrimaryProgressButton({required this.order});

  @override
  Widget build(BuildContext context) {
    final service = OrderService.instance;
    String? label;
    OrderStatus? next;

    switch (order.status) {
      case OrderStatus.pending:
        label = 'Accept';
        next = OrderStatus.accepted;
        break;
      case OrderStatus.accepted:
        label = 'Start preparing';
        next = OrderStatus.preparing;
        break;
      case OrderStatus.preparing:
        label = 'Out for delivery';
        next = OrderStatus.outForDelivery;
        break;
      case OrderStatus.outForDelivery:
        label = 'Complete';
        next = OrderStatus.completed;
        break;
      case OrderStatus.completed:
      case OrderStatus.cancelled:
      case OrderStatus.refunded:
        label = null;
        break;
    }

    if (label == null) return const SizedBox.shrink();

    return FilledButton.tonal(
      onPressed: () async {
        try {
          await service.updateStatus(order.id, next!);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order ${order.id} → ${next.name}')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
          }
        }
      },
      child: Text(label),
    );
  }
}

class _RowMenu extends StatelessWidget {
  final OrderModel order;
  const _RowMenu({required this.order});

  @override
  Widget build(BuildContext context) {
    final service = OrderService.instance;
    return PopupMenuButton<String>(
      onSelected: (value) async {
        try {
          switch (value) {
            case 'assign':
              final driverId = await _promptText(context, 'Assign driver ID');
              if (driverId != null && driverId.isNotEmpty) await service.assignDriver(order.id, driverId);
              break;
            case 'eta':
              await service.setEta(order.id, DateTime.now().add(const Duration(minutes: 45)));
              break;
            case 'paid':
              await service.markPaid(order.id);
              break;
            case 'priority':
              final p = await _promptPriority(context, order.priority);
              if (p != null) await service.setPriority(order.id, p);
              break;
            case 'note':
              final n = await _promptText(context, 'Add admin note', initial: order.notes);
              if (n != null) await service.addNote(order.id, n);
              break;
            case 'cancel':
              final c = await _confirm(context, 'Cancel this order?');
              if (c == true) await service.cancel(order.id, reason: 'Cancelled by admin');
              break;
            case 'refund':
              final r = await _confirm(context, 'Refund this order?');
              if (r == true) await service.refund(order.id, reason: 'Refunded by admin');
              break;
          }
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Updated')));
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
          }
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'assign', child: Text('Assign driver')),
        PopupMenuItem(value: 'eta', child: Text('Set ETA +45m')),
        PopupMenuItem(value: 'paid', child: Text('Mark Paid')),
        PopupMenuItem(value: 'priority', child: Text('Set Priority')),
        PopupMenuItem(value: 'note', child: Text('Add note')),
        PopupMenuDivider(),
        PopupMenuItem(value: 'cancel', child: Text('Cancel')),
        PopupMenuItem(value: 'refund', child: Text('Refund')),
      ],
      child: const Icon(Icons.more_horiz),
    );
  }

  Future<String?> _promptText(BuildContext context, String title, {String? initial}) async {
    final controller = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<int?> _promptPriority(BuildContext context, int current) async {
    int p = current;
    return showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Priority'),
        content: StatefulBuilder(
          builder: (context, setState) => Row(children: [
            ChoiceChip(label: const Text('Normal'), selected: p == 0, onSelected: (_) => setState(() => p = 0)),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('High'), selected: p == 1, onSelected: (_) => setState(() => p = 1)),
            const SizedBox(width: 8),
            ChoiceChip(label: const Text('Urgent'), selected: p == 2, onSelected: (_) => setState(() => p = 2)),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(p), child: const Text('Save')),
        ],
      ),
    );
  }

  Future<bool?> _confirm(BuildContext context, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('No')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Yes')),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  final OrderStatus status;
  const _StatusDot({required this.status});
  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      OrderStatus.pending => Colors.grey,
      OrderStatus.accepted => Colors.blue,
      OrderStatus.preparing => Colors.orange,
      OrderStatus.outForDelivery => Colors.indigo,
      OrderStatus.completed => Colors.green,
      OrderStatus.cancelled => Colors.red,
      OrderStatus.refunded => Colors.purple,
    };
    return Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _PriorityChip extends StatelessWidget {
  final int priority;
  const _PriorityChip({required this.priority});
  @override
  Widget build(BuildContext context) {
    final label = switch (priority) { 2 => 'Urgent', 1 => 'High', _ => 'Normal' };
    final color = switch (priority) { 2 => Colors.red, 1 => Colors.orange, _ => Colors.grey };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(.4))),
      child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class _OrderDetailsSheet extends StatefulWidget {
  final OrderModel order;
  final ScrollController controller;
  const _OrderDetailsSheet({required this.order, required this.controller});

  @override
  State<_OrderDetailsSheet> createState() => _OrderDetailsSheetState();
}

class _OrderDetailsSheetState extends State<_OrderDetailsSheet> {
  final _service = OrderService.instance;
  late OrderModel _order;
  final _noteController = TextEditingController();
  int _priority = 0;

  @override
  void initState() {
    super.initState();
    _order = widget.order;
    _priority = _order.priority;
    _noteController.text = _order.notes ?? '';
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: ListView(
        controller: widget.controller,
        children: [
          Row(children: [
            Text('Order #${_order.id}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            _statusChip(context, _order.status),
          ]),
          const SizedBox(height: 8),
          Text(_order.customerName ?? _order.customerEmail ?? _order.userId, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text('Created: ${_fmt(_order.createdAt)}', style: const TextStyle(color: Colors.grey)),
          if (_order.eta != null) Text('ETA: ${_fmt(_order.eta!)}', style: const TextStyle(color: Colors.grey)),
          const Divider(height: 24),
          const Text('Items', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          ..._order.items.map((i) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${i.name} x${i.quantity}'),
                trailing: Text('₱${(i.subtotal).toStringAsFixed(2)}'),
                subtitle: i.options != null && i.options!.isNotEmpty
                    ? Text(i.options!.entries.map((e) => '${e.key}: ${e.value}').join(', '))
                    : null,
              )),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('Total: ₱${_order.total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 24),
          // Priority selection: wrap chips on narrow widths and keep the save button below to avoid overflow
          const Text('Priority: '),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('Normal'), selected: _priority == 0, onSelected: (_) => setState(() => _priority = 0)),
              ChoiceChip(label: const Text('High'), selected: _priority == 1, onSelected: (_) => setState(() => _priority = 1)),
              ChoiceChip(label: const Text('Urgent'), selected: _priority == 2, onSelected: (_) => setState(() => _priority = 2)),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () async {
                await _service.setPriority(_order.id, _priority);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Admin note',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (context, constraints) {
            // switch to a stacked layout on narrow widths to avoid RenderFlex overflow
            if (constraints.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _service.addNote(_order.id, _noteController.text);
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.note_add_outlined),
                        label: const Text('Save note'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await _service.setEta(_order.id, DateTime.now().add(const Duration(minutes: 45)));
                          if (context.mounted) Navigator.pop(context);
                        },
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Set ETA +45m'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: () async {
                        await _service.updateStatus(_order.id, OrderStatus.completed);
                        if (context.mounted) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Complete'),
                    ),
                  ),
                ],
              );
            }

            return Row(children: [
              OutlinedButton.icon(
                onPressed: () async {
                  await _service.addNote(_order.id, _noteController.text);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Save note'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  await _service.setEta(_order.id, DateTime.now().add(const Duration(minutes: 45)));
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Set ETA +45m'),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: () async {
                  await _service.updateStatus(_order.id, OrderStatus.completed);
                  if (context.mounted) Navigator.pop(context);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Complete'),
              ),
            ]);
          })
        ],
      ),
    );
  }

  String _fmt(DateTime d) {
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
