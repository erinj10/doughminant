import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/cart_model.dart';

class MenuService {
  MenuService._();
  static final instance = MenuService._();

  CollectionReference<Map<String, dynamic>> get _col => FirebaseFirestore.instance.collection('menu_items').withConverter<Map<String, dynamic>>(
        fromFirestore: (snap, _) => snap.data() ?? <String, dynamic>{},
        toFirestore: (map, _) => map,
      );

  Stream<List<CartItem>> streamMenu() {
    return _col.snapshots().map((snap) {
      return snap.docs.map((d) {
        final data = d.data();
        return CartItem(
          id: d.id,
          name: (data['name'] ?? '') as String,
          emoji: (data['emoji'] ?? '') as String,
          price: (data['price'] is num) ? (data['price'] as num).toDouble() : double.tryParse('${data['price']}') ?? 0.0,
          category: (data['category'] ?? 'Pizza') as String,
        );
      }).toList();
    });
  }

  Future<void> addMenuItem(Map<String, dynamic> item) => _col.add(item).then((_) {});

  Future<void> updateMenuItem(String id, Map<String, dynamic> item) => _col.doc(id).set(item);

  Future<void> deleteMenuItem(String id) => _col.doc(id).delete();
}
