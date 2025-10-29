import 'package:flutter/material.dart';
import 'screens/order_tracking.dart';

void main() {
  runApp(const MapTestApp());
}

class MapTestApp extends StatelessWidget {
  const MapTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Map Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
      ),
      home: const OrderTrackingPage(),
    );
  }
}
