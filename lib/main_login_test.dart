import 'package:flutter/material.dart';
import 'screens/login_page.dart';

void main() {
  runApp(const LoginTestApp());
}

class LoginTestApp extends StatelessWidget {
  const LoginTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Login Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginPage(),
    );
  }
}
