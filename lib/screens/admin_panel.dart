import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:doughminant/models/cart_model.dart';
import 'package:doughminant/services/menu_service.dart';
import 'package:doughminant/screens/admin_profile.dart';
import 'package:doughminant/screens/admin_orders_page.dart';
import '../services/notification_service.dart';
import '../widgets/notification_tile.dart';

/// AdminPanelPage
/// A modern / futuristic admin panel screen with animated dashboard cards,
/// horizontal "Manage Menu" carousel, Tools grid, and quick actions.
///
/// This file contains placeholder detail pages to make navigation easy
/// during development. Integrate the page by pushing `AdminPanelPage()`
/// from your app's navigation (or add it to routes).

class AdminPanelPage extends StatefulWidget {
  const AdminPanelPage({super.key});

  @override
  State<AdminPanelPage> createState() => _AdminPanelPageState();
}

// -----------------------------------------------------------------------------
// Admin auth gate
// -----------------------------------------------------------------------------
/// Replace the email below with the admin account email you created in
/// Firebase Authentication. The user must sign in with this email + password
/// to open the admin panel.
const List<String> kAdminEmails = [
  // TODO: change this to your admin email
  'erin@gmail.com',
];

/// Widget that shows a small login form for admin credentials and navigates
/// to the real `AdminPanelPage` only when sign-in succeeds and the signed-in
/// user's email is in `kAdminEmails`.
class AdminPanelAuth extends StatefulWidget {
  const AdminPanelAuth({super.key});

  @override
  State<AdminPanelAuth> createState() => _AdminPanelAuthState();
}

class _AdminPanelAuthState extends State<AdminPanelAuth> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signInAndOpen() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email and password')));
      return;
    }
    setState(() => _loading = true);
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      final user = cred.user;
      if (user == null) throw Exception('Sign in returned no user');
      final allowed = kAdminEmails.contains(user.email);
      if (!allowed) {
        // not an admin — sign out and show error
        await FirebaseAuth.instance.signOut();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account is not authorized for admin panel')));
      } else {
        // open admin panel page
        if (!mounted) return;
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPanelPage()));
      }
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Auth error')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Login')),
      body: Center(
        child: Card(
          margin: const EdgeInsets.symmetric(horizontal: 22),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Admin email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _signInAndOpen,
                    child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () async {
                    // convenience: open AdminPanelPage if already signed-in and allowed
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null && kAdminEmails.contains(user.email)) {
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminPanelPage()));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No signed-in admin detected')));
                    }
                  },
                  child: const Text('I am already signed in'),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class _AdminPanelPageState extends State<AdminPanelPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openManageMenu() async {
    // disable Hero animations for the pushed page to avoid Hero tag collisions
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => HeroMode(enabled: false, child: const ManageMenuPage())),
    );
    // If ManageMenuPage returned true, switch the panel to Home
    if (res == true && mounted) {
      setState(() => _selectedIndex = 0);
    }
  }

  void _openOrders() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminOrdersPage()),
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
                return Center(child: Text('Unable to load notifications: ${snap.error}'));
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
                      Navigator.of(context).pop();
                      if (n.orderId != null && n.orderId!.isNotEmpty) {
                        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AdminOrdersPage()));
                      }
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          // Show back arrow only when on the Menu tab; otherwise leave space
          _selectedIndex == 1
              ? IconButton(
                  onPressed: () => setState(() => _selectedIndex = 0),
                  icon: const Icon(Icons.arrow_back_ios_new),
                  color: Colors.white,
                )
              : const SizedBox(width: 48),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Admin Panel',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Dashboard Overview',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // live admin notifications bell with unread count and sheet
          StreamBuilder<int>(
            stream: NotificationService.instance.unreadCountAdmin(),
            builder: (context, snap) {
              final count = snap.data ?? 0;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: _openAdminNotificationsSheet,
                    icon: const Icon(Icons.notifications_none),
                    color: Colors.white,
                  ),
                  if (count > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.deepOrangeAccent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 6)],
                        ),
                        constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
                        child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.center),
                      ),
                    )
                ],
              );
            },
          )
        ],
      ),
    );
  }

  Widget _buildOverviewCards(BuildContext context) {
    final values = <Map<String, String>>[
      {'title': 'Total Orders', 'value': '1,560'},
      {'title': 'Revenue', 'value': '₱15,000'},
      {'title': 'New Users', 'value': '250'},
    ];

    return SizedBox(
      height: 120,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            itemCount: values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, idx) {
              final item = values[idx];
              final t = (_controller.value - (idx * 0.12)).clamp(0.0, 1.0);
              final scale = Tween<double>(begin: 0.92, end: 1.0).transform(Curves.easeOut.transform(t));
              final opacity = t;

              return Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity,
                  child: _OverviewCard(
                    title: item['title']!,
                    value: item['value']!,
                    accent: idx == 1 ? Colors.tealAccent.shade200 : Colors.pinkAccent.shade100,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildManageMenuCarousel(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Manage Menu', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
              TextButton.icon(
                onPressed: _openManageMenu,
                icon: const Icon(Icons.list, color: Colors.white70),
                label: const Text('Manage', style: TextStyle(color: Colors.white70)),
              )
            ],
          ),
        ),
        const SizedBox(height: 8),
        // increased height and bottom padding to avoid a subtle 2px RenderFlex overflow
        SizedBox(
          height: 130,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: StreamBuilder<List<CartItem>>(
              stream: MenuService.instance.streamMenu(),
              builder: (ctx, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(
                      child: Text('Error loading menu: ${snap.error}', style: const TextStyle(color: Colors.redAccent)),
                    ),
                  );
                }

                final items = snap.data ?? [];
                if (items.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Center(child: Text('No menu items', style: TextStyle(color: Colors.white70))),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 18.0),
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final it = items[i];
                    return GestureDetector(
                      onTap: () => _showMenuItem(context, {'name': it.name, 'price': '₱${it.price.toStringAsFixed(2)}'}),
                      child: SizedBox(
                        width: 220,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            height: 112,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 8, offset: const Offset(0, 6))],
                            ),
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  width: 64,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(colors: [Colors.deepOrange.shade200, Colors.deepOrange.shade400]),
                                  ),
                                  child: Center(child: Text(it.emoji.isNotEmpty ? it.emoji : '🍕', style: const TextStyle(fontSize: 28))),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                                      const SizedBox(height: 6),
                                      Text('₱${it.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.more_vert, color: Colors.white70),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  void _showMenuItem(BuildContext context, Map<String, String> item) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(item['name'] ?? ''),
        content: Text('Price: ${item['price']}\n\nManage this menu item (edit, remove, analytics).'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Edit')),
        ],
      ),
    );
  }

  Widget _buildToolsGrid(BuildContext context) {
    final tools = [
      {'label': 'Analytics', 'icon': Icons.bar_chart},
      {'label': 'Discounts', 'icon': Icons.local_offer},
      {'label': 'Support', 'icon': Icons.support_agent},
      {'label': 'Settings', 'icon': Icons.settings},
      {'label': 'Accounts', 'icon': Icons.people},
      {'label': 'Inventory', 'icon': Icons.inventory_2},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 8),
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: tools.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemBuilder: (context, i) {
          final t = tools[i];
          return GestureDetector(
            onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${t['label']} tapped'))),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    child: Icon(t['icon'] as IconData, color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 8),
                    Text(t['label'] as String, style: const TextStyle(color: Colors.white70, fontSize: 12), textAlign: TextAlign.center),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOverviewCards(context),
          const SizedBox(height: 12),
          _buildManageMenuCarousel(context),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Text('Tools', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
          ),
          const SizedBox(height: 8),
          _buildToolsGrid(context),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18.0),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openOrders,
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('View Orders'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrangeAccent),
                  ),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: null,
                  onPressed: () {},
                  mini: true,
                  backgroundColor: Colors.pinkAccent,
                  child: const Icon(Icons.add),
                )
              ],
            ),
          ),
          const SizedBox(height: 28),
        ],
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Animated futuristic gradient background + subtle blur
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final glow = 0.6 + (_controller.value * 0.6);
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: const Alignment(-0.9, -0.6),
                      radius: 1.2,
                      colors: [
                        Colors.deepOrange.shade400.withValues(alpha: 0.65 * glow),
                        Colors.deepPurple.shade700.withValues(alpha: 0.8 * (1 - _controller.value) + 0.2),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                );
              },
            ),
          ),
          // subtle frosted glass overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8.0 * (0.6), sigmaY: 8.0 * (0.6)),
              child: Container(color: Colors.black.withValues(alpha: 0.12)),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(top: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.02),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(18),
                        topRight: Radius.circular(18),
                      ),
                      child: IndexedStack(
                        index: _selectedIndex,
                        children: [
                          // Dashboard
                          _buildBody(context),
                          // Manage Menu (full page) - show the dedicated ManageMenuPage
                          // so admins can add/edit/delete directly from the Menu tab.
                          const ManageMenuPage(),
                          // Orders tab: open the Orders Manager directly
                          const AdminOrdersPage(),
                          // Profile (admin) — full page
                          const AdminProfilePage(),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: Colors.white),
        unselectedIconTheme: const IconThemeData(color: Colors.white),
        selectedLabelStyle: const TextStyle(color: Colors.white),
        unselectedLabelStyle: const TextStyle(color: Colors.white),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Menu'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined), label: 'Orders'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final Color accent;

  const _OverviewCard({
    required this.title,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(colors: [accent.withValues(alpha: 0.22), Colors.white.withValues(alpha: 0.02)]),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 12, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.show_chart, color: Colors.white70, size: 18),
              )
            ],
          )
        ],
      ),
    );
  }
}

// Placeholder ManageMenuPage for quick navigation during development
class ManageMenuPage extends StatelessWidget {
  const ManageMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          // Signal the caller to go Home when the user navigates back from this page
          Navigator.of(context).pop(true);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          // Leading back arrow removed because the parent AdminPanel already
          // displays a back control when the Menu tab is selected. This
          // prevents showing two back arrows side-by-side.
          title: const Text('Manage Menu'),
        ),
        body: StreamBuilder<List<CartItem>>(
          stream: MenuService.instance.streamMenu(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()));
        if (snap.hasError) return Padding(padding: const EdgeInsets.all(12), child: Center(child: Text('Error loading menu: ${snap.error}')));
        final items = snap.data ?? [];
        if (items.isEmpty) return const Padding(padding: EdgeInsets.all(12), child: Center(child: Text('No menu items')));
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final it = items[i];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Text(it.emoji.isNotEmpty ? it.emoji : '🍕')),
                    title: Text(it.name),
                    subtitle: Text('₱${it.price.toStringAsFixed(2)} · ${it.category}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          final nameCtrl = TextEditingController(text: it.name);
                          final priceCtrl = TextEditingController(text: it.price.toString());
                          final emojiCtrl = TextEditingController(text: it.emoji);
                          final catCtrl = TextEditingController(text: it.category);
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Edit Menu Item'),
                              content: SingleChildScrollView(
                                child: Column(mainAxisSize: MainAxisSize.min, children: [
                                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                                  TextField(controller: priceCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price')),
                                  TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
                                  TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
                                ]),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                                ElevatedButton(
                                  onPressed: () async {
                                    final name = nameCtrl.text.trim();
                                    final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                                    final emoji = emojiCtrl.text.trim();
                                    final cat = catCtrl.text.trim();
                                    try {
                                      await MenuService.instance.updateMenuItem(it.id, {'name': name, 'price': price, 'emoji': emoji, 'category': cat});
                                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Item updated')));
                                      Navigator.of(ctx).pop();
                                    } catch (e) {
                                      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Update failed: $e')));
                                    }
                                  },
                                  child: const Text('Save'),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete item'),
                              content: Text('Delete ${it.name}?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await MenuService.instance.deleteMenuItem(it.id);
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Item deleted')));
                            } catch (e) {
                              if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
                            }
                          }
                        },
                      ),
                    ]),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          heroTag: null,
          onPressed: () {
            final nameCtrl = TextEditingController();
            final priceCtrl = TextEditingController();
            final emojiCtrl = TextEditingController();
            final catCtrl = TextEditingController();
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Add Menu Item'),
                content: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name')),
                    TextField(controller: priceCtrl, keyboardType: TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Price')),
                    TextField(controller: emojiCtrl, decoration: const InputDecoration(labelText: 'Emoji')),
                    TextField(controller: catCtrl, decoration: const InputDecoration(labelText: 'Category')),
                  ]),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameCtrl.text.trim();
                      final price = double.tryParse(priceCtrl.text.trim()) ?? 0.0;
                      final emoji = emojiCtrl.text.trim();
                      final cat = catCtrl.text.trim();
                      try {
                        await MenuService.instance.addMenuItem({'name': name, 'price': price, 'emoji': emoji, 'category': cat});
                        Navigator.of(ctx).pop();
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Menu item added')));
                      } catch (e) {
                        if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Add failed: $e')));
                      }
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class OrdersSheet extends StatelessWidget {
  const OrdersSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final orders = List.generate(6, (i) => {'title': 'Order #${1000 + i}', 'total': '₱${(20 + i * 5)}'});
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, sc) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
            ),
            child: ListView.builder(
              controller: sc,
              itemCount: orders.length + 1,
              itemBuilder: (context, idx) {
                if (idx == 0) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Orders', style: Theme.of(context).textTheme.headlineSmall),
                        IconButton(onPressed: () => Navigator.of(context).pop(), icon: const Icon(Icons.close))
                      ],
                    ),
                  );
                }
                final order = orders[idx - 1];
                return ListTile(
                  title: Text(order['title']!),
                  subtitle: Text('Placed • 2 items'),
                  trailing: Text(order['total']!),
                  onTap: () {},
                );
              },
            ),
          );
        },
      ),
    );
  }
}
