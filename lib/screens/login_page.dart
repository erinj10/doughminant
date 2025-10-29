import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_auth_service.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'home_page.dart';
import 'register_page.dart';
import 'admin_panel.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _showPassword = false;
  bool _rememberMe = false;
  bool _loading = false;
  String? _emailError;
  String? _passwordError;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;

  @override
  void initState() {
    super.initState();
  _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);
  _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
  _logoController.forward();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final remember = prefs.getBool('remember_me') ?? false;
    if (remember) {
      final savedEmail = prefs.getString('saved_email') ?? '';
      setState(() {
        _rememberMe = true;
        _emailController.text = savedEmail;
      });
    }
  }

  Future<void> _setRemember(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', remember);
    if (remember) {
      await prefs.setString('saved_email', _emailController.text);
    } else {
      await prefs.remove('saved_email');
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _emailController.dispose();
    _emailFocus.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _attemptLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Persist remember preference
    await _setRemember(_rememberMe);
    // Clear previous errors
    setState(() {
      _emailError = null;
      _passwordError = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // After successful login, fire-and-forget a profile sync so name/email/phone
      // are written to `users/{uid}` without blocking the navigation flow.
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          final svc = UserProfileService();
          final profile = UserProfile(
            uid: user.uid,
            fullname: user.displayName ?? (user.email != null ? user.email!.split('@').first : ''),
            email: user.email ?? '',
            phone: user.phoneNumber ?? '',
          );
          // do not await — keep login fast; save in background
          svc.saveProfile(profile).then((ok) {}).catchError((_) {});
        }
      } catch (e) {
        // non-fatal; continue
      }
      setState(() => _loading = false);
      if (!mounted) return;
      final user = FirebaseAuth.instance.currentUser;
      final email = user?.email?.toLowerCase();
      final isAdmin = email != null && kAdminEmails.map((e) => e.toLowerCase()).contains(email);
      if (isAdmin) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminPanelPage()));
      } else {
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      // If the user-not-found or wrong-password error occurs, set field-specific errors
      if (e.code == 'user-not-found') {
        setState(() {
          _emailError = 'No account found for this email.';
          _passwordError = null;
        });
        // Focus the email field so user can correct it
        if (mounted) {
          FocusScope.of(context).requestFocus(_emailFocus);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email not found')));
        }
        // Also show a dialog for emphasis
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Email not found'),
              content: const Text('There is no account registered with that email.'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            ),
          );
        }
        return;
      }
      if (e.code == 'wrong-password') {
        setState(() {
          _passwordError = 'Incorrect password.';
          _emailError = null;
        });
        if (mounted) {
          FocusScope.of(context).requestFocus(_passwordFocus);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Incorrect password')));
        }
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Incorrect password'),
              content: const Text('The password you entered is incorrect.'),
              actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
            ),
          );
        }
        return;
      }

      String message = '';
      if (e.code == 'invalid-email') {
        message = 'The email address is badly formatted.';
      } else {
        message = 'An unexpected error occurred: ${e.message}';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient + decorative circles
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
              ),
            ),
          ),
          Positioned(
            right: -size.width * 0.2,
            top: -size.width * 0.15,
            child: Opacity(
              opacity: 0.12,
              child: Container(
                width: size.width * 0.7,
                height: size.width * 0.7,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            left: -size.width * 0.3,
            bottom: -size.width * 0.25,
            child: Opacity(
              opacity: 0.08,
              child: Container(
                width: size.width * 0.9,
                height: size.width * 0.9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: _buildLogo(),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5B2A1A),
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildCard(),
                    const SizedBox(height: 12),
                    _buildSocialRow(),
                    const SizedBox(height: 14),
                    _buildSignupRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    // Circular white background with subtle shadow, larger logo
    return Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        // ensure the image itself is clipped to a circle
        child: ClipOval(
          child: SizedBox(
            width: 130,
            height: 130,
            child: Image.asset(
              'assets/app_icon.png',
              width: 130,
              height: 130,
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email
              TextFormField(
                controller: _emailController,
                focusNode: _emailFocus,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFB85A3B)),
                  hintText: 'Email',
                  filled: true,
                  fillColor: const Color(0xFFF8ECE5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  errorText: _emailError,
                  // show a red outline when there's an error to make it more visible
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.6)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2.0)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              // Password
              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                obscureText: !_showPassword,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFB85A3B)),
                  hintText: 'Password',
                  filled: true,
                  fillColor: const Color(0xFFF8ECE5),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  errorText: _passwordError,
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 1.6)),
                  focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.redAccent, width: 2.0)),
                  suffixIcon: IconButton(
                    icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey[700]),
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a password';
                  if (v.length < 4) return 'Password too short';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Checkbox(
                        value: _rememberMe,
                        activeColor: const Color(0xFFB85A3B),
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                      ),
                      const Text('Remember me', style: TextStyle(color: Color(0xFF6B3A2E))),
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      // TODO: implement forgot password flow
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Forgot password tapped')));
                    },
                    child: const Text('Forgot Password?', style: TextStyle(color: Color(0xFFB85A3B))),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Login button
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8C2E1A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _loading ? null : _attemptLogin,
          child: _loading
            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2))
            : const Text('LOG IN', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRow() {
    return Column(
      children: [
        const Text('or continue with', style: TextStyle(color: Color(0xFF6B3A2E))),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _socialButton(Icons.facebook, Colors.blue.shade800, 'Facebook'),
            const SizedBox(width: 12),
            // Use the provided google.png asset (placed in assets/)
            _socialButton(null, Colors.white, 'Google', asset: 'assets/google.png'),
            const SizedBox(width: 12),
            _socialButton(Icons.apple, Colors.black, 'Apple'),
          ],
        ),
      ],
    );
  }

  Widget _socialButton(IconData? icon, Color bg, String label, {String? asset, Color? iconColor}) {
    return GestureDetector(
      onTap: () async {
        if (label == 'Google') {
          setState(() => _loading = true);
          try {
            final FirebaseAuthService auth = FirebaseAuthService();
            final cred = await auth.signInWithGoogle();
            setState(() => _loading = false);
                if (cred != null && mounted) {
                  // After Google sign-in, sync basic profile information to Firestore
                  try {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      final svc = UserProfileService();
                      final profile = UserProfile(
                        uid: user.uid,
                        fullname: user.displayName ?? (user.email != null ? user.email!.split('@').first : ''),
                        email: user.email ?? '',
                        phone: user.phoneNumber ?? '',
                      );
                      svc.saveProfile(profile).then((ok) {}).catchError((_) {});
                    }
                  } catch (_) {}
                  // If the signed-in Google account is an admin, open admin panel.
                  final current = FirebaseAuth.instance.currentUser;
                  final email = current?.email?.toLowerCase();
                  final isAdmin = email != null && kAdminEmails.map((e) => e.toLowerCase()).contains(email);
                  if (isAdmin) {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AdminPanelPage()));
                  } else {
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
                  }
                }
          } catch (e) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-in failed')));
          }
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label login not implemented')));
      },
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 6)],
        ),
        child: Center(
          child: asset == null
              ? Icon(icon, color: iconColor ?? (bg == Colors.white ? Colors.black : Colors.white))
              : Image.asset(asset, width: 26, height: 26),
        ),
      ),
    );
  }

  Widget _buildSignupRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Don\'t have your account?', style: TextStyle(color: Color(0xFF6B3A2E))),
        TextButton(
          onPressed: () {
            // Navigate to register page
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterPage()));
          },
          child: const Text('Sign Up', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8C2E1A))),
        ),
      ],
    );
  }
}

// _PlaceholderHome removed — navigation now goes to the app's real HomePage

