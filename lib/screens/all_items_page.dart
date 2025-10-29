import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

import '../models/cart_model.dart';
import 'cart_page.dart';
import 'product_customization.dart';

class AllItemsPage extends StatefulWidget {
  final String title;
  final List<CartItem> items;
  // optional callback used when the page is embedded (e.g., inside a PageView)
  final VoidCallback? onBack;

  const AllItemsPage({super.key, required this.title, required this.items, this.onBack});

  @override
  State<AllItemsPage> createState() => _AllItemsPageState();
}

class _AllItemsPageState extends State<AllItemsPage> with SingleTickerProviderStateMixin {
  late final AnimationController _listController;
  final TextEditingController _search = TextEditingController();
  List<CartItem> _filtered = [];
  String _sort = 'Recommended';
  String _selectedCategory = 'All';
  final Map<String, int> _quantities = {};
  final CartModel _cart = CartModel.instance;

  @override
  void initState() {
    super.initState();
    _filtered = List.from(widget.items);
    // ensure category filter initialized
    _selectedCategory = 'All';
    for (var it in widget.items) {
      _quantities[it.id] = 1;
    }
    _listController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    // Give a tiny delay so the page transition feels natural, then play the stagger
    Future.delayed(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      _listController.forward();
    });
    // update when cart changes so badge updates
    _cart.addListener(_onCartChanged);
  }

  void _refreshFiltered() {
    final ql = _search.text.trim().toLowerCase();
    List<CartItem> base = widget.items.where((it) => _selectedCategory == 'All' || it.category.toLowerCase() == _selectedCategory.toLowerCase()).toList();
    if (ql.isNotEmpty) {
      base = base.where((it) => it.name.toLowerCase().contains(ql) || it.category.toLowerCase().contains(ql)).toList();
    }
    if (_sort == 'Price: Low') {
      base.sort((a, b) => a.price.compareTo(b.price));
    } else if (_sort == 'Price: High') {
      base.sort((a, b) => b.price.compareTo(a.price));
    } else {
      // keep original passed order
      base = widget.items.where((it) => base.map((b) => b.id).contains(it.id)).toList();
    }
    setState(() {
      _filtered = base;
    });
    _listController.forward(from: 0);
  }

  @override
  void didUpdateWidget(covariant AllItemsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // if parent passed different items (e.g., filtered by category), update our list
    if (oldWidget.items != widget.items) {
      setState(() {
        _filtered = List.from(widget.items);
      });
      // restart entrance animation
      if (mounted) _listController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _listController.dispose();
    _search.dispose();
    _cart.removeListener(_onCartChanged);
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  void _applySearch(String q) {
    _refreshFiltered();
  }

  void _applySort(String choice) {
    _sort = choice;
    _refreshFiltered();
  }

  void _addWithSnackbar(CartItem it, int count) {
    for (var i = 0; i < count; i++) {
      CartModel.instance.addItem(it);
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('${it.name} added • $count'),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          CartModel.instance.removeQuantity(it.id, count);
        },
      ),
      duration: const Duration(seconds: 3),
    ));
  }

  IconData _iconForCategory(String c) {
    switch (c.toLowerCase()) {
      case 'pizza':
        return Icons.local_pizza;
      case 'pasta':
        return Icons.ramen_dining;
      case 'drinks':
        return Icons.local_drink;
      case 'desserts':
        return Icons.icecream;
      default:
        return Icons.fastfood;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(140),
        child: AnimatedBuilder(
          animation: _listController,
          builder: (context, child) {
            final anim = Curves.easeOut.transform(_listController.value);
            final bg = Color.lerp(Theme.of(context).cardColor.withValues(alpha: 0.12), Theme.of(context).cardColor.withValues(alpha: 0.04), anim) ?? Theme.of(context).cardColor.withValues(alpha: 0.06);
            return ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8 * (0.6 + 0.4 * anim), sigmaY: 8 * (0.6 + 0.4 * anim)),
                child: Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 12, right: 12, bottom: 12),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    border: Border.all(color: Colors.white.withAlpha((0.08 * 255).round())),
                    boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.04 * 255).round()), blurRadius: 12 * anim, offset: Offset(0, 6 * anim))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Transform.scale(
                            scale: 0.96 + anim * 0.04,
                              child: Material(
                              color: Colors.transparent,
                              child: IconButton(
                                icon: const Icon(Icons.arrow_back_ios_new),
                                onPressed: () {
                                  // if embedded, call onBack instead of popping the route
                                  if (widget.onBack != null) {
                                    widget.onBack!();
                                  } else {
                                    Navigator.of(context).pop();
                                  }
                                },
                                tooltip: 'Back',
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(widget.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                                const SizedBox(height: 4),
                                Text('${_filtered.length} items', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                              ],
                            ),
                          ),
                          // sort + cart
                          PopupMenuButton<String>(
                            initialValue: _sort,
                            onSelected: _applySort,
                            itemBuilder: (ctx) => ['Recommended', 'Price: Low', 'Price: High'].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                            icon: const Icon(Icons.sort),
                          ),
                          const SizedBox(width: 6),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Material(
                                color: Colors.transparent,
                                child: IconButton(
                                  icon: const Icon(Icons.shopping_cart_outlined),
                                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartPage())),
                                ),
                              ),
                              if (_cart.totalCount > 0)
                                Positioned(
                                  right: 6,
                                  top: 6,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: Colors.deepOrange[700], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.0)),
                                    child: Text(_cart.totalCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 11)),
                                  ),
                                )
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      // search field inside header for tighter layout
                      SizedBox(
                        height: 40,
                        child: TextField(
                          controller: _search,
                          onChanged: _applySearch,
                          decoration: InputDecoration(
                            hintText: 'Search ${widget.title.toLowerCase()}',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _search.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _search.clear(); _applySearch(''); }) : null,
                            filled: true,
                            fillColor: Theme.of(context).canvasColor.withValues(alpha: 0.96),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        if (_filtered.isEmpty) {
          return Center(child: Text('No ${widget.title.toLowerCase()} found', style: Theme.of(context).textTheme.titleMedium));
        }

        // Narrow: single column list with staggered entrance
        if (constraints.maxWidth < 720) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _filtered.length,
            itemBuilder: (context, idx) {
              final it = _filtered[idx];
              final start = (idx * 0.06).clamp(0.0, 0.6);
              final end = (start + 0.5).clamp(0.0, 1.0);
              final anim = CurvedAnimation(parent: _listController, curve: Interval(start, end, curve: Curves.easeOutCubic));
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(anim),
                  child: _buildItemCard(it),
                ),
              );
            },
          );
        }

        // Wide: show category selector + responsive grid
        final availableCategories = <String>{'All'};
        for (final it in widget.items) {
          availableCategories.add(it.category);
        }

        final cats = availableCategories.toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.category),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      items: cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setState(() => _selectedCategory = v);
                        _refreshFiltered();
                      },
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  PopupMenuButton<String>(
                    initialValue: _sort,
                    onSelected: _applySort,
                    itemBuilder: (ctx) => ['Recommended', 'Price: Low', 'Price: High'].map((s) => PopupMenuItem(value: s, child: Text(s))).toList(),
                    icon: const Icon(Icons.sort),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: () {
                  // order categories with common ones first
                  final preferred = ['Pizza', 'Pasta', 'Drinks', 'Desserts'];
                  final available = <String>{};
                  for (final it in widget.items) available.add(it.category);
                  final ordered = <String>[];
                  for (final p in preferred) if (available.contains(p)) ordered.add(p);
                  for (final a in available) if (!ordered.contains(a)) ordered.add(a);

                  // build a list of section widgets
                  final sections = <Widget>[];
                  for (final cat in ordered) {
                    final itemsForCat = _filtered.where((it) => it.category == cat).toList();
                    if (itemsForCat.isEmpty) continue;

                    // section header
                    sections.add(Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                            child: Icon(_iconForCategory(cat), size: 18, color: Theme.of(context).colorScheme.primary),
                          ),
                          const SizedBox(width: 12),
                          Text(cat, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                          const SizedBox(width: 12),
                          Expanded(child: Divider(color: Colors.black12)),
                        ],
                      ),
                    ));

                    // grid of items for this category (non-scrolling so outer ListView scrolls)
                    sections.add(GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: max(1, constraints.maxWidth ~/ 360),
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 3.6,
                      ),
                      itemCount: itemsForCat.length,
                      itemBuilder: (context, idx2) {
                        final it = itemsForCat[idx2];
                        final globalIndex = _filtered.indexOf(it);
                        final start = (globalIndex * 0.04).clamp(0.0, 0.6);
                        final end = (start + 0.5).clamp(0.0, 1.0);
                        final anim = CurvedAnimation(parent: _listController, curve: Interval(start, end, curve: Curves.easeOutCubic));
                        return FadeTransition(
                          opacity: anim,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero).animate(anim),
                            child: _buildItemCard(it),
                          ),
                        );
                      },
                    ));

                    sections.add(const SizedBox(height: 16));
                  }
                  return sections;
                }(),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildItemCard(CartItem it) {
    return InkWell(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProductCustomization(item: it))),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.04 * 255).round()), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(height: 64, width: 64, decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(10)), child: Center(child: Text(it.emoji, style: const TextStyle(fontSize: 32)))),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text('₱${it.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.black54)),
                const SizedBox(height: 6),
                Row(children: [
                  IconButton(onPressed: () => setState(() => _quantities[it.id] = max(1, (_quantities[it.id] ?? 1) - 1)), icon: const Icon(Icons.remove_circle_outline)),
                  Text('${_quantities[it.id] ?? 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(onPressed: () => setState(() => _quantities[it.id] = min(99, (_quantities[it.id] ?? 1) + 1)), icon: const Icon(Icons.add_circle_outline)),
                ])
              ]),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                final q = _quantities[it.id] ?? 1;
                _addWithSnackbar(it, q);
              },
              onLongPress: () {
                _addWithSnackbar(it, 3);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.deepOrange[400], borderRadius: BorderRadius.circular(10)),
                child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
