import 'package:cloud_firestore/cloud_firestore.dart';

enum OrderStatus {
  pending,
  accepted,
  preparing,
  outForDelivery,
  completed,
  cancelled,
  refunded,
}

enum PaymentStatus {
  unpaid,
  paid,
  refunded,
  failed,
}

class OrderItem {
  final String id;
  final String name;
  final int quantity;
  final double price;
  final Map<String, dynamic>? options;

  OrderItem({
    required this.id,
    required this.name,
    required this.quantity,
    required this.price,
    this.options,
  });

  double get subtotal => price * quantity;

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      id: map['id'] as String,
      name: map['name'] as String,
      quantity: (map['quantity'] as num).toInt(),
      price: (map['price'] as num).toDouble(),
      options: (map['options'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'quantity': quantity,
      'price': price,
      'options': options,
    };
  }
}

class DeliveryInfo {
  final String? addressLine;
  final String? contactName;
  final String? contactPhone;
  final GeoPoint? coordinates;

  const DeliveryInfo({this.addressLine, this.contactName, this.contactPhone, this.coordinates});

  factory DeliveryInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DeliveryInfo();
    return DeliveryInfo(
      addressLine: map['addressLine'] as String?,
      contactName: map['contactName'] as String?,
      contactPhone: map['contactPhone'] as String?,
      coordinates: map['coordinates'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() => {
        'addressLine': addressLine,
        'contactName': contactName,
        'contactPhone': contactPhone,
        'coordinates': coordinates,
      };
}

class OrderModel {
  final String id;
  final String userId;
  final String? customerName;
  final String? customerEmail;
  final List<OrderItem> items;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final double total;
  final int priority; // 0 normal, 1 high, 2 urgent
  final String? assignedDriverId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? eta;
  final String? notes;
  final DeliveryInfo deliveryInfo;

  OrderModel({
    required this.id,
    required this.userId,
    required this.items,
    required this.status,
    required this.paymentStatus,
    required this.total,
    required this.createdAt,
    this.updatedAt,
    this.eta,
    this.notes,
    this.assignedDriverId,
    this.priority = 0,
    this.customerName,
    this.customerEmail,
    this.deliveryInfo = const DeliveryInfo(),
  });

  OrderModel copyWith({
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    DateTime? eta,
    String? notes,
    String? assignedDriverId,
    int? priority,
  }) {
    return OrderModel(
      id: id,
      userId: userId,
      items: items,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      total: total,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      eta: eta ?? this.eta,
      notes: notes ?? this.notes,
      assignedDriverId: assignedDriverId ?? this.assignedDriverId,
      priority: priority ?? this.priority,
      customerName: customerName,
      customerEmail: customerEmail,
      deliveryInfo: deliveryInfo,
    );
  }

  factory OrderModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final items = ((data['items'] as List?) ?? [])
        .map((e) => OrderItem.fromMap(Map<String, dynamic>.from(e)))
        .toList();
    return OrderModel(
      id: doc.id,
      userId: data['userId'] as String,
      items: items,
      status: OrderStatus.values[(data['status'] ?? 0) as int],
      paymentStatus: PaymentStatus.values[(data['paymentStatus'] ?? 0) as int],
      total: (data['total'] as num).toDouble(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      eta: (data['eta'] as Timestamp?)?.toDate(),
      notes: data['notes'] as String?,
      assignedDriverId: data['assignedDriverId'] as String?,
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      customerName: data['customerName'] as String?,
      customerEmail: data['customerEmail'] as String?,
      deliveryInfo: DeliveryInfo.fromMap((data['deliveryInfo'] as Map?)?.cast<String, dynamic>()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'items': items.map((e) => e.toMap()).toList(),
      'status': status.index,
      'paymentStatus': paymentStatus.index,
      'total': total,
      'priority': priority,
      'assignedDriverId': assignedDriverId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'eta': eta != null ? Timestamp.fromDate(eta!) : null,
      'notes': notes,
      'customerName': customerName,
      'customerEmail': customerEmail,
      'deliveryInfo': deliveryInfo.toMap(),
    };
  }
}
