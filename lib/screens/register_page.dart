import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/gestures.dart';

import 'home_page.dart';
import 'terms_page.dart';
import '../services/firebase_auth_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();

  bool _showPassword = false;
  bool _loading = false;
  double _passwordScore = 0.0;
  bool _agreed = false;
  late TapGestureRecognizer _termsRecognizer;

  late AnimationController _logoController;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  final FirebaseAuthService _authService = FirebaseAuthService();

  @override
  void initState() {
    super.initState();
    _logoController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = CurvedAnimation(parent: _logoController, curve: Curves.elasticOut);
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _logoController, curve: Curves.easeOut));
    _logoController.forward();
    _passwordController.addListener(_onPasswordChanged);
    _confirmController.addListener(_onConfirmChanged);
    _termsRecognizer = TapGestureRecognizer()..onTap = _openTerms;
  }

  @override
  void dispose() {
    _logoController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.removeListener(_onPasswordChanged);
    _passwordController.dispose();
    _confirmController.removeListener(_onConfirmChanged);
    _confirmController.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  void _openTerms() {
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TermsPage()));
  }

  void _onConfirmChanged() {
    setState(() {});
  }

  void _onPasswordChanged() {
    final pwd = _passwordController.text;
    final score = _calculatePasswordScore(pwd);
    setState(() {
      _passwordScore = score;
    });
  }

  double _calculatePasswordScore(String pwd) {
    if (pwd.isEmpty) return 0.0;
    double score = 0;
    if (pwd.length >= 8) score += 0.3;
    if (RegExp(r'[A-Z]').hasMatch(pwd)) score += 0.2;
    if (RegExp(r'[0-9]').hasMatch(pwd)) score += 0.2;
    if (RegExp(r'[!@#\$%\^&\*(),.?":{}|<>]').hasMatch(pwd)) score += 0.3;
    return score.clamp(0.0, 1.0);
  }

  String _passwordStrengthLabel(double score) {
    if (score <= 0.25) return 'Very weak';
    if (score <= 0.5) return 'Weak';
    if (score <= 0.75) return 'Good';
    return 'Strong';
  }

  Future<void> _attemptRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You must agree to the Terms and Agreements to continue')));
      return;
    }
    setState(() => _loading = true);
    try {
      // Create user with Firebase Auth
      await _authService.registerWithEmail(_emailController.text.trim(), _passwordController.text);

      // Optionally persist registered user email locally for demo purposes
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('registered_email', _emailController.text.trim());

      setState(() => _loading = false);
      if (!mounted) return;

      // Show success and navigate to HomePage
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Account created'),
          content: const Text('Your account was created successfully.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
              },
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } on FirebaseAuthException catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message ?? 'Registration failed')));
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFFB75E), Color(0xFFED8F03)],
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
                    FadeTransition(opacity: _logoFade, child: ScaleTransition(scale: _logoScale, child: _buildLogo())),
                    const SizedBox(height: 18),
                    const Text('Create account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Color(0xFF5B2A1A))),
                    const SizedBox(height: 18),
                    _buildCard(),
                    const SizedBox(height: 12),
                    _buildSigninRow(),
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
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.14), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Center(
        child: ClipOval(
          child: SizedBox(
            width: 100,
            height: 100,
            child: Image.asset('assets/app_icon.png', fit: BoxFit.cover),
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
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(hintText: 'Full name', filled: true, fillColor: const Color(0xFFF8ECE5), prefixIcon: const Icon(Icons.person_outline, color: Color(0xFFB85A3B)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(hintText: 'Email', filled: true, fillColor: const Color(0xFFF8ECE5), prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFFB85A3B)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Please enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              // Password field with live strength indicator
              TextFormField(
                controller: _passwordController,
                obscureText: !_showPassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  hintText: 'Password',
                  filled: true,
                  fillColor: const Color(0xFFF8ECE5),
                  prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFFB85A3B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: IconButton(icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey[700]), onPressed: () => setState(() => _showPassword = !_showPassword)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please enter a password';
                  if (v.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 8),
              // Strength meter and guidance
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: _passwordScore,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.4),
                    valueColor: AlwaysStoppedAnimation<Color>(_passwordScore < 0.4
                        ? Colors.redAccent
                        : _passwordScore < 0.75
                            ? Colors.orange
                            : Colors.green),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          _passwordScore == 0 ? 'Use at least 8 chars, upper-case, number, symbol' : _passwordStrengthLabel(_passwordScore),
                          style: TextStyle(color: _passwordScore < 0.4 ? Colors.redAccent : (_passwordScore < 0.75 ? Colors.orange : Colors.green), fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Confirm password with live match indicator
              TextFormField(
                controller: _confirmController,
                obscureText: !_showPassword,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                decoration: InputDecoration(
                  hintText: 'Confirm password',
                  filled: true,
                  fillColor: const Color(0xFFF8ECE5),
                  prefixIcon: const Icon(Icons.lock, color: Color(0xFFB85A3B)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  suffixIcon: _confirmController.text.isEmpty
                      ? null
                      : Icon(
                          _confirmController.text == _passwordController.text ? Icons.check_circle : Icons.cancel,
                          color: _confirmController.text == _passwordController.text ? Colors.green : Colors.redAccent,
                        ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Please confirm your password';
                  if (v != _passwordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 14),
              // Terms & Agreements checkbox (CheckboxListTile with tappable link)
              CheckboxListTile(
                value: _agreed,
                onChanged: (v) => setState(() => _agreed = v ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                title: RichText(
                  text: TextSpan(
                    text: 'I agree to the ',
                    style: const TextStyle(color: Color(0xFF6B3A2E)),
                    children: [
                      TextSpan(
                        text: 'Terms and Agreements',
                        style: const TextStyle(color: Color(0xFF8C2E1A), fontWeight: FontWeight.bold),
                        recognizer: _termsRecognizer,
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: 48,
                child: Builder(builder: (context) {
                  final canSubmit = !_loading && _agreed && _passwordScore >= 0.5;
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8C2E1A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: canSubmit ? _attemptRegister : null,
                    child: _loading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.2)) : const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                  );
                }),
              ),
              const SizedBox(height: 10),
              // Social signup prompt under the card
              Column(
                children: [
                  const SizedBox(height: 8),
                  const Text('or sign up using your', style: TextStyle(color: Color(0xFF6B3A2E))),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _socialButton(Icons.facebook, Colors.blue.shade800, 'Facebook'),
                      const SizedBox(width: 12),
                      _socialButton(null, Colors.white, 'Google', asset: 'assets/google.png'),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSigninRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Already have an account?', style: TextStyle(color: Color(0xFF6B3A2E))),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Sign in', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF8C2E1A))),
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
            final cred = await _authService.signInWithGoogle();
            setState(() => _loading = false);
            if (cred != null && mounted) {
              Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
            }
          } catch (e) {
            setState(() => _loading = false);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Google sign-up failed')));
          }
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label sign-up not implemented')));
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
}
