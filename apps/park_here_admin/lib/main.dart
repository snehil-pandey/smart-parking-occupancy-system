import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'src/admin_dashboard_screen.dart';

void main() {
  runApp(const ProviderScope(child: ParkHereAdminApp()));
}

class ParkHereAdminApp extends StatelessWidget {
  const ParkHereAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Park Here: Location Administrator',
      theme: ParkHereTheme.adminTheme(),
      home: const AdminDashboardScreen(),
    );
  }
}
