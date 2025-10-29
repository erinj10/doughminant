import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order.dart';
import 'notification_service.dart';

class OrderService {
  OrderService._();
  static final OrderService instance = OrderService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders => _db.collection('orders');

  // Stream all orders with optional filters
  Stream<List<OrderModel>> streamOrders({
    List<OrderStatus>? statuses,
    String? query,
    int? limit,
  }) {
    Query<Map<String, dynamic>> q = _orders.orderBy('createdAt', descending: true);

    if (statuses != null && statuses.isNotEmpty) {
      final indexes = statuses.map((e) => e.index).toList();
      q = q.where('status', whereIn: indexes.length > 10 ? indexes.sublist(0, 10) : indexes);
    }

    if (limit != null) {
      q = q.limit(limit);
    }

    return q.snapshots().map((snap) {
      var list = snap.docs.map((d) => OrderModel.fromDoc(d)).toList();
      if (query != null && query.trim().isNotEmpty) {
        final ql = query.toLowerCase();
        list = list.where((o) {
          final id = o.id.toLowerCase();
          final name = (o.customerName ?? '').toLowerCase();
          final email = (o.customerEmail ?? '').toLowerCase();
          return id.contains(ql) || name.contains(ql) || email.contains(ql);
        }).toList();
      }
      return list;
    });
  }

  Stream<List<OrderModel>> streamUserOrders(String userId) {
    return _orders
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => OrderModel.fromDoc(d)).toList());
  }

  Future<void> createOrder(OrderModel order) async {
    await _orders.add(order.toMap());
  }

  Future<void> updateStatus(String orderId, OrderStatus status) async {
    final docRef = _orders.doc(orderId);
    final snap = await docRef.get();
    final data = snap.data();
    final userId = data?['userId'] as String?;

    await docRef.update({
      'status': status.index,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // create notification for user
    try {
      if (userId != null) {
        final title = 'Order ${orderId} updated';
        final body = 'Your order is now ${status.name}';
        await NotificationService.instance.create(userId: userId, title: title, body: body, orderId: orderId);
      }
    } catch (_) {}
  }

  Future<void> setEta(String orderId, DateTime eta) async {
    await _orders.doc(orderId).update({
      'eta': Timestamp.fromDate(eta),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> assignDriver(String orderId, String driverId) async {
    await _orders.doc(orderId).update({
      'assignedDriverId': driverId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setPriority(String orderId, int priority) async {
    await _orders.doc(orderId).update({
      'priority': priority,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addNote(String orderId, String note) async {
    await _orders.doc(orderId).update({
      'notes': note,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> cancel(String orderId, {String? reason}) async {
    await _orders.doc(orderId).update({
      'status': OrderStatus.cancelled.index,
      'notes': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markPaid(String orderId) async {
    await _orders.doc(orderId).update({
      'paymentStatus': PaymentStatus.paid.index,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> refund(String orderId, {String? reason}) async {
    await _orders.doc(orderId).update({
      'status': OrderStatus.refunded.index,
      'paymentStatus': PaymentStatus.refunded.index,
      'notes': reason,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Helper to place an order from cart-like structure
  Future<String> placeOrder({
    required String userId,
    required List<OrderItem> items,
    required double total,
    String? customerName,
    String? customerEmail,
    DeliveryInfo deliveryInfo = const DeliveryInfo(),
    String? notes,
  }) async {
    final doc = await _orders.add({
      'userId': userId,
      'items': items.map((e) => e.toMap()).toList(),
      'status': OrderStatus.pending.index,
      'paymentStatus': PaymentStatus.unpaid.index,
      'total': total,
      'priority': 0,
      'assignedDriverId': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'eta': null,
      'notes': notes,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'deliveryInfo': deliveryInfo.toMap(),
    });
    // notify admins about new order
    try {
      await NotificationService.instance.create(userId: null, title: 'New order', body: 'Order ${doc.id} placed', orderId: doc.id, forAdmin: true);
    } catch (_) {}
    return doc.id;
  }
}
