import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firebase_auth_service.dart';
import 'login_page.dart';

/// Notification sent by pages that want the parent to navigate back to the
/// home/main page (page index 0 by default).
class BackToHomeNotification extends Notification {
  final int page;
  BackToHomeNotification([this.page = 0]);
}

class ProfilePage extends StatefulWidget {
  /// Optional callback invoked when the user taps the back button in the
  /// profile header. If null, the page will fall back to dispatching
  /// `BackToHomeNotification` so older wiring still works.
  final VoidCallback? onBack;

  const ProfilePage({Key? key, this.onBack}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with TickerProviderStateMixin {
  String _name = 'Jane Doe';
  String _email = 'janedoe@email.com';
  bool _notifications = true;
  final List<String> _addresses = ['742 Evergreen Terrace, Springfield'];
  final List<String> _payments = ['Visa •••• 4242'];
  final List<Map<String, String>> _orders = [
    {'title': 'Pepperoni Classic', 'date': 'Oct 18, 2025', 'price': '₱10.00'},
    {'title': 'Margherita', 'date': 'Sep 29, 2025', 'price': '₱8.00'},
  ];

  late final AnimationController _avatarPulse;
  late final AnimationController _listEntranceController;
  String? _avatarPath;
  String? _avatarUrl;
  String _phone = '+63 912 345 6789';
  final ImagePicker _picker = ImagePicker();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  @override
  void initState() {
    super.initState();
    _avatarPulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _listEntranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _loadAvatar();
    // Immediately populate fields from the authenticated user so the UI
    // reflects the signed-in account even before a backend Firestore
    // document snapshot arrives (or if Firestore write is delayed/blocked).
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && mounted) {
        setState(() {
          if (user.displayName != null && user.displayName!.isNotEmpty) _name = user.displayName!;
          if (user.email != null && user.email!.isNotEmpty) _email = user.email!;
          if (user.phoneNumber != null && user.phoneNumber!.isNotEmpty) _phone = user.phoneNumber!;
        });
      }
    } catch (e) {
      // non-fatal, but log so we can debug in app logs if needed
      // ignore: avoid_print
      print('ProfilePage: failed to read FirebaseAuth.currentUser: $e');
    }
    _subscribeProfileChanges();
    // small staggered entrance
    _listEntranceController.forward();
  }

  void _subscribeProfileChanges() {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      _profileSub = FirebaseFirestore.instance.collection('users').doc(uid).snapshots().listen((snap) {
        if (snap.exists && mounted) {
          final data = snap.data() ?? <String, dynamic>{};
          setState(() {
            final fullname = (data['fullname'] ?? '') as String;
            final phone = (data['phone'] ?? '') as String;
            final avatar = data['avatarUrl'] as String?;
            if (fullname.isNotEmpty) _name = fullname;
            if (phone.isNotEmpty) _phone = phone;
            if (avatar != null && avatar.isNotEmpty) _avatarUrl = avatar;
          });
        }
      }, onError: (err) {
        // Log subscription errors so they can be diagnosed from app logs.
        // ignore: avoid_print
        print('ProfilePage: Firestore profile subscription error: $err');
      });
    } catch (_) {}
  }

  /// Wrap a widget with a small staggered slide+fade entrance using [_listEntranceController].
  Widget _staggered(Widget child, int index) {
    final start = (index * 0.08).clamp(0.0, 0.8);
    final end = (start + 0.38).clamp(0.0, 1.0);
    return AnimatedBuilder(
      animation: _listEntranceController,
      builder: (context, _) {
        final t = _listEntranceController.value;
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
          child: Transform.translate(offset: Offset(0, offsetY), child: child),
        );
      },
    );
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    _avatarPulse.dispose();
    _listEntranceController.dispose();
    super.dispose();
  }

  Future<void> _loadAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final path = prefs.getString('profile_avatar_path');
      if (path != null && mounted) {
        setState(() => _avatarPath = path);
      }
    } catch (_) {}
  }

  Future<void> _pickAvatar() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final dir = await getApplicationDocumentsDirectory();
      final file = File(
        '${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('profile_avatar_path', file.path);
      if (!mounted) return;
      setState(() => _avatarPath = file.path);
    } catch (e) {
      // ignore or show a small snackbar
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to pick avatar')));
    }
  }

  Future<void> _removeAvatar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_avatarPath != null) {
        final f = File(_avatarPath!);
        if (await f.exists()) await f.delete();
      }
      await prefs.remove('profile_avatar_path');
      if (mounted) setState(() => _avatarPath = null);
    } catch (_) {}
  }

  Future<void> _editProfile() async {
    final nameCtrl = TextEditingController(text: _name);
    final emailCtrl = TextEditingController(text: _email);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            TextField(
              controller: emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _name = nameCtrl.text.trim().isEmpty
                    ? _name
                    : nameCtrl.text.trim();
                _email = emailCtrl.text.trim().isEmpty
                    ? _email
                    : emailCtrl.text.trim();
              });
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addAddress() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Address'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Address'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) {
                setState(() => _addresses.insert(0, val));
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _addPayment() async {
    final ctrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Payment Method'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Card (e.g. Visa •••• 4242)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = ctrl.text.trim();
              if (val.isNotEmpty) setState(() => _payments.insert(0, val));
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(Map<String, String> order) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              order['title'] ?? '',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(order['date'] ?? ''),
            const SizedBox(height: 8),
            Text(
              'Total: ${order['price'] ?? ''}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Keep the top safe area but allow painting into the bottom inset so
    // the translucent bottom navigation (in the parent Scaffold with
    // `extendBody: true`) can blur this gradient instead of sampling the
    // platform background (which appears black).
    return SafeArea(
      top: true,
      bottom: false,
      child: Container(
        // ensure this background fills the full viewport so the translucent
        // bottom nav blurs this gradient instead of the platform black.
        height: MediaQuery.of(context).size.height,
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical,
        ),
        // soft warm gradient background for the profile page
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF8F3), // very light cream
              Color(0xFFFFEDE4), // soft peach
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back-to-top arrow and Header with avatar and edit
              // Arrow button placed before the header to allow jumping back to Home
              Padding(
                padding: const EdgeInsets.only(bottom: 6.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () {
                        // If parent provided a callback, use it; otherwise fall back
                        // to the Notification mechanism for backwards compatibility.
                        if (widget.onBack != null) {
                          widget.onBack!();
                        } else {
                          BackToHomeNotification().dispatch(context);
                        }
                      },
                      // left/back arrow — placed on the left of the header
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                    ),
                  ),
              ),

              Row(
                children: [
                  ScaleTransition(
                    scale: Tween(begin: 0.96, end: 1.04).animate(
                      CurvedAnimation(
                        parent: _avatarPulse,
                        curve: Curves.easeInOut,
                      ),
                    ),
                    child: GestureDetector(
                      onTap: () async => await _pickAvatar(),
                      child: Hero(
                        tag: 'profile-avatar',
                        child: CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.orange[100],
                          child: ClipOval(
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: _avatarPath != null
                                  ? Image.file(
                                      File(_avatarPath!),
                                      fit: BoxFit.cover,
                                    )
                                  : (_avatarUrl != null
                                      ? Image.network(
                                          _avatarUrl!,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.asset(
                                          'assets/app_icon.png',
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.contain,
                                        )),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _name,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(_email, style: theme.textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text(_phone, style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54)),
                        const SizedBox(height: 8),
                        // Use a Wrap so action buttons can wrap to the next line
                        // instead of causing a horizontal overflow on narrow screens.
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _editProfile,
                              label: const Text('Edit Profile'),
                              icon: const Icon(Icons.edit),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _showShareProfile(),
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                            ),
                            if (_avatarPath != null)
                              OutlinedButton.icon(
                                onPressed: _removeAvatar,
                                icon: const Icon(Icons.delete),
                                label: const Text('Remove Avatar'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Cards
              Text(
                'User Profile',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              _staggered(
                _buildListCard(
                  icon: Icons.history,
                  title: 'Order History',
                  subtitle: '${_orders.length} past orders',
                  onTap: () => _openOrderHistory(),
                ),
                0,
              ),
              const SizedBox(height: 8),
              _staggered(
                _buildListCard(
                  icon: Icons.location_on,
                  title: 'Saved Addresses',
                  subtitle: '${_addresses.length} saved',
                  onTap: () => _openAddresses(),
                ),
                1,
              ),
              const SizedBox(height: 8),
              _staggered(
                _buildListCard(
                  icon: Icons.credit_card,
                  title: 'Payment Methods',
                  subtitle: '${_payments.length} cards',
                  onTap: () => _openPayments(),
                ),
                2,
              ),
              const SizedBox(height: 8),
              _staggered(
                _buildListCard(
                  icon: Icons.notifications,
                  title: 'Notifications',
                  subtitle: _notifications ? 'Enabled' : 'Disabled',
                  onTap: () => _toggleNotifications(),
                ),
                3,
              ),
              const SizedBox(height: 8),
              _staggered(
                _buildListCard(
                  icon: Icons.settings,
                  title: 'Settings',
                  subtitle: 'App settings and preferences',
                  onTap: () => _openSettings(),
                ),
                4,
              ),
              const SizedBox(height: 18),

              // Small quick actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addAddress,
                      icon: const Icon(Icons.add_location),
                      label: const Text('Add Address'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _addPayment,
                      icon: const Icon(Icons.add_card),
                      label: const Text('Add Card'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Logout action placed below quick actions for clearer discoverability
              Center(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Log out'),
                        content: const Text('Are you sure you want to log out?'),
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
                    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
                  },
                  icon: const Icon(Icons.logout, color: Colors.redAccent),
                  label: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListCard({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    return _HoverCard(
      icon: icon,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
    );
  }

  void _openOrderHistory() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                IconButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._orders
                .map(
                  (o) => ListTile(
                    title: Text(o['title'] ?? ''),
                    subtitle: Text(o['date'] ?? ''),
                    trailing: Text(o['price'] ?? ''),
                    onTap: () => _showOrderDetails(o),
                  ),
                )
                .toList(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _openAddresses() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Saved Addresses',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_addresses.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No addresses yet'),
                  ),
                ..._addresses.map((a) {
                  return Dismissible(
                    key: ValueKey(a),
                    background: Container(
                      color: Colors.redAccent,
                      padding: const EdgeInsets.all(8),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                    ),
                    onDismissed: (_) {
                      // remove by value to avoid index mismatch during rebuilds
                      setState(() => _addresses.remove(a));
                      setSt(() {});
                    },
                    child: ListTile(title: Text(a)),
                  );
                }).toList(),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _addAddress();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Address'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openPayments() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Payment Methods',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_payments.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Text('No payment methods yet'),
                  ),
                ..._payments.map((p) {
                  return Dismissible(
                    key: ValueKey(p),
                    background: Container(
                      color: Colors.redAccent,
                      padding: const EdgeInsets.all(8),
                      child: const Align(
                        alignment: Alignment.centerRight,
                        child: Icon(Icons.delete, color: Colors.white),
                      ),
                    ),
                    onDismissed: (_) {
                      // remove by value to avoid index mismatch during rebuilds
                      setState(() => _payments.remove(p));
                      setSt(() {});
                    },
                    child: ListTile(title: Text(p)),
                  );
                }).toList(),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    _addPayment();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Card'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _toggleNotifications() {
    setState(() => _notifications = !_notifications);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _notifications ? 'Notifications enabled' : 'Notifications disabled',
        ),
      ),
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              value: _notifications,
              onChanged: (v) => setState(() => _notifications = v),
              title: const Text('Push Notifications'),
            ),
            ListTile(
              title: const Text('Theme'),
              subtitle: const Text('Light (default)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showShareProfile() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Share $_name profile',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              const Text(
                'Share a link to your public profile or invite friends.',
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HoverCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _HoverCard({
    Key? key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
  }) : super(key: key);

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hover = false;

  void _setHover(bool v) {
    if (_hover == v) return;
    setState(() => _hover = v);
  }

  @override
  Widget build(BuildContext context) {
    final color = Colors.white;
    final shadow = _hover
        ? [
            BoxShadow(
              color: Colors.black.withAlpha(28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ]
        : [
            BoxShadow(
              color: Colors.black.withAlpha(12),
              blurRadius: 8,
              offset: const Offset(0, 6),
            ),
          ];

    return MouseRegion(
      onEnter: (_) => _setHover(true),
      onExit: (_) => _setHover(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..translate(0.0, _hover ? -6.0 : 0.0)
          ..scale(_hover ? 1.01 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: color,
          boxShadow: shadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: widget.onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.orange[50],
                    child: Icon(widget.icon, color: Colors.deepOrange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        if (widget.subtitle != null) const SizedBox(height: 6),
                        if (widget.subtitle != null)
                          Text(
                            widget.subtitle!,
                            style: const TextStyle(color: Colors.black54),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
