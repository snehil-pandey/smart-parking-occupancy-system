import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'src/user_home_screen.dart';

void main() {
  runApp(const ProviderScope(child: ParkHereUserApp()));
}

class ParkHereUserApp extends StatelessWidget {
  const ParkHereUserApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Park Here',
      theme: ParkHereTheme.userTheme(),
      home: const UserHomeScreen(),
    );
  }
}
