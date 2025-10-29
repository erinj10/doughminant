import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/cart_model.dart';
import '../models/order.dart' as ord;
import '../services/order_service.dart';

class CartPage extends StatefulWidget {
  // optional onBack allows the page to be embedded in a parent PageView
  final VoidCallback? onBack;

  const CartPage({super.key, this.onBack});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> with TickerProviderStateMixin {
  final CartModel cart = CartModel.instance;

  // For Animated total display
  double _animatedTotal = 0.0;

  // header entrance animation
  late final AnimationController _headerController;

  // Staggered entrance control for list items
  final Set<int> _visibleItems = {};

  // Payment & checkout
  String _paymentMethod = 'Cash';
  final double _deliveryFee = 1.50;
  bool _placingOrder = false;
  // Delivery address
  String _address = 'No address set';
  bool _leaveAtDoor = false;

  @override
  void initState() {
    super.initState();
    cart.addListener(_onCartChanged);
    _animatedTotal = cart.totalPrice;
    // trigger initial stagger animation
    WidgetsBinding.instance.addPostFrameCallback((_) => _staggerItems());
    _headerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 620))..forward();
  }

  @override
  void dispose() {
    cart.removeListener(_onCartChanged);
    _headerController.dispose();
    super.dispose();
  }

  void _onCartChanged() {
    // update animated total and re-run item reveal (so newly added items animate in)
    _updateAnimatedTotal();
    _staggerItems();
    setState(() {});
  }

  void _updateAnimatedTotal() {
    setState(() {
      _animatedTotal = cart.totalPrice;
    });
  }

  void _staggerItems() {
    _visibleItems.clear();
    final groups = cart.grouped();
    for (var i = 0; i < groups.length; i++) {
      Future.delayed(Duration(milliseconds: 80 * i), () {
        if (!mounted) return;
        setState(() {
          _visibleItems.add(i);
        });
      });
    }
  }

  void _choosePayment() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(title: const Text('Cash'), onTap: () => Navigator.of(ctx).pop('Cash')),
        ListTile(title: const Text('Card'), onTap: () => Navigator.of(ctx).pop('Card')),
        ListTile(title: const Text('GPay'), onTap: () => Navigator.of(ctx).pop('GPay')),
      ]),
    );
    if (choice != null && mounted) setState(() => _paymentMethod = choice);
  }

  Future<void> _placeOrder() async {
    if (_placingOrder || cart.items.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please sign in to place an order.')));
      return;
    }

    setState(() => _placingOrder = true);

    // Show progress dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [CircularProgressIndicator(), SizedBox(height: 12), Text('Processing payment...')]),
        ),
      ),
    );

    try {
      // Simulate payment success delay (replace with real gateway integration)
      await Future.delayed(const Duration(milliseconds: 900));

      // Map cart items to order items
      final grouped = cart.grouped();
      final List<ord.OrderItem> orderItems = [];
      grouped.forEach((id, data) {
        final item = data['item'] as CartItem;
        final count = data['count'] as int;
        // Map customizable options from CartItem.customizationSchema if present
        Map<String, dynamic>? options;
        if (item.customizationSchema != null) {
          // Persist the schema so admin can see chosen configuration.
          // If you later store actual user selections separately, merge them here.
          options = {
            'schema': item.customizationSchema,
          };
        }
        orderItems.add(ord.OrderItem(
          id: id,
          name: item.name,
          quantity: count,
          price: item.price,
          options: options,
        ));
      });

      final subtotal = cart.totalPrice;
      final total = subtotal + _deliveryFee;

      // Delivery info
      final delivery = ord.DeliveryInfo(
        addressLine: _address == 'No address set' ? null : _address,
        contactName: user.displayName,
        contactPhone: null,
        coordinates: null,
      );

      // Create order in Firestore
      final orderId = await OrderService.instance.placeOrder(
        userId: user.uid,
        items: orderItems,
        total: total,
        customerName: user.displayName,
        customerEmail: user.email,
        deliveryInfo: delivery,
        notes: _leaveAtDoor ? 'Leave at door' : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // close progress

      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Success!'),
          content: Text('Order placed. Order #$orderId'),
          actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
        ),
      );

      cart.clear();
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = cart.grouped();
    final subtotal = cart.totalPrice;
    final total = subtotal + _deliveryFee;

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(110),
        child: AnimatedBuilder(
          animation: _headerController,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_headerController.value);
            return SafeArea(
              bottom: false,
              child: Transform.translate(
                offset: Offset(0, -10 * (1 - t)),
                child: Opacity(
                  opacity: t,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10 * t, sigmaY: 10 * t),
                      child: Container(
                        height: 110,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.deepOrange.shade600.withAlpha((0.98 * 255).round()), Colors.deepOrange.shade400.withAlpha((0.96 * 255).round())], begin: Alignment.topLeft, end: Alignment.bottomRight),
                          boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.12 * 255).round()), blurRadius: 18, offset: const Offset(0, 8))],
                        ),
                        child: Row(
                          children: [
                            // Back / close
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    if (widget.onBack != null) {
                                      widget.onBack!();
                                    } else {
                                      Navigator.of(context).pop();
                                    }
                                  },
                                  child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.white.withAlpha((0.06 * 255).round()), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.arrow_back_ios_new, color: Colors.white)),
                                ),
                              ),
                            const SizedBox(width: 12),

                            // Title + subtitle
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                                Text('Cart & Checkout', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 6),
                                Row(children: [Text('${cart.totalCount} items', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70)), const SizedBox(width: 10),
                                  TweenAnimationBuilder<double>(
                                    tween: Tween(begin: _animatedTotal, end: subtotal),
                                    duration: const Duration(milliseconds: 420),
                                    builder: (context, value, child) => Text('₱${value.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                                    onEnd: () => _animatedTotal = subtotal,
                                  ),
                                ]),
                              ]),
                            ),

                            // Cart icon with badge
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withAlpha((0.08 * 255).round()), borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.shopping_cart_outlined, color: Colors.white)),
                                if (cart.totalCount > 0)
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle), child: Text(cart.totalCount.toString(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800))),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      body: cart.items.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 140,
                    width: 260,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [Colors.orange[50]!, Colors.orange[100]!]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: const [Text('🛒', style: TextStyle(fontSize: 44)), SizedBox(height: 8), Text('Your cart is empty', style: TextStyle(fontSize: 16))]),
                  ),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to menu'))
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                children: [
                  // Glass header showing cart title and animated total
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.white.withAlpha((0.08 * 255).round()), Colors.white.withAlpha((0.04 * 255).round())]),
                        ),
                        child: Row(
                          children: [
                            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Your Cart', style: Theme.of(context).textTheme.titleLarge), Text('${cart.totalCount} items', style: Theme.of(context).textTheme.bodySmall)]),
                            const Spacer(),
                            // animated subtotal
                            TweenAnimationBuilder<double>(
                              tween: Tween(begin: _animatedTotal, end: subtotal),
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) => Text('₱${value.toStringAsFixed(2)}', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                              onEnd: () => _animatedTotal = subtotal,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Items list with staggered entrance
                  Expanded(
                    child: ListView.separated(
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, idx) {
                        final entry = groups.entries.toList()[idx];
                        final id = entry.key;
                        final item = entry.value['item'] as CartItem;
                        final count = entry.value['count'] as int;
                        final visible = _visibleItems.contains(idx);

                        return Dismissible(
                          key: Key(id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            alignment: Alignment.centerRight,
                            decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            // remove all instances and offer undo
                            cart.removeQuantity(id, count);
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('$count × ${item.name} removed'),
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(label: 'Undo', onPressed: () {
                                for (var i = 0; i < count; i++) {
                                  cart.addItem(item);
                                }
                              }),
                            ));
                          },
                          child: TweenAnimationBuilder<double>(
                            duration: const Duration(milliseconds: 420),
                            curve: Curves.easeOutCubic,
                            tween: Tween(begin: visible ? 1.0 : 0.0, end: visible ? 1.0 : 0.0),
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(offset: Offset(0, (1 - value) * 18), child: child),
                            ),
                            child: AnimatedSize(
                              duration: const Duration(milliseconds: 220),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: Colors.white.withAlpha((0.98 * 255).round()), borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.03 * 255).round()), blurRadius: 12, offset: const Offset(0, 6))]),
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onLongPress: () {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(item.name),
                                            content: Column(mainAxisSize: MainAxisSize.min, children: [Text('Price: ₱${item.price.toStringAsFixed(2)}'), const SizedBox(height: 8), Text('Quantity: $count')]),
                                            actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))],
                                          ),
                                        );
                                      },
                                      child: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(10)), child: Text(item.emoji, style: const TextStyle(fontSize: 28))),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 6), Text('₱${item.price.toStringAsFixed(2)} each', style: const TextStyle(color: Colors.black54))]),
                                    ),
                                    // quantity controls
                                    Row(children: [
                                      IconButton(
                                        onPressed: () {
                                          cart.removeOneById(id);
                                        },
                                        icon: const Icon(Icons.remove_circle_outline),
                                      ),
                                      Text('$count', style: const TextStyle(fontWeight: FontWeight.w800)),
                                      IconButton(
                                        onPressed: () {
                                          cart.addItem(item);
                                        },
                                        icon: const Icon(Icons.add_circle_outline),
                                      ),
                                    ]),
                                    const SizedBox(width: 8),
                                    Text('₱${(item.price * count).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Order summary card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withAlpha((0.98 * 255).round())),
                    child: Column(
                      children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Subtotal', style: Theme.of(context).textTheme.bodyLarge), Text('₱${subtotal.toStringAsFixed(2)}')]),
                        const SizedBox(height: 8),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Delivery Fee', style: Theme.of(context).textTheme.bodySmall), Text('₱${_deliveryFee.toStringAsFixed(2)}')]),
                        const Divider(height: 18),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)), Text('₱${total.toStringAsFixed(2)}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))]),
                        const SizedBox(height: 8),
                        // Payment method
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.payment_outlined),
                          title: Text('Payment Method'),
                          subtitle: Text(_paymentMethod),
                          trailing: TextButton(onPressed: _choosePayment, child: const Text('Change')),
                        ),

                        // Delivery address placed directly below payment method for visibility
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.location_on_outlined),
                          title: const Text('Delivery'),
                          subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_address, maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Row(children: [
                              Switch(value: _leaveAtDoor, onChanged: (v) => setState(() => _leaveAtDoor = v)),
                              const SizedBox(width: 6),
                              const Text('Leave at door')
                            ])
                          ]),
                          trailing: TextButton(
                            onPressed: () async {
                              final res = await showModalBottomSheet<String>(
                                context: context,
                                isScrollControlled: true,
                                builder: (ctx) {
                                  final controller = TextEditingController(text: _address == 'No address set' ? '' : _address);
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                                        const Text('Delivery Address', style: TextStyle(fontWeight: FontWeight.w800)),
                                        const SizedBox(height: 8),
                                        TextField(controller: controller, decoration: const InputDecoration(hintText: 'Enter address')),
                                        const SizedBox(height: 12),
                                        Row(children: [
                                          Expanded(child: OutlinedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel'))),
                                          const SizedBox(width: 8),
                                          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(controller.text.trim()), child: const Text('Save')),
                                        ])
                                      ]),
                                    ),
                                  );
                                },
                              );
                              if (res != null && mounted) setState(() => _address = res.isEmpty ? 'No address set' : res);
                            },
                            child: const Text('Edit'),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Place Order bar
                  SafeArea(
                    top: false,
                    child: Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _placingOrder ? null : _placeOrder,
                            icon: AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: _placingOrder ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.shopping_bag_outlined)),
                            label: Text(_placingOrder ? 'Placing...' : 'Place Order • ₱${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                            style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(56), backgroundColor: Colors.deepOrange[700], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
