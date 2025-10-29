import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../models/cart_model.dart';
import 'package:doughminant/services/menu_service.dart';
import 'cart_page.dart';
import 'all_items_page.dart';
import 'profile_page.dart';
import '../widgets/side_menu.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  late final AnimationController _bgController;
  late final AnimationController _waveController;
  late final AnimationController _orderCardController;
  late final AnimationController _orderPulseController;
  late final AnimationController _offersController;
  final PageController _pageController = PageController(viewportFraction: 0.78);
  late final PageController _mainPageController;
  final CartModel cart = CartModel.instance;

  final List<CartItem> demoItems = [
    // Pizzas
    CartItem(id: 'm1', name: 'Margherita', emoji: '🍕', price: 250.0, category: 'Pizza'),
    CartItem(id: 'p1', name: 'Pepperoni Classic', emoji: '🍕', price: 270.0, category: 'Pizza'),
    CartItem(id: 'v1', name: 'Veggie Deluxe', emoji: '🥦', price: 220.0, category: 'Pizza'),
    // Pastas
    CartItem(id: 'ps1', name: 'Spaghetti Bolognese', emoji: '🍝', price: 110.0, category: 'Pasta'),
    CartItem(id: 'ps2', name: 'Penne Arrabbiata', emoji: '🍝', price:129.5, category: 'Pasta'),
    CartItem(id: 'ps3', name: 'Fettuccine Alfredo', emoji: '🍝', price: 1500.5, category: 'Pasta'),
    // Drinks
    CartItem(id: 'd1', name: 'Coke', emoji: '🥤', price: 50.0, category: 'Drinks'),
    CartItem(id: 'd2', name: 'Iced Tea', emoji: '🧊', price: 25.0, category: 'Drinks'),
    CartItem(id: 'd3', name: 'Lemonade', emoji: '🍋', price: 25.0, category: 'Drinks'),
    // Desserts
    CartItem(id: 'ds1', name: 'Chocolate Lava Cake', emoji: '🍫', price: 35.5, category: 'Desserts'),
    CartItem(id: 'ds2', name: 'Vanilla Cheesecake', emoji: '🍰', price: 39.0, category: 'Desserts'),
    CartItem(id: 'ds3', name: 'Strawberry Gelato', emoji: '🍨', price: 48.5, category: 'Desserts'),
  ];

  // categories used by the category chips and carousel filtering
  final List<String> _categories = ['Pizza', 'Pasta', 'Drinks', 'Desserts'];
  int _selectedCategory = 0;
  final Map<String, String> _categoryEmoji = {
    'Pizza': '🍕',
    'Pasta': '🍝',
    'Drinks': '🥤',
    'Desserts': '🍰',
  };

  int _orderAgainQty = 1;
  int _pressedPopularIndex = -1;
  // bottom nav selection
  int _selectedNav = 0;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat();
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _orderCardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _orderCardController.forward();
    _orderPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  _offersController = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat(reverse: true);
  _mainPageController = PageController(initialPage: 0);
    // Keep pageController updates in sync so we can animate centered card scale
    _pageController.addListener(() {
      setState(() {});
    });
    cart.addListener(_onCartChanged);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _waveController.dispose();
    _orderCardController.dispose();
    _orderPulseController.dispose();
    _pageController.dispose();
    _mainPageController.dispose();
    cart.removeListener(_onCartChanged);
    _offersController.dispose();
    super.dispose();
  }

  void _onCartChanged() => setState(() {});

  void _addToCart(CartItem it) {
    cart.addItem(it);
    _showAddedPopup(it, 1);
  }

  void _openCart() {
    // if we have a main page controller, switch to the cart page (index 2), otherwise fallback to push
    if (_mainPageController.hasClients) {
      _mainPageController.animateToPage(2, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
      setState(() => _selectedNav = 2);
    } else {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartPage()));
    }
  }

  Future<void> _orderAgainAdd() async {
    // Try to fetch a recent menu snapshot and pick a representative item (fallback to demoItems)
    final items = await MenuService.instance.streamMenu().first.timeout(const Duration(seconds: 2), onTimeout: () => demoItems);
    final item = (items.length > 1) ? items[1] : demoItems[1];
    final int count = _orderAgainQty;
    // small pulse animation on the pizza icon so user sees feedback
    _orderPulseController.forward(from: 0).then((_) => _orderPulseController.reverse());
    for (var i = 0; i < count; i++) {
      cart.addItem(item);
    }
    // show pop-up with undo
    _showAddedPopup(item, count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      drawer: SideMenu(onSelectPage: (page) {
        // Close drawer already handled by SideMenu; here we animate the main PageView
        if (_mainPageController.hasClients) {
          _mainPageController.animateToPage(page, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
          setState(() => _selectedNav = page);
        } else {
          setState(() => _selectedNav = page);
        }
      }),
      extendBody: true, // allow body to paint behind bottomNavigationBar so blur shows the underlying gradient
      backgroundColor: Colors.transparent,
      body: PageView(
          controller: _mainPageController,
          // allow user to swipe between main pages
          physics: const BouncingScrollPhysics(),
          onPageChanged: (i) => setState(() => _selectedNav = i),
          children: [
            // HOME (existing body)
            AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) {
          final t = _bgController.value;
          final hue = (20 + t * 20) % 360;
          final c1 = HSLColor.fromAHSL(1, hue, 0.9, 0.6).toColor();
          final c2 = HSLColor.fromAHSL(1, (hue + 18) % 360, 0.95, 0.52).toColor();

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.8 + sin(t * pi * 2) * 0.08, -1),
                end: Alignment(1, 1),
                colors: [c1, c2],
              ),
            ),
            child: StreamBuilder<List<CartItem>>(
              stream: MenuService.instance.streamMenu(),
              builder: (ctxMenu, snap) {
                final menuItems = snap.data ?? demoItems;
                return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top header
                    Row(
                      children: [
                        // profile (tap to open side menu)
                        GestureDetector(
                          onTap: () {
                            Scaffold.of(context).openDrawer();
                          },
                          child: Container(
                            height: 44,
                            width: 44,
                            decoration: BoxDecoration(color: Colors.white.withAlpha((0.25 * 255).round()), borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.person_outline, color: Colors.white),
                          ),
                        ),
                        const Spacer(),
                        // Title center
                        Expanded(
                          flex: 4,
                          child: Center(child: Text('DOUGHMINANT', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900))),
                        ),
                        const Spacer(),
                        // Cart
                        GestureDetector(
                          onTap: _openCart,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(color: Colors.white.withAlpha((0.25 * 255).round()), borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                              ),
                              if (cart.totalCount > 0)
                                Positioned(
                                  right: -6,
                                  top: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(color: Colors.deepOrange[700], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                                    child: Text(cart.totalCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Glassmorphic "Order Again" card with more functionality
                    // Entrance animation (slide + fade) + subtle wave scale
                    AnimatedBuilder(
                      animation: _orderCardController,
                      builder: (context, child) {
                        final double anim = Curves.easeOut.transform(_orderCardController.value);
                        return Opacity(
                          opacity: anim,
                          child: Transform.translate(
                            offset: Offset(0, 18 * (1 - anim)),
                            child: Transform.scale(
                              scale: 0.995 + (_waveController.value * 0.01),
                              child: child,
                            ),
                          ),
                        );
                      },
                      child: GestureDetector(
                        onLongPress: () {
                          // show last-order details and reorder option
                          showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha((0.96 * 255).round()),
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                              ),
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(height: 64, width: 64, decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle), child: const Center(child: Text('🍕', style: TextStyle(fontSize: 30)))),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(menuItems.length > 1 ? menuItems[1].name : demoItems[1].name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                                      Text('₱${(menuItems.length > 1 ? menuItems[1].price : demoItems[1].price).toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text('Placed: 2 days ago • 1 item', style: theme.textTheme.bodySmall),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            _orderAgainQty = 1;
                                            _orderAgainAdd();
                                          },
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[400], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                          child: const Text('Reorder'),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [Colors.white.withAlpha((0.10 * 255).round()), Colors.white.withAlpha((0.06 * 255).round())], begin: Alignment.topLeft, end: Alignment.bottomRight),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withAlpha((0.14 * 255).round()), width: 1.0),
                                boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.08 * 255).round()), blurRadius: 18, offset: const Offset(0, 8))],
                              ),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    onTap: () {
                                      // quick detail peek
                                      showDialog(
                                        context: context,
                                          builder: (ctx) => AlertDialog(
                                          title: const Text('Last Order'),
                                          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(menuItems.length > 1 ? menuItems[1].name : demoItems[1].name), const SizedBox(height: 8), Text('Price: ₱${(menuItems.length > 1 ? menuItems[1].price : demoItems[1].price).toStringAsFixed(2)}')]),
                                          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
                                        ),
                                      );
                                    },
                                    child: ScaleTransition(
                                      scale: Tween(begin: 1.0, end: 1.12).animate(CurvedAnimation(parent: _orderPulseController, curve: Curves.easeOut)),
                                      child: Container(
                                        height: 78,
                                        width: 78,
                                        decoration: BoxDecoration(color: Colors.orange[100], shape: BoxShape.circle),
                                        child: const Center(child: Text('🍕', style: TextStyle(fontSize: 34))),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Order Again', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white)),
                                        const SizedBox(height: 6),
                                        Text('Last order: Pepperoni Classic', style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70)),
                                      ],
                                    ),
                                  ),
                                  // quantity selector
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(color: Colors.white.withAlpha((0.04 * 255).round()), borderRadius: BorderRadius.circular(12)),
                                    child: Row(
                                      children: [
                                        InkWell(
                                          onTap: () => setState(() => _orderAgainQty = max(1, _orderAgainQty - 1)),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, color: Colors.white, size: 18)),
                                        ),
                                        Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('$_orderAgainQty', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                                        InkWell(
                                          onTap: () => setState(() => _orderAgainQty = min(9, _orderAgainQty + 1)),
                                          borderRadius: BorderRadius.circular(8),
                                          child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, color: Colors.white, size: 18)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // animated order button
                                  ElevatedButton(
                                    onPressed: _orderAgainAdd,
                                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), backgroundColor: Colors.deepOrange[400]),
                                    child: Text('Order ($_orderAgainQty)'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // Category capsule / chips (interactive + animated)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      // make capsule transparent per request
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: List.generate(_categories.length, (index) {
                              final label = _categories[index];
                              final selected = _selectedCategory == index;
                              return Expanded(
                                child: GestureDetector(
                                    onTap: () {
                                      // Just change the selected category and reset the carousel.
                                      // We intentionally do NOT navigate to the Menu page here so
                                      // taps on the category chips or the carousel won't redirect.
                                      setState(() {
                                        _selectedCategory = index;
                                        _pressedPopularIndex = -1;
                                      });
                                      // reset carousel to first item for the newly selected category
                                      if (_pageController.hasClients) {
                                        _pageController.animateToPage(0, duration: const Duration(milliseconds: 320), curve: Curves.easeOut);
                                      }
                                    },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected ? Colors.deepOrange[50] : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? Colors.deepOrange.shade200 : Colors.white.withAlpha((0.6 * 255).round()), width: selected ? 2 : 1),
                    boxShadow: selected
                      ? [BoxShadow(color: Colors.deepOrange.withAlpha((0.12 * 255).round()), blurRadius: 10, offset: const Offset(0, 6))]
                      : [BoxShadow(color: Colors.black.withAlpha((0.0 * 255).round()))],
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        AnimatedContainer(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeOut,
                                          height: selected ? 56 : 48,
                                          width: selected ? 56 : 48,
                                          decoration: BoxDecoration(
                                            color: selected ? Colors.deepOrange[100] : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: selected ? Colors.deepOrange : Colors.white.withAlpha((0.6 * 255).round())),
                                          ),
                                          child: Center(child: Text(_categoryEmoji[label] ?? label[0], style: TextStyle(fontSize: selected ? 22 : 20, color: selected ? Colors.brown[900] : Colors.white))),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(label, style: TextStyle(color: selected ? Colors.brown[900] : Colors.white70, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                          const SizedBox(height: 10),
                          // Animated indicator under the selected category
                          SizedBox(
                            height: 8,
                            child: LayoutBuilder(builder: (context, constraints) {
                              final alignX = -1 + (_selectedCategory * (2 / (_categories.length - 1)));
                              return Stack(
                                children: [
                                  Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(width: constraints.maxWidth, height: 6, decoration: BoxDecoration(color: Colors.white.withAlpha((0.06 * 255).round()), borderRadius: BorderRadius.circular(6))),
                                  ),
                                  AnimatedAlign(
                                    alignment: Alignment(alignX, 0),
                                    duration: const Duration(milliseconds: 350),
                                    curve: Curves.easeOutCubic,
                                    child: Container(
                                      width: (constraints.maxWidth / _categories.length) - 16,
                                      height: 6,
                                      decoration: BoxDecoration(color: Colors.deepOrange[400], borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.deepOrange.withAlpha((0.18 * 255).round()), blurRadius: 8, offset: const Offset(0, 4))]),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          )
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Popular Items heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Popular Items', style: theme.textTheme.titleMedium?.copyWith(color: Colors.brown[900], fontWeight: FontWeight.w800)),
                        TextButton(
                          onPressed: () {
                            final filtered = menuItems.where((it) => it.category == _categories[_selectedCategory]).toList();
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => AllItemsPage(title: _categories[_selectedCategory], items: filtered)));
                          },
                          child: const Text('See all'),
                        )
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Popular Items carousel (PageView) with centered scale effect
                    SizedBox(
                      height: 180,
                      child: PageView.builder(
                          controller: _pageController,
                          itemCount: menuItems.where((it) => it.category == _categories[_selectedCategory]).length,
                          padEnds: false,
                          physics: const BouncingScrollPhysics(),
                          itemBuilder: (context, index) {
                            final filtered = menuItems.where((it) => it.category == _categories[_selectedCategory]).toList();
                            final it = filtered[index];
                          // compute scale based on how close the page is to center
                          double page = 0;
                          if (_pageController.hasClients) {
                            page = _pageController.page ?? _pageController.initialPage.toDouble();
                          } else {
                            page = _pageController.initialPage.toDouble();
                          }
                          final double delta = (page - index).abs();
                          final double scale = (1 - (min(delta, 1.0) * 0.12)).clamp(0.88, 1.0);

                          return Transform.scale(
                            scale: scale,
                            alignment: Alignment.center,
                            child: Padding(
                              padding: EdgeInsets.only(left: index == 0 ? 0 : 10, right: index == menuItems.length - 1 ? 0 : 10),
                              child: _popularCard(it, index),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Special Offers (animated gradient)
                    Text('Special Offers', style: theme.textTheme.titleMedium?.copyWith(color: Colors.brown[900], fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _offersController,
                      builder: (context, child) {
                        final t = _offersController.value;
                        final c1 = HSLColor.fromAHSL(1, 28 + t * 24, 0.9, 0.6).toColor();
                        final c2 = HSLColor.fromAHSL(1, 12 + t * 24, 0.95, 0.52).toColor();
                        return Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [c1.withAlpha((0.96 * 255).round()), c2.withAlpha((0.9 * 255).round())], begin: Alignment.topLeft, end: Alignment.bottomRight),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.06 * 255).round()), blurRadius: 12, offset: const Offset(0, 8))],
                          ),
                          child: child,
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('20% OFF', style: theme.textTheme.titleLarge?.copyWith(color: Colors.deepOrange[800], fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              const Text('On your first order!'),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              if (menuItems.isNotEmpty) {
                                _addToCart(menuItems[0]);
                              } else {
                                _addToCart(demoItems[0]);
                              }
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange[400], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                            child: const Text('+ Add'),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Spacer to push content up in smaller screens
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            );
              },
            ),
          );
        },
      ),

          // MENU (All items)
          StreamBuilder<List<CartItem>>(
            stream: MenuService.instance.streamMenu(),
            builder: (ctx, snap) {
              final items = snap.data ?? demoItems;
              return AllItemsPage(title: 'Menu', items: items, onBack: () { _mainPageController.animateToPage(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic); setState(() => _selectedNav = 0); });
            },
          ),

          // CART
          CartPage(onBack: () { _mainPageController.animateToPage(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic); setState(() => _selectedNav = 0); }),

          // PROFILE
          // Pass a direct callback to ProfilePage so it can request
          // the parent to navigate back to the Home tab. This is clearer
          // and avoids relying on Notifications for cross-widget wiring.
          ProfilePage(onBack: () {
            if (_mainPageController.hasClients) {
              _mainPageController.animateToPage(0, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
              setState(() => _selectedNav = 0);
            } else {
              // Fallback: if controller not ready, ensure we still reflect state.
              setState(() => _selectedNav = 0);
            }
          }),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCart,
        backgroundColor: Colors.deepOrange[600],
        child: const Icon(Icons.shopping_bag),
      ),
      // Custom modern transparent bottom nav with glass effect, border, and animations
      bottomNavigationBar: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, 12 + MediaQuery.of(context).padding.bottom),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              // use a flexible min height so content can fit and we account for system inset via padding above
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                // use a subtle translucent tint so the BackdropFilter blur has something to blend and the nav doesn't appear black
                color: Colors.white.withAlpha((0.03 * 255).round()),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withAlpha((0.10 * 255).round()), width: 1.0),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 12, offset: const Offset(0, 8))],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // (indicator removed) — visual underline has been disabled per request

                  // Nav items row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                _buildNavItem(Icons.home, 'Home', 0),
                _buildNavItem(Icons.storefront, 'Menu', 1),
                _buildNavItem(Icons.shopping_cart, 'Cart', 2),
                _buildNavItem(Icons.person, 'Profile', 3),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final selected = _selectedNav == index;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        // update selected and animate main PageView to the requested tab
        setState(() => _selectedNav = index);
        if (_mainPageController.hasClients) {
          _mainPageController.animateToPage(index, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
        } else {
          // fallback behavior: keep previous navigation (open cart or push menu)
          if (index == 2) {
            _openCart();
          } else if (index == 1) {
            final filtered = demoItems.where((it) => it.category == _categories[_selectedCategory]).toList();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => AllItemsPage(title: 'Menu', items: filtered)));
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.18 : 1.0,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutBack,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: selected ? Colors.white.withOpacity(0.12) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: selected ? Colors.white.withOpacity(0.14) : Colors.white.withOpacity(0.04), width: selected ? 1.4 : 1.0),
                ),
                child: Icon(icon, color: Colors.black, size: 20),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: TextStyle(fontSize: 10, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: Colors.black),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

// AllItemsPage moved to top-level below to avoid class nesting issues.

  // category selector handled inline with animated buttons above

  Widget _popularCard(CartItem it, int index) {
    final pressed = _pressedPopularIndex == index;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.white.withAlpha((0.98 * 255).round()), Colors.white.withAlpha((0.92 * 255).round())], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withAlpha((0.06 * 255).round())),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.04 * 255).round()), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Container(
            height: 84,
            width: 84,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [Colors.orange[100]!, Colors.orange[50]!]),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(it.emoji, style: const TextStyle(fontSize: 38))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 6),
                Text('Delicious • Hot • Fresh', style: TextStyle(color: Colors.brown[300], fontSize: 12)),
                const SizedBox(height: 8),
                Text('₱${it.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.brown, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          // Add button: icon + text 'Add' (no duplicated '+')
          AnimatedScale(
            duration: const Duration(milliseconds: 180),
            scale: pressed ? 0.92 : 1.0,
            curve: Curves.easeOutBack,
            child: InkWell(
              onTap: () => _addToCartWithFeedback(it, index, 1),
              onLongPress: () => _addToCartWithFeedback(it, index, 3),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: pressed ? Colors.deepOrange[400] : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.deepOrange[400]!, width: 1.6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.add, size: 18, color: pressed ? Colors.white : Colors.deepOrange[400]),
                    const SizedBox(width: 6),
                    Text('Add', style: TextStyle(color: pressed ? Colors.white : Colors.deepOrange[400], fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }

  void _addToCartWithFeedback(CartItem it, int index, [int count = 1]) {
    setState(() => _pressedPopularIndex = index);
    for (var i = 0; i < count; i++) {
      cart.addItem(it);
    }
    _showAddedPopup(it, count);
    // revert the press animation shortly after
    Future.delayed(const Duration(milliseconds: 360), () {
      if (!mounted) return;
      setState(() => _pressedPopularIndex = -1);
    });
  }

  bool _isShowingAddDialog = false;

  void _showAddedPopup(CartItem it, int count) {
    if (_isShowingAddDialog) return;
    _isShowingAddDialog = true;

    // showGeneralDialog gives us a lightweight popup we can auto-close
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Added',
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (ctx, anim1, anim2) {
        return SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Material(
              color: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28, vertical: 80),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 16, offset: const Offset(0, 8))],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(height: 56, width: 56, decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(10)), child: Center(child: Text(it.emoji, style: const TextStyle(fontSize: 28)))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${it.name} added', style: const TextStyle(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 6),
                          Text('₱${it.price.toStringAsFixed(2)} • $count', style: const TextStyle(color: Colors.black54)),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Undo: remove last `count` items
                        for (var i = 0; i < count; i++) {
                          if (cart.items.isNotEmpty) cart.removeAt(cart.items.length - 1);
                        }
                        setState(() {});
                        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                      },
                      child: const Text('Undo'),
                    ),
                    TextButton(
                      onPressed: () {
                        // open cart
                        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
                        _openCart();
                      },
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, a1, a2, child) => FadeTransition(opacity: CurvedAnimation(parent: a1, curve: Curves.easeOut), child: child),
    ).then((_) {
      // when dialog closes (dismissed or timed), clear flag
      _isShowingAddDialog = false;
    });

    // auto-dismiss after a short delay if still open
    Future.delayed(const Duration(seconds: 2), () {
      if (!_isShowingAddDialog) return;
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    });
  }
}
