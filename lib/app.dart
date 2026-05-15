import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/home/home_screen.dart';

class TryMaarApp extends StatelessWidget {
  const TryMaarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TryMaar',
      debugShowCheckedModeBanner: false,
      theme: TryMaarTheme.darkTheme,
      home: const HomeScreen(),
    );
  }
}
