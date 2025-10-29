import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationModel {
  final String id;
  final String? userId; // recipient; null means broadcast/admin
  final String title;
  final String body;
  final String? orderId;
  final bool read;
  final DateTime createdAt;

  NotificationModel({required this.id, this.userId, required this.title, required this.body, this.orderId, required this.read, required this.createdAt});

  factory NotificationModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data() ?? {};
    return NotificationModel(
      id: d.id,
      userId: data['userId'] as String?,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      orderId: data['orderId'] as String?,
      read: data['read'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _notes => _db.collection('notifications');

  Future<void> create({String? userId, required String title, required String body, String? orderId, bool forAdmin = false}) async {
    await _notes.add({
      'userId': userId,
      'title': title,
      'body': body,
      'orderId': orderId,
      'forAdmin': forAdmin,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<NotificationModel>> streamForUser(String userId) {
    return _notes.where('userId', isEqualTo: userId).orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((d) => NotificationModel.fromDoc(d)).toList());
  }

  Stream<List<NotificationModel>> streamAdmin() {
    return _notes.where('forAdmin', isEqualTo: true).orderBy('createdAt', descending: true).snapshots().map((snap) => snap.docs.map((d) => NotificationModel.fromDoc(d)).toList());
  }

  Stream<int> unreadCountForUser(String userId) {
    return _notes.where('userId', isEqualTo: userId).where('read', isEqualTo: false).snapshots().map((s) => s.docs.length);
  }

  Stream<int> unreadCountAdmin() {
    return _notes.where('forAdmin', isEqualTo: true).where('read', isEqualTo: false).snapshots().map((s) => s.docs.length);
  }

  Future<void> markRead(String id) async {
    await _notes.doc(id).update({'read': true});
  }

  Future<void> delete(String id) async {
    await _notes.doc(id).delete();
  }
}
