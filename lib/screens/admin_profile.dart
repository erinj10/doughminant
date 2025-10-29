import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_page.dart';

/// AdminProfilePage
/// Simple profile editor for admin accounts. Shows avatar (from URL), fullname,
/// phone and address fields. Saves to Firestore under `users/{uid}` and
/// provides a Logout button.

class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({Key? key}) : super(key: key);

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final _fullNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _avatarCtrl = TextEditingController();
  bool _loading = false;

  User? get _user => FirebaseAuth.instance.currentUser;
  DocumentReference<Map<String, dynamic>>? get _userDoc => _user == null
      ? null
      : FirebaseFirestore.instance.collection('users').doc(_user!.uid);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final doc = _userDoc;
    if (doc == null) return;
    try {
      final snap = await doc.get();
      final data = snap.data();
      if (data != null) {
        _fullNameCtrl.text = (data['fullname'] ?? '') as String;
        _phoneCtrl.text = (data['phone'] ?? '') as String;
        _addressCtrl.text = (data['address'] ?? '') as String;
        _avatarCtrl.text = (data['avatarUrl'] ?? '') as String;
      }
    } catch (e) {
      // ignore - we'll show when saving
    }
  }

  Future<void> _saveProfile() async {
    final doc = _userDoc;
    if (doc == null) return;
    setState(() => _loading = true);
    try {
      await doc.set({
        'fullname': _fullNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'avatarUrl': _avatarCtrl.text.trim(),
        'email': _user?.email,
      }, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    // Navigate back to LoginPage and clear stack
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginPage()), (route) => false);
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _avatarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _avatarCtrl.text.trim();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Logout',
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 16),
              CircleAvatar(
                radius: 48,
                backgroundColor: Colors.grey.shade200,
                child: ClipOval(
                  child: SizedBox(
                    height: 96,
                    width: 96,
                    child: avatarUrl.isEmpty
                        ? Center(child: Text(_user?.email?.substring(0, 1).toUpperCase() ?? 'A', style: const TextStyle(fontSize: 28)))
                        : Image.network(avatarUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Center(child: Text(_user?.email?.substring(0, 1).toUpperCase() ?? 'A'))),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(_user?.email ?? 'Unknown', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 18),

              // Avatar URL
              TextField(
                controller: _avatarCtrl,
                decoration: const InputDecoration(labelText: 'Avatar image URL (optional)', hintText: 'https://...'),
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              TextField(controller: _fullNameCtrl, decoration: const InputDecoration(labelText: 'Full name')),
              const SizedBox(height: 12),
              TextField(controller: _phoneCtrl, decoration: const InputDecoration(labelText: 'Phone')),
              const SizedBox(height: 12),
              TextField(controller: _addressCtrl, decoration: const InputDecoration(labelText: 'Address')),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _loading ? null : _saveProfile,
                      child: _loading ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save profile'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton(
                    onPressed: _logout,
                    child: const Text('Logout'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text('Tip: provide an accessible image URL for your avatar. You can also leave it blank.'),
            ],
          ),
        ),
      ),
    );
  }
}
