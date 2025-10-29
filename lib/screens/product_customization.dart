import 'package:flutter/material.dart';

import '../models/cart_model.dart';

class ProductCustomization extends StatefulWidget {
  final CartItem item;

  const ProductCustomization({Key? key, required this.item}) : super(key: key);

  @override
  State<ProductCustomization> createState() => _ProductCustomizationState();
}

class _ProductCustomizationState extends State<ProductCustomization> with SingleTickerProviderStateMixin {
  String _crust = 'Original';
  String _size = 'Medium';
  // toppings/add-ons are category-specific; default map is populated in initState
  final Map<String, bool> _toppings = {};
  // per-option prices for the fallback toppings/add-ons (populated in initState)
  final Map<String, double> _toppingPrices = {};
  // Schema-driven state (per-product customization)
  final Map<String, String> _singleChoices = {};
  final Map<String, Set<String>> _multiChoices = {};
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, double> _fieldPrices = {};
  int _qty = 1;
  final TextEditingController _notes = TextEditingController();
  late final AnimationController _pulse;

  double get base => widget.item.price;

  double get sizeMultiplier {
    final sizeValue = (widget.item.customizationSchema != null && _singleChoices.containsKey('size')) ? _singleChoices['size']! : _size;
    switch (sizeValue) {
      case 'Small':
        return 0.9;
      case 'Large':
        return 1.25;
      default:
        return 1.0;
    }
  }

  // dynamic toppings/extra calculation: if schema provides multiselect fields, use them
  double get toppingsExtra {
    if (widget.item.customizationSchema != null && _multiChoices.isNotEmpty) {
      double total = 0.0;
      _multiChoices.forEach((key, set) {
        final price = _fieldPrices[key] ?? 5.0;
        total += set.length * price;
      });
      return total;
    }
    // fallback to legacy toppings/add-ons map — sum per-option prices when selected
    double total = 0.0;
    _toppings.forEach((k, v) {
      if (v) {
        total += _toppingPrices[k] ?? 5.0;
      }
    });
    return total;
  }

  double get totalPriceSingle => (base * sizeMultiplier) + toppingsExtra;

  double get totalPrice => totalPriceSingle * _qty;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    // initialize schema-driven defaults if present
    final schema = widget.item.customizationSchema;
    if (schema != null && schema['fields'] is List) {
      for (final f in schema['fields']) {
        try {
          final Map<String, dynamic> field = Map<String, dynamic>.from(f as Map);
          final type = field['type'] as String? ?? 'choice';
          final key = field['key'] as String? ?? field['label']?.toString() ?? 'opt';
          if (type == 'choice') {
            final List options = (field['options'] is List) ? field['options'] as List : [];
            final def = field['default'] ?? (options.isNotEmpty ? options.first : null);
            if (def != null) _singleChoices[key] = def.toString();
          } else if (type == 'multiselect') {
            _multiChoices[key] = <String>{};
            _fieldPrices[key] = (field['price'] is num) ? (field['price'] as num).toDouble() : 5.0;
          } else if (type == 'text') {
            _textControllers[key] = TextEditingController();
          }
        } catch (_) {
          // ignore malformed field
        }
      }
    }
    // If no schema provided, initialize a category-specific toppings/add-ons map
    if (schema == null) {
  final cat = widget.item.category.toLowerCase();
      if (cat == 'pasta') {
        _toppings.addAll({
          'Parmesan': false,
          'Meatballs': false,
          'Extra Sauce': false,
          'Basil': false,
          'Mushrooms': false,
        });
        // sensible per-option prices (₱)
        _toppingPrices.addAll({
          'Parmesan': 8.0,
          'Meatballs': 20.0,
          'Extra Sauce': 5.0,
          'Basil': 0.0,
          'Mushrooms': 5.0,
        });
      } else if (cat == 'drinks') {
        // Drinks use add-ons instead of "toppings"
        _toppings.addAll({
          'Lemon': false,
          'Mint': false,
          'Boba': false,
          'Extra Ice': false,
          'Sugar Boost': false,
        });
        _toppingPrices.addAll({
          'Lemon': 2.0,
          'Mint': 3.0,
          'Boba': 15.0,
          'Extra Ice': 0.0,
          'Sugar Boost': 2.0,
        });
        // example default: extra ice true for drinks
        _toppings['Extra Ice'] = true;
      } else if (cat == 'desserts') {
        // Desserts also use add-ons
        _toppings.addAll({
          'Chocolate Syrup': false,
          'Whipped Cream': false,
          'Nuts': false,
          'Caramel Drizzle': false,
          'Sprinkles': false,
        });
        _toppingPrices.addAll({
          'Chocolate Syrup': 8.0,
          'Whipped Cream': 8.0,
          'Nuts': 6.0,
          'Caramel Drizzle': 7.0,
          'Sprinkles': 2.0,
        });
      } else {
        // fallback (pizza / general)
        _toppings.addAll({
          'Extra Cheese': false,
          'Mushrooms': false,
          'Onions': false,
          'Bacon': false,
          'Olives': false,
        });
      }
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _addToCart() {
    // create a customized id so instances are grouped separately
    final List<String> opts = [];
    if (widget.item.customizationSchema != null) {
      // collect single choices
      _singleChoices.forEach((k, v) {
        opts.add('$k:$v');
      });
      // collect multis
      _multiChoices.forEach((k, set) {
        for (final s in set) opts.add('$k:$s');
      });
      // collect text fields
      _textControllers.forEach((k, ctrl) {
        if (ctrl.text.trim().isNotEmpty) opts.add('$k:${ctrl.text.trim()}');
      });
    } else {
      opts.addAll([_crust, _size]);
      opts.addAll(_toppings.entries.where((e) => e.value).map((e) => e.key));
    }

    final id = '${widget.item.id}|' + opts.join(',');
    final name = opts.isNotEmpty ? '${widget.item.name} (${opts.join(', ')})' : widget.item.name;
    final price = double.parse(totalPriceSingle.toStringAsFixed(2));
    final ci = CartItem(id: id, name: name, emoji: widget.item.emoji, price: price, category: widget.item.category);
    for (var i = 0; i < _qty; i++) {
      CartModel.instance.addItem(ci);
    }
    // provide feedback and pop
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Added ${widget.item.name} x$_qty')));
    Navigator.of(context).pop();
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.deepOrange[50] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? Colors.deepOrange : Colors.grey.withAlpha(60)),
        boxShadow: selected ? [BoxShadow(color: Colors.deepOrange.withAlpha(30), blurRadius: 10, offset: const Offset(0, 6))] : null,
      ),
      child: InkWell(onTap: onTap, child: Text(label, style: TextStyle(color: selected ? Colors.deepOrange[800] : Colors.black87, fontWeight: FontWeight.w700))),
    );
  }

  @override
  Widget build(BuildContext context) {
    // layered background with adaptive gradient + subtle radial highlights
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgGradient = isDark
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF334155)],
          )
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5), Color(0xFFFFE4C7)],
          );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // base gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(gradient: bgGradient),
            ),
          ),

          // soft radial highlights to add depth
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.8, -0.9),
                    radius: 1.2,
                    colors: [
                      (isDark ? Colors.deepPurple : Colors.pink).withOpacity(0.08),
                      Colors.transparent
                    ],
                    stops: const [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // subtle vignette for focus
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [Colors.black.withOpacity(isDark ? 0.35 : 0.06), Colors.transparent],
                    stops: const [0.9, 1.0],
                  ),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.of(context).pop()),
                          Text('Menu & Customization', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(width: 48),
                        ]),
                        const SizedBox(height: 18),
                        Center(
                          child: ScaleTransition(
                            scale: Tween(begin: 0.98, end: 1.02).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Colors.orange[100]!, Colors.orange[50]!]),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withAlpha(16), blurRadius: 20, offset: const Offset(0, 10))],
                                border: Border.all(color: Colors.orange.withAlpha(60)),
                              ),
                              child: Column(children: [
                                Container(height: 130, width: 130, decoration: BoxDecoration(color: Colors.orange[200], shape: BoxShape.circle), child: Center(child: Text(widget.item.emoji, style: const TextStyle(fontSize: 56)))),
                                const SizedBox(height: 12),
                                Text(widget.item.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                Text('₱${widget.item.price.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.brown[700], fontWeight: FontWeight.w800)),
                              ]),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        // Schema-driven customization: if product provides a schema, render fields dynamically
                        Builder(builder: (ctx) {
                          final schema = widget.item.customizationSchema;
                          if (schema != null && schema['fields'] is List) {
                            final List fields = schema['fields'] as List;
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: fields.map<Widget>((raw) {
                                final Map<String, dynamic> field = Map<String, dynamic>.from(raw as Map);
                                final type = field['type'] as String? ?? 'choice';
                                final label = field['label'] as String? ?? field['key'] as String? ?? 'Option';
                                final key = field['key'] as String? ?? label;
                                if (type == 'choice') {
                                  final List options = (field['options'] is List) ? field['options'] as List : [];
                                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 8),
                                    Wrap(spacing: 8, children: options.map((opt) {
                                      final s = opt.toString();
                                      final selected = (_singleChoices[key] ?? '') == s;
                                      return _chip(s, selected, () => setState(() => _singleChoices[key] = s));
                                    }).toList()),
                                    const SizedBox(height: 14),
                                  ]);
                                } else if (type == 'multiselect') {
                                  final List options = (field['options'] is List) ? field['options'] as List : [];
                                  final price = (field['price'] is num) ? (field['price'] as num).toDouble() : 5.0;
                                  _fieldPrices[key] = price;
                                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), Text('+₱${price.toStringAsFixed(0)} each', style: Theme.of(context).textTheme.bodySmall)]),
                                    const SizedBox(height: 8),
                                    Column(children: options.map((opt) {
                                      final s = opt.toString();
                                      final set = _multiChoices.putIfAbsent(key, () => <String>{});
                                      return Card(
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        child: SwitchListTile(
                                          dense: true,
                                          value: set.contains(s),
                                          onChanged: (v) => setState(() => v ? set.add(s) : set.remove(s)),
                                          title: Text(s, style: const TextStyle(fontWeight: FontWeight.w700)),
                                        ),
                                      );
                                    }).toList()),
                                    const SizedBox(height: 12),
                                  ]);
                                } else if (type == 'text') {
                                  final ctl = _textControllers.putIfAbsent(key, () => TextEditingController());
                                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 6),
                                    TextField(controller: ctl, minLines: 2, maxLines: 4, decoration: InputDecoration(hintText: field['hint'] ?? 'Enter', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                                    const SizedBox(height: 12),
                                  ]);
                                }
                                return const SizedBox.shrink();
                              }).toList(),
                            );
                          }
                          // fallback to legacy UI
                          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Crust Type', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: ['Thin', 'Original', 'Stuffed'].map((c) => _chip(c, _crust == c, () => setState(() => _crust = c))).toList()),
                            const SizedBox(height: 14),
                            Text('Crust Size', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: ['Small', 'Medium', 'Large'].map((s) => _chip(s, _size == s, () => setState(() => _size = s))).toList()),
                            const SizedBox(height: 14),
                            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text((['drinks', 'desserts'].contains(widget.item.category.toLowerCase()) ? 'Add-ons' : 'Toppings'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)), Text('+₱5 each', style: Theme.of(context).textTheme.bodySmall)]),
                            const SizedBox(height: 8),
                            Column(children: _toppings.keys.map((k) {
                              return Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                child: SwitchListTile(
                                  dense: true,
                                  value: _toppings[k]!,
                                  onChanged: (v) => setState(() => _toppings[k] = v),
                                  title: Text(k, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              );
                            }).toList()),
                            const SizedBox(height: 12),
                            Text('Special Instructions', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 6),
                            TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: InputDecoration(hintText: 'Any notes for the kitchen...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                            const SizedBox(height: 12),
                          ]);
                        }),
                        Row(children: [
                          Text('Quantity', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                          const Spacer(),
                          Row(children: [
                            IconButton(onPressed: () => setState(() => _qty = (_qty - 1).clamp(1, 99)), icon: const Icon(Icons.remove_circle_outline)),
                            Text('$_qty', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            IconButton(onPressed: () => setState(() => _qty = (_qty + 1).clamp(1, 99)), icon: const Icon(Icons.add_circle_outline)),
                          ])
                        ]),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),
                ),

                // Pinned action with glassy background
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor.withOpacity(isDark ? 0.12 : 0.85),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha(isDark ? 14 : 6), blurRadius: 18, offset: const Offset(0, -6))],
                    border: Border.all(color: Colors.white.withOpacity(isDark ? 0.03 : 0.06)),
                  ),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Total', style: Theme.of(context).textTheme.bodySmall), Text('₱${totalPrice.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900))]),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _addToCart,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14), backgroundColor: Colors.deepOrange[600], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Row(children: [const Icon(Icons.add_shopping_cart), const SizedBox(width: 8), Text('Add to Cart - ₱${totalPrice.toStringAsFixed(2)}')]),
                    )
                  ]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
