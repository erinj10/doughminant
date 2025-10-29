import 'package:flutter/foundation.dart';

class CartItem {
  final String id;
  final String name;
  final String emoji;
  final double price;
  final String category;
  /// Optional customization schema describing per-product customization fields.
  /// Example:
  /// {
  ///   'fields': [
  ///     {'type':'choice','key':'size','label':'Size','options':['Small','Medium','Large'],'default':'Medium'},
  ///     {'type':'multiselect','key':'toppings','label':'Toppings','options':['Cheese','Bacon'],'price':5.0}
  ///   ]
  /// }
  final Map<String, dynamic>? customizationSchema;

  CartItem({required this.id, required this.name, required this.emoji, required this.price, this.category = 'Pizza', this.customizationSchema});
}

class CartModel extends ChangeNotifier {
  CartModel._internal();
  static final CartModel instance = CartModel._internal();

  final List<CartItem> _items = [];

  List<CartItem> get items => List.unmodifiable(_items);

  int get totalCount => _items.length;

  double get totalPrice => _items.fold(0.0, (v, e) => v + e.price);

  void addItem(CartItem item) {
    _items.add(item);
    notifyListeners();
  }

  void removeAt(int index) {
    if (index >= 0 && index < _items.length) {
      _items.removeAt(index);
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }

  // ----- Convenience helpers for quantities & grouped UI -----
  /// Return a map of itemId -> (representative item, count)
  Map<String, Map<String, dynamic>> grouped() {
    final Map<String, Map<String, dynamic>> m = {};
    for (final it in _items) {
      if (!m.containsKey(it.id)) {
        m[it.id] = {'item': it, 'count': 1};
      } else {
        m[it.id]!['count'] = (m[it.id]!['count'] as int) + 1;
      }
    }
    return m;
  }

  /// Number of instances for given item id
  int countById(String id) => _items.where((e) => e.id == id).length;

  /// Remove one instance of the given item id (last occurrence)
  void removeOneById(String id) {
    for (var i = _items.length - 1; i >= 0; i--) {
      if (_items[i].id == id) {
        _items.removeAt(i);
        notifyListeners();
        return;
      }
    }
  }

  /// Remove up to [count] instances of given item id
  void removeQuantity(String id, int count) {
    var remaining = count;
    for (var i = _items.length - 1; i >= 0 && remaining > 0; i--) {
      if (_items[i].id == id) {
        _items.removeAt(i);
        remaining--;
      }
    }
    if (count > 0) notifyListeners();
  }
}
