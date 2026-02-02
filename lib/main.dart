import 'package:flutter/material.dart';
import 'home_screen.dart'; 

void main() {
  runApp(const SeederDemo());
}

class SeederDemo extends StatelessWidget {
  const SeederDemo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Seeder Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}