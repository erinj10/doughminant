import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms and Agreements'),
        backgroundColor: const Color(0xFF8C2E1A),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('Terms and Agreements', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 12),
              Text(
                'These are placeholder terms and agreements for the Doughnate app. Replace this with your legal terms or load a remote URL. By creating an account you agree to these terms.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              SizedBox(height: 12),
              Text('• Use the app responsibly.'),
              Text('• Respect other users.'),
              Text('• Do not abuse the service.'),
            ],
          ),
        ),
      ),
    );
  }
}
