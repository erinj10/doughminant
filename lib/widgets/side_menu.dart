import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/notification_service.dart';
import '../widgets/notification_tile.dart';
import '../services/firebase_auth_service.dart';
import '../screens/order_tracking.dart';
import '../screens/profile_page.dart';
import '../screens/cart_page.dart';
import '../screens/login_page.dart';

class SideMenu extends StatefulWidget {
  final void Function(int)? onSelectPage;
  const SideMenu({Key? key, this.onSelectPage}) : super(key: key);

  @override
  State<SideMenu> createState() => _SideMenuState();
}

class _SideMenuState extends State<SideMenu> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  String? _avatarPath;
  final ImagePicker _picker = ImagePicker();

  // controller and other initialization are set up later in the file

 
  String? _avatarUrl;
  String _name = 'Jane Doe';
  String _email = 'janedoe@email.com';
  String _phone = '+63 912 345 6789';
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  final _items = <Map<String, Object>>[
    {'icon': Icons.person, 'title': 'Profile'},
    {'icon': Icons.local_shipping, 'title': 'Orders & Tracking'},
    {'icon': Icons.history, 'title': 'Company History'},
    {'icon': Icons.storefront, 'title': 'About our Products'},
    {'icon': Icons.shopping_cart, 'title': 'Cart'},
    {'icon': Icons.info_outline, 'title': 'About the App'},
    {'icon': Icons.code, 'title': 'Developers'},
    {'icon': Icons.contact_mail, 'title': 'Contact Us'},
  ];

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
    _loadAvatar();
  _populateFromAuth();
  _subscribeProfile();
    // start entrance animation slightly delayed so drawer slide feels layered
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  // Notification bell for user: shows unread count and opens notifications sheet
  Widget _notificationBell() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();
    return StreamBuilder<int>(
      stream: NotificationService.instance.unreadCountForUser(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(children: [
          IconButton(onPressed: _openNotificationsSheet, icon: const Icon(Icons.notifications_outlined)),
          if (count > 0)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(12)),
                constraints: const BoxConstraints(minWidth: 20, minHeight: 16),
                child: Text(count.toString(), style: const TextStyle(color: Colors.white, fontSize: 11), textAlign: TextAlign.center),
              ),
            )
        ]);
      },
    );
  }

  void _openNotificationsSheet() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: SizedBox(
          height: 420,
              child: StreamBuilder<List<NotificationModel>>(
            stream: NotificationService.instance.streamForUser(uid),
            builder: (context, snap) {
              final notes = snap.data ?? [];
              if (notes.isEmpty) return const Center(child: Text('No notifications'));
              return ListView.separated(
                itemCount: notes.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final n = notes[i];
                  return NotificationTile(
                    model: n,
                    isAdmin: false,
                        onMarkRead: () => NotificationService.instance.markRead(n.id),
                        onDelete: () => NotificationService.instance.delete(n.id),
                    onTap: () async {
                      await NotificationService.instance.markRead(n.id);
                      Navigator.of(context).pop();
                      if (n.orderId != null) {
                        if (widget.onSelectPage != null) widget.onSelectPage!(1);
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

  void _populateFromAuth() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        setState(() {
          if (user.displayName != null && user.displayName!.isNotEmpty) _name = user.displayName!;
          if (user.email != null && user.email!.isNotEmpty) _email = user.email!;
          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) _phone = user.phoneNumber!;
        });
      }
    } catch (_) {}
  }

  void _subscribeProfile() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      _profileSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snap) {
        if (snap.exists && mounted) {
          final data = snap.data() ?? <String, dynamic>{};
          setState(() {
            final fullname = (data['fullname'] ?? '') as String;
            final phone = (data['phone'] ?? '') as String;
            final email = (data['email'] ?? '') as String;
            final avatar = data['avatarUrl'] as String?;
            if (fullname.isNotEmpty) _name = fullname;
            if (email.isNotEmpty) _email = email;
            if (phone.isNotEmpty) _phone = phone;
            if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
          });
        }
      }, onError: (err) {
        // ignore errors silently, but could log if needed
      });
    } catch (_) {}
  }

  void _showAboutApp() {
    const aboutApp = '''📱 About the App – Doughminant

Doughminant is a modern pizza ordering app designed to bring convenience, creativity, and flavor right to your fingertips. Built with a passion for both food and technology, the app offers a seamless and enjoyable way to browse menus, place orders, and track deliveries—all within a few simple taps.

Our goal is to make every pizza experience dominant—easy, fast, and fun. With its clean, user-friendly interface and vibrant design, Doughminant makes it effortless for customers to explore our menu, customize their orders, and enjoy exclusive promos anytime, anywhere.

Key Features

🍕 Interactive Menu – Browse through our full list of pizzas, sides, and desserts with vivid photos and detailed descriptions.
🛒 Smart Ordering System – Add items to your cart, apply discounts, and check out with ease.
📦 Order Tracking – Stay updated with real-time tracking from preparation to delivery.
⭐ Personalized Experience – Save your favorite orders and get recommendations based on your taste.
💳 Secure Payment Options – Pay effortlessly through cash, card, or mobile payment gateways.

With Doughminant, pizza lovers can experience a new level of comfort and satisfaction. Whether you’re at home, at work, or on the go—Doughminant makes sure your favorite pizza is just a tap away.
''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.64,
          minChildSize: 0.42,
          maxChildSize: 0.95,
          builder: (context, controller) {
            // local animated visibility for feature list
            final vis = List<bool>.filled(5, false);
            var started = false;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? LinearGradient(colors: [Colors.grey[900]!, Colors.grey[850]!])
                    : LinearGradient(colors: [Colors.white, Colors.grey[50]!]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.12)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6))],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(children: [
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset('assets/app_icon.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('About the App', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Doughminant — modern, fast, delicious', style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () async { await Clipboard.setData(const ClipboardData(text: aboutApp)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('About text copied'))); }, icon: const Icon(Icons.copy_outlined)),
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () async { await Share.share(aboutApp, subject: 'About Doughminant'); }, icon: const Icon(Icons.share_outlined)),
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () async {
                      try {
                        final doc = pw.Document();
                        doc.addPage(pw.MultiPage(build: (pw.Context pwContext) => [pw.Header(level: 0, child: pw.Text('About the App – Doughminant')), pw.Paragraph(text: aboutApp)]));
                        final bytes = await doc.save();
                        await Printing.sharePdf(bytes: bytes, filename: 'doughminant_about_app.pdf');
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to export PDF')));
                      }
                    }, icon: const Icon(Icons.picture_as_pdf_outlined)),
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                  ])
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: StatefulBuilder(builder: (context, setStateSB) {
                      if (!started) {
                        started = true;
                        for (var i = 0; i < vis.length; i++) {
                          Future.delayed(Duration(milliseconds: 80 * i), () => setStateSB(() => vis[i] = true));
                        }
                      }

                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 360),
                          opacity: vis[0] ? 1 : 0,
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
                            ),
                            child: Text(
                              'Doughminant is a modern pizza ordering app designed to bring convenience, creativity, and flavor right to your fingertips. Built with a passion for both food and technology, the app offers a seamless and enjoyable way to browse menus, place orders, and track deliveries—all within a few simple taps.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AnimatedOpacity(duration: const Duration(milliseconds: 380), opacity: vis[1] ? 1 : 0, child: Text('Key Features', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                        const SizedBox(height: 8),
                        AnimatedOpacity(duration: const Duration(milliseconds: 380), opacity: vis[2] ? 1 : 0, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _FeatureChip(icon: Icons.local_pizza, title: 'Interactive Menu – vivid photos & descriptions'),
                          const SizedBox(height: 8),
                          _FeatureChip(icon: Icons.shopping_cart, title: 'Smart Ordering System – discounts & checkout'),
                          const SizedBox(height: 8),
                          _FeatureChip(icon: Icons.local_shipping, title: 'Order Tracking – from prep to delivery'),
                          const SizedBox(height: 8),
                          _FeatureChip(icon: Icons.star, title: 'Personalized Experience – favorites & recommendations'),
                          const SizedBox(height: 8),
                          _FeatureChip(icon: Icons.credit_card, title: 'Secure Payment Options'),
                        ])),
                        const SizedBox(height: 16),
                        AnimatedOpacity(duration: const Duration(milliseconds: 420), opacity: vis[3] ? 1 : 0, child: Text('Why Doughminant?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                        const SizedBox(height: 8),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 420),
                          opacity: vis[4] ? 1 : 0,
                          child: Text(
                            'With Doughminant, pizza lovers can experience a new level of comfort and satisfaction. Whether you’re at home, at work, or on the go—Doughminant makes sure your favorite pizza is just a tap away.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ]);
                    }),
                  ),
                ),
                const SizedBox(height: 8),
                // pinned action row
                Padding(
                  padding: EdgeInsets.only(bottom: 12 + MediaQuery.of(context).viewPadding.bottom),
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close), label: const Text('Close'))),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(onPressed: () {
                      if (widget.onSelectPage != null) {
                        widget.onSelectPage!(1);
                        Navigator.of(ctx).pop();
                      } else {
                        Navigator.of(ctx).pop();
                      }
                    }, icon: const Icon(Icons.storefront), label: const Text('Open Menu')),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final p = prefs.getString('profile_avatar_path');
      if (p != null && mounted) setState(() => _avatarPath = p);
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 800, maxHeight: 800, imageQuality: 80);
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/drawer_avatar_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_avatar_path', file.path);
      if (!mounted) return;
      setState(() => _avatarPath = file.path);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick avatar')));
    }
  }

  void _showSheet(String title, String body) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 8),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
          Align(alignment: Alignment.centerRight, child: ElevatedButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close'))),
        ]),
      ),
    );
  }

  void _showCompanyHistory() {
    const companyText = '''Founded in 2025, Doughminant began as a bold idea from a group of passionate students who wanted to revolutionize the pizza ordering experience. Inspired by the love for pizza and the desire to “dominate” the food delivery game, they combined creativity, technology, and teamwork to create an app that stands out from the rest.

The name “Doughminant” represents the perfect blend of “dough”—the heart of every great pizza—and “dominance”, symbolizing the team’s ambition to lead in flavor, fun, and innovation. What started as a simple class project soon grew into a full-fledged concept for a smart, user-friendly pizza ordering app designed to make every slice count.

From its vibrant design and customizable pizza builder to its efficient order tracking system, Doughminant delivers more than just food—it delivers an experience. Each feature was built with the customer in mind, ensuring that ordering pizza is fast, interactive, and enjoyable.

Today, Doughminant continues to rise like the perfect crust—driven by innovation, teamwork, and a shared mission to bring people together through technology and taste.''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.48,
          maxChildSize: 0.95,
          builder: (context, controller) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.14)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(children: [
                // draggable handle
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  // Constrain the left side so the right action icons don't push content off-screen
                  Expanded(
                    child: Row(children: [
                      // company logo (use bundled asset if available)
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset('assets/app_icon.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Allow the text block to wrap / shrink when horizontal space is tight
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Company History', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), softWrap: true),
                          const SizedBox(height: 2),
                          Text('Founded 2025 · Dough & Innovation', style: Theme.of(context).textTheme.bodySmall, softWrap: true),
                        ]),
                      ),
                    ]),
                  ),
                  // action icons kept to the right with fixed intrinsic size
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () async {
                        await Clipboard.setData(const ClipboardData(text: companyText));
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company history copied to clipboard')));
                      },
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Copy',
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () async {
                        // placeholder: Save as PDF functionality could be added here
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Save as PDF coming soon')));
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      tooltip: 'Save as PDF',
                    ),
                    IconButton(
                      padding: const EdgeInsets.all(8),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ]),
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // highlight card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [Theme.of(context).colorScheme.primary.withOpacity(0.12), Theme.of(context).colorScheme.secondary.withOpacity(0.06)]),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
                        ),
                        child: Row(children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.local_pizza, color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('A story of flavor, design, and community — built for people who love pizza and polished apps.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 12),
                      // main content
                      Text(companyText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
                      const SizedBox(height: 16),
                      // feature chips / cards
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        _FeatureChip(icon: Icons.brush, title: 'Vibrant Design'),
                        _FeatureChip(icon: Icons.local_pizza, title: 'Custom Pizza Builder'),
                        _FeatureChip(icon: Icons.track_changes, title: 'Order Tracking'),
                        _FeatureChip(icon: Icons.people, title: 'Community Focus'),
                      ]),
                      const SizedBox(height: 18),
                      // action row
                      Row(children: [
                        Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.check), label: const Text('Close'))),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(onPressed: () async {
                          await Clipboard.setData(const ClipboardData(text: companyText));
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Company history copied')));
                        }, icon: const Icon(Icons.share), label: const Text('Share')),
                      ])
                    ]),
                  ),
                ),
                // pinned action row (outside of scrollable content)
                const SizedBox(height: 12),
                Padding(
                  padding: EdgeInsets.only(bottom: 12 + MediaQuery.of(context).viewPadding.bottom),
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.check), label: const Text('Close'))),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(onPressed: () {
                      // prefer to navigate via onSelectPage if provided so HomePage can show the full menu
                      if (widget.onSelectPage != null) {
                        widget.onSelectPage!(1);
                        Navigator.of(ctx).pop();
                      } else {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Open Menu (coming)')));
                      }
                    }, icon: const Icon(Icons.storefront), label: const Text('View Menu')),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  void _showAboutProducts() {
    const aboutText = '''🍕 About Our Products – Doughminant

At Doughminant, we don’t just make pizza—we craft experiences that bring people together. Every product we offer is made with passion, fresh ingredients, and a love for flavor that stands out. Our menu is designed to satisfy every craving, whether you’re enjoying a solo meal or sharing with friends and family.

1. Signature Pizzas

Our Signature Pizzas are the pride of Doughminant. Each one is baked to perfection using freshly made dough, premium cheese, and flavorful toppings. From the Pepperoni Overload to the Cheesy Supreme, every bite delivers a bold and unforgettable taste.

2. Specialty Crusts

Because every pizza starts with great dough, we offer a variety of crusts to suit every preference. Try our Classic Hand-Tossed, Thin & Crispy, or Cheesy-Stuffed Crust—each one baked golden brown to perfection and loaded with flavor.

3. Doughminant Combos

Get more out of your meal with our Doughminant Combos! Pair your favorite pizza with sides like garlic bread, crispy wings, and a refreshing drink. Perfect for parties, family dinners, or a well-deserved treat for yourself.

4. Desserts & Beverages

Satisfy your sweet tooth with our dessert pizzas and baked treats. From chocolate-drizzled dough bites to creamy beverages, our desserts are the perfect way to finish your Doughminant experience.

5. Limited-Edition Flavors

We love keeping things exciting! Our Limited-Edition Flavors feature unique recipes inspired by local favorites and seasonal themes. These exclusive creations are available for a limited time—so grab them before they’re gone!''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.48,
          maxChildSize: 0.95,
          builder: (context, controller) {
            // local state for staggered animations
            final visible = List<bool>.filled(4, false);
            var _started = false;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                // adapt gradient more aggressively to light/dark theme
                color: Theme.of(context).scaffoldBackgroundColor,
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? LinearGradient(colors: [Colors.grey[900]!, Colors.grey[850]!])
                    : LinearGradient(colors: [Colors.white, Colors.grey[50]!]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.14)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 24, offset: const Offset(0, -6)),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
              child: Column(children: [
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(
                    child: Row(children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.asset('assets/app_icon.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink()),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('About Our Products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800), softWrap: true),
                        const SizedBox(height: 4),
                        Text('Delicious. Fresh. Creative.', style: Theme.of(context).textTheme.bodySmall, softWrap: true),
                        const SizedBox(height: 8),
                        // quick action to open the full Menu — prefers onSelectPage callback when available
                        Row(children: [
                          ElevatedButton.icon(
                            onPressed: () {
                              if (widget.onSelectPage != null) {
                                widget.onSelectPage!(1);
                                Navigator.of(ctx).pop();
                              } else {
                                Navigator.of(ctx).pop();
                              }
                            },
                            icon: const Icon(Icons.storefront),
                            label: const Text('Open Menu'),
                            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                          ),
                        ]),
                      ])),
                    ]),
                  ),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () async { await Clipboard.setData(const ClipboardData(text: aboutText)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('About text copied'))); }, icon: const Icon(Icons.copy_outlined), tooltip: 'Copy'),
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () async {
                      // share via share sheet
                      await Share.share(aboutText, subject: 'About Doughminant');
                    }, icon: const Icon(Icons.share_outlined), tooltip: 'Share'),
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () async {
                      // generate PDF and open platform share/save
                      try {
                        final doc = pw.Document();
                        doc.addPage(pw.MultiPage(build: (pw.Context pwContext) {
                          return [
                            pw.Header(level: 0, child: pw.Text('About Our Products – Doughminant')),
                            pw.Paragraph(text: aboutText),
                          ];
                        }));
                        final bytes = await doc.save();
                        await Printing.sharePdf(bytes: bytes, filename: 'doughminant_about_products.pdf');
                      } catch (e) {
                        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to export PDF')));
                      }
                    }, icon: const Icon(Icons.picture_as_pdf_outlined), tooltip: 'Save as PDF'),
                    IconButton(padding: const EdgeInsets.all(8), constraints: const BoxConstraints(minWidth: 36, minHeight: 36), onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close), tooltip: 'Close'),
                  ])
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    // add bottom padding so the last row of actions doesn't overflow
                    // when the sheet is tightly constrained by the draggable parent
                    child: Padding(
                      // leave a bit more bottom padding so the final action row never clips
                      padding: EdgeInsets.only(bottom: 48 + MediaQuery.of(context).viewPadding.bottom),
                      child: StatefulBuilder(builder: (context, setStateSB) {
                      if (!_started) {
                        _started = true;
                        for (var i = 0; i < visible.length; i++) {
                          Future.delayed(Duration(milliseconds: 90 * i), () {
                            setStateSB(() => visible[i] = true);
                          });
                        }
                      }

                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        // feature grid with staggered entrance
                        GridView.count(
                          shrinkWrap: true,
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 3.2,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [
                            for (var i = 0; i < 4; i++)
                              AnimatedOpacity(
                                duration: const Duration(milliseconds: 360),
                                opacity: visible[i] ? 1 : 0,
                                child: Transform.translate(offset: Offset(0, visible[i] ? 0 : 8), child: [
                                  _FeatureCard(icon: Icons.local_pizza, title: 'Signature Pizzas', subtitle: 'Bold, crafted flavors'),
                                  _FeatureCard(icon: Icons.layers, title: 'Specialty Crusts', subtitle: 'Hand-tossed to stuffed'),
                                  _FeatureCard(icon: Icons.local_fire_department, title: 'Limited Flavors', subtitle: 'Seasonal & exciting'),
                                  _FeatureCard(icon: Icons.local_drink, title: 'Desserts & Drinks', subtitle: 'Sweet finishes'),
                                ][i]),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(aboutText, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45)),
                        const SizedBox(height: 16),
                        Wrap(spacing: 8, runSpacing: 8, children: [
                          _FeatureChip(icon: Icons.menu_book, title: 'Signature Pizzas'),
                          _FeatureChip(icon: Icons.pie_chart, title: 'Specialty Crusts'),
                          _FeatureChip(icon: Icons.local_dining, title: 'Combos'),
                          _FeatureChip(icon: Icons.icecream, title: 'Desserts'),
                        ]),
                        const SizedBox(height: 18),
                        // NOTE: action row moved out of the scrollable area to avoid clipping on
                        // small sheet sizes. The pinned actions are rendered after the Expanded
                        // scroll area below.
                      ],
                      );
                    }),
                    ),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  void _onItemTap(int index) {
    final title = _items[index]['title'] as String;
    Navigator.of(context).pop();
    switch (title) {
      case 'Orders & Tracking':
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => const OrderTrackingPage()));
        break;
      case 'Profile':
        if (widget.onSelectPage != null) {
          widget.onSelectPage!(3);
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfilePage()));
        }
        break;
      case 'Cart':
        if (widget.onSelectPage != null) {
          widget.onSelectPage!(2);
        } else {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartPage()));
        }
        break;
      case 'Company History':
        _showCompanyHistory();
        break;
      case 'About our Products':
        _showAboutProducts();
        break;
      case 'About the App':
        _showAboutApp();
        break;
      case 'Developers':
        _showDevelopers();
        break;
      case 'Contact Us':
        _showContactUs();
        break;
      default:
        break;
    }
  }

  void _showDevelopers() {
    final devs = [
      {
        'name': 'Erin Denzelle Picardal',
        'role': 'Lead Programmer / Backend Developer',
        'bio': 'Leads the development and develops and maintains the server-side functions, ensuring secure data flow between users and the system. Focuses on stability, performance, and reliability.',
        'asset': 'assets/erin.png'
      },
      {
        'name': 'Jimuel P. Quevedo',
        'role': 'Frontend Developer',
        'bio': 'Handles the visual components and responsiveness of the app. Brings the design to life through interactive pages and seamless navigation.',
        'asset': 'assets/jimuel.png'
      },
      {
        'name': 'Lord Ivan Johannes B. Bautista',
        'role': 'UI-UX Designer',
        'bio': 'Designs the app’s user interface, ensuring a smooth and enjoyable customer experience. Oversees team coordination and project progress.',
        'asset': 'assets/ivan.png'
      },
      {
        'name': 'Noah Joseph Narvaez',
        'role': 'Database Manager',
        'bio': 'Designs and manages the database structure for customer information, orders, and product inventory. Ensures data accuracy and efficient storage.',
        'asset': 'assets/noah.png'
      },
      {
        'name': 'Abdul Rahman Noor',
        'role': 'Quality Assurance & Security Lead',
        'bio': 'Conducts app testing, identifies bugs, and implements fixes. Ensures app security, performance, and reliability before deployment.',
        'asset': 'assets/abdul.png'
      },
    ];

    // Precache developer images so the modal shows them without a visible delay
    // (safe no-op if the asset files are missing; they'll fallback to initials).
    for (final d in devs) {
      try {
        precacheImage(AssetImage(d['asset'] as String), context);
      } catch (_) {}
    }

    final teamText = StringBuffer();
    teamText.writeln('Developers Credits – Team Doughminant\n');
    for (final d in devs) {
      teamText.writeln('${d['name']} — ${d['role']}');
      teamText.writeln('${d['bio']}\n');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.66,
          minChildSize: 0.44,
          maxChildSize: 0.95,
          builder: (context, controller) {
            final vis = List<bool>.filled(devs.length, false);
            var started = false;

            String initials(String name) {
              final parts = name.split(' ');
              if (parts.isEmpty) return '';
              final first = parts.first.isNotEmpty ? parts.first[0] : '';
              final last = parts.length > 1 && parts.last.isNotEmpty ? parts.last[0] : '';
              return (first + last).toUpperCase();
            }

            return AnimatedContainer(
              duration: const Duration(milliseconds: 420),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, -6))],
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Column(children: [
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/app_icon.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink())),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Developers', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('Meet the team behind Doughminant', style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: teamText.toString())); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team credits copied'))); }, icon: const Icon(Icons.copy_outlined)),
                    IconButton(onPressed: () async { await Share.share(teamText.toString(), subject: 'Team Doughminant'); }, icon: const Icon(Icons.share_outlined)),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                  ])
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: StatefulBuilder(builder: (context, setStateSB) {
                      if (!started) {
                        started = true;
                        for (var i = 0; i < vis.length; i++) {
                          Future.delayed(Duration(milliseconds: 80 * i), () => setStateSB(() => vis[i] = true));
                        }
                      }

                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const SizedBox(height: 6),
                        for (var i = 0; i < devs.length; i++)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 360),
                            opacity: vis[i] ? 1 : 0,
                            child: Transform.translate(
                              offset: Offset(0, vis[i] ? 0 : 8),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.04)),
                                ),
                                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  // avatar (asset if present, fallback to initials)
                                  Container(
                                    width: 64,
                                    height: 64,
                                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.asset(
                                        devs[i]['asset'] as String,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => Container(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                                          child: Center(child: Text(initials(devs[i]['name'] as String), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900))),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(devs[i]['name'] as String, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                                    const SizedBox(height: 2),
                                    Text(devs[i]['role'] as String, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                                    const SizedBox(height: 8),
                                    Text(devs[i]['bio'] as String, style: Theme.of(context).textTheme.bodyMedium),
                                  ])),
                                  const SizedBox(width: 8),
                                  Column(mainAxisSize: MainAxisSize.min, children: [
                                    IconButton(onPressed: () async { await Clipboard.setData(ClipboardData(text: '${devs[i]['name']} — ${devs[i]['role']}\n${devs[i]['bio']}')); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Developer copied'))); }, icon: const Icon(Icons.copy)),
                                    IconButton(onPressed: () async { await Share.share('${devs[i]['name']} — ${devs[i]['role']}\n${devs[i]['bio']}', subject: 'Meet the developer'); }, icon: const Icon(Icons.share)),
                                  ])
                                ]),
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text('Team Motto', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 6),
                        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(12)), child: Text('“We don’t just make pizza — we make technology taste better!” 🍕💛', style: Theme.of(context).textTheme.bodyMedium)),
                        const SizedBox(height: 12),
                      ]);
                    }),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 12 + MediaQuery.of(context).viewPadding.bottom),
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close), label: const Text('Close'))),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(onPressed: () async { await Clipboard.setData(ClipboardData(text: teamText.toString())); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Team credits copied'))); }, icon: const Icon(Icons.copy), label: const Text('Copy All')),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(onPressed: () async { await Share.share(teamText.toString(), subject: 'Team Doughminant'); }, icon: const Icon(Icons.share), label: const Text('Share Team')),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      child: SafeArea(
        child: FadeTransition(
          opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(-0.04, 0), end: Offset.zero).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [theme.colorScheme.primary.withOpacity(0.14), theme.colorScheme.primary.withOpacity(0.06)]),
                ),
                child: Row(children: [
                  GestureDetector(
                    onTap: () async {
                      // allow user to pick avatar from drawer
                      await _pickAvatar();
                    },
                    child: Hero(
                      tag: 'drawer-avatar',
                      child: ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.02).animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeInOut))),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.orange[50],
                          child: ClipOval(
                              child: SizedBox(
                              width: 64,
                              height: 64,
                              child: _avatarPath != null
                                  ? Image.file(File(_avatarPath!), fit: BoxFit.cover)
                                  : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                      ? Image.network(_avatarUrl!, fit: BoxFit.cover, errorBuilder: (c, e, s) => Image.asset('assets/app_icon.png', fit: BoxFit.contain))
                                      : Image.asset('assets/app_icon.png', fit: BoxFit.contain)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(_email, style: theme.textTheme.bodySmall),
                      const SizedBox(height: 2),
                      Text(_phone, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
                    ]),
                  ),
                  // notification bell
                  _notificationBell(),
                ]),
              ),
              const SizedBox(height: 12),

              // animated menu items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  itemCount: _items.length,
                  itemBuilder: (context, i) {
                    final it = _items[i];
                    final icon = it['icon'] as IconData;
                    final title = it['title'] as String;
                    // staggered interval
                    final start = (i * 0.07).clamp(0.0, 0.9);
                    final end = (start + 0.45).clamp(0.0, 1.0);

                    return AnimatedBuilder(
                      animation: _ctrl,
                      builder: (context, child) {
                        final t = _ctrl.value;
                        double progress;
                        if (t <= start)
                          progress = 0.0;
                        else if (t >= end)
                          progress = 1.0;
                        else
                          progress = (t - start) / (end - start);

                        final offsetY = (1 - Curves.easeOut.transform(progress)) * 12;
                        final opacity = Curves.easeOut.transform(progress);
                        return Opacity(
                          opacity: opacity,
                          child: Transform.translate(
                            offset: Offset(0, offsetY),
                            child: child,
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () => _onItemTap(i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.white.withAlpha((0.98 * 255).round())),
                              child: Row(children: [
                                Container(
                                  height: 42,
                                  width: 42,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
                                  child: Icon(icon, color: Theme.of(context).colorScheme.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                const Icon(Icons.chevron_right),
                              ]),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Version 1.0.0', style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
                  Row(children: [
                    TextButton(onPressed: () => _showSheet('Legal', 'Privacy & Terms placeholder.'), child: const Text('Legal')),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Log out'),
                            content: const Text('Do you want to log out?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                              ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Log out')),
                            ],
                          ),
                        );
                        if (confirm != true) return;
                        try {
                          final auth = FirebaseAuthService();
                          await auth.signOut();
                        } catch (e) {}
                        if (!mounted) return;
                        // close drawer then navigate to LoginPage clearing stack
                        Navigator.of(context).pop();
                        Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
                      },
                      child: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
                    ),
                  ]),
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  void _showContactUs() {
    const contactText = '''📞 Contact Us – Doughminant

We’d love to hear from you! Whether you have a question, feedback, or just want to share your Doughminant experience, our team is always ready to help.

Get in Touch

📍 Office Address:
Doughminant Headquarters
123 Pizza Street, Quezon City, Philippines

📧 Email:
support@doughminant.com

📞 Phone:
(+63) 912 345 6789

🌐 Website:
https://www.doughminant.com

Follow Us

📘 Facebook: https://facebook.com/DoughminantPH
📸 Instagram: https://instagram.com/doughminant.ph
🐦 X (Twitter): https://twitter.com/doughminant

At Doughminant, your satisfaction is our top priority. Reach out anytime—we’re here to make sure your pizza experience is always dominant in taste, quality, and service! 🍕💛
''';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.52,
          minChildSize: 0.36,
          maxChildSize: 0.92,
          builder: (context, controller) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                gradient: Theme.of(context).brightness == Brightness.dark
                    ? LinearGradient(colors: [Colors.grey[900]!, Colors.grey[800]!])
                    : LinearGradient(colors: [Colors.white, Colors.grey[50]!]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.08)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 18, offset: const Offset(0, -6))],
              ),
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Column(children: [
                Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/app_icon.png', fit: BoxFit.cover, errorBuilder: (c, e, s) => const SizedBox.shrink())),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Contact Us', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text('We’re here to help — reach out anytime', style: Theme.of(context).textTheme.bodySmall),
                  ])),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(onPressed: () async { await Clipboard.setData(const ClipboardData(text: contactText)); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact details copied'))); }, icon: const Icon(Icons.copy_outlined)),
                    IconButton(onPressed: () async { await Share.share(contactText, subject: 'Contact Doughminant'); }, icon: const Icon(Icons.share_outlined)),
                    IconButton(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close)),
                  ])
                ]),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    controller: controller,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Theme.of(context).cardColor, border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.04))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Office Address', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text('Doughminant Headquarters', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('123 Pizza Street, Quezon City, Philippines', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 12),
                          Row(children: [
                            ElevatedButton.icon(onPressed: () async {
                              final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=123+Pizza+Street+Quezon+City');
                              if (!await launchUrl(uri)) {
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open maps')));
                              }
                            }, icon: const Icon(Icons.map), label: const Text('Open in Maps')),
                            const SizedBox(width: 8),
                            OutlinedButton.icon(onPressed: () async { await Clipboard.setData(const ClipboardData(text: '123 Pizza Street, Quezon City, Philippines')); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Address copied'))); }, icon: const Icon(Icons.copy), label: const Text('Copy')),
                          ])
                        ]),
                      ),
                      const SizedBox(height: 12),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.email_outlined),
                        title: const Text('support@doughminant.com'),
                        subtitle: const Text('Email us for support'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(onPressed: () async { await Clipboard.setData(const ClipboardData(text: 'support@doughminant.com')); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email copied'))); }, icon: const Icon(Icons.copy)),
                          IconButton(onPressed: () async { final uri = Uri(scheme: 'mailto', path: 'support@doughminant.com', queryParameters: {'subject': 'App Support'}); if (!await launchUrl(uri)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email client'))); } }, icon: const Icon(Icons.send)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.phone_outlined),
                        title: const Text('(+63) 912 345 6789'),
                        subtitle: const Text('Call or message us'),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(onPressed: () async { await Clipboard.setData(const ClipboardData(text: '+639123456789')); if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied'))); }, icon: const Icon(Icons.copy)),
                          IconButton(onPressed: () async { final uri = Uri(scheme: 'tel', path: '+639123456789'); if (!await launchUrl(uri)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not make a call'))); } }, icon: const Icon(Icons.call)),
                        ]),
                      ),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.public),
                        title: const Text('www.doughminant.com'),
                        subtitle: const Text('Visit our website'),
                        trailing: IconButton(onPressed: () async { final uri = Uri.parse('https://www.doughminant.com'); if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open website'))); } }, icon: const Icon(Icons.open_in_new)),
                      ),
                      const SizedBox(height: 12),
                      Text('Follow Us', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 8),
                      Row(children: [
                        IconButton(onPressed: () async { final uri = Uri.parse('https://facebook.com/DoughminantPH'); if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Facebook'))); } }, icon: const Icon(Icons.facebook, color: Color(0xFF1877F2))),
                        IconButton(onPressed: () async { final uri = Uri.parse('https://instagram.com/doughminant.ph'); if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Instagram'))); } }, icon: const Icon(Icons.camera_alt, color: Color(0xFFE4405F))),
                        IconButton(onPressed: () async { final uri = Uri.parse('https://twitter.com/doughminant'); if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open X'))); } }, icon: const Icon(Icons.alternate_email, color: Color(0xFF1DA1F2))),
                        const SizedBox(width: 6),
                        Expanded(child: Text('Follow us for promos, updates, and limited flavors!', style: Theme.of(context).textTheme.bodySmall)),
                      ]),
                      const SizedBox(height: 18),
                    ]),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 12 + MediaQuery.of(context).viewPadding.bottom),
                  child: Row(children: [
                    Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.of(ctx).pop(), icon: const Icon(Icons.close), label: const Text('Close'))),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(onPressed: () async { await Share.share('Contact Doughminant:\nsupport@doughminant.com\n(+63) 912 345 6789\nhttps://www.doughminant.com'); }, icon: const Icon(Icons.send), label: const Text('Share Contact')),
                  ]),
                ),
              ]),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }
}

// Small feature chip used in the Company History modal
class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureChip({Key? key, required this.icon, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 8), Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700))]),
    );
  }
}

// Small feature card used in About Our Products
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureCard({Key? key, required this.icon, required this.title, required this.subtitle}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.06)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Row(children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary.withOpacity(0.10), borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Theme.of(context).colorScheme.primary)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // use a slightly smaller body style so the card fits better in tight grid cells
              Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis, maxLines: 1),
              const SizedBox(height: 2),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ]),
    );
  }
}
