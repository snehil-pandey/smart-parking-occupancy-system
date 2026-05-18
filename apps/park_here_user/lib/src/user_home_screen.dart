import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'features/user_bookings_tab.dart';
import 'features/user_explore_tab.dart';
import 'features/user_home_tab.dart';
import 'features/user_notifications_tab.dart';
import 'features/user_profile_tab.dart';
import 'user_app_controller.dart';
import 'widgets/user_status_strip.dart';

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebase = ref.watch(firebaseReadinessProvider);
    if (!firebase.isConfigured) {
      return FirebaseSetupErrorScreen(message: firebase.message);
    }
    final state = ref.watch(userAppControllerProvider);
    final controller = ref.read(userAppControllerProvider.notifier);

    if (state.isLoading || state.authStatus == UserAuthStatus.checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.authStatus == UserAuthStatus.signedOut) {
      return Scaffold(
        body: _UserAuthScreen(
          error: state.error,
          onSignIn: controller.signIn,
          onSignUp: controller.signUp,
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: state.currentTab.index,
          children: [
            UserHomeTab(state: state, controller: controller),
            UserBookingsTab(state: state, controller: controller),
            UserExploreTab(state: state, controller: controller),
            UserNotificationsTab(state: state, controller: controller),
            UserProfileTab(
              state: state,
              controller: controller,
              firebase: firebase,
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.currentTab.index,
        onDestinationSelected: (index) =>
            controller.changeTab(UserTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.confirmation_number_outlined),
            selectedIcon: Icon(Icons.confirmation_number),
            label: 'Bookings',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
            label: 'Updates',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class FirebaseSetupErrorScreen extends StatelessWidget {
  const FirebaseSetupErrorScreen({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.cloud_off_outlined,
                  size: 42,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 14),
                Text(
                  'Firebase setup required',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 8),
                const Text(
                  'Run FlutterFire configuration for this app and make sure Firebase Auth and Firestore are enabled.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAuthScreen extends StatefulWidget {
  const _UserAuthScreen({
    required this.onSignIn,
    required this.onSignUp,
    this.error,
  });

  final Future<void> Function({required String email, required String password})
  onSignIn;
  final Future<void> Function({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  })
  onSignUp;
  final String? error;

  @override
  State<_UserAuthScreen> createState() => _UserAuthScreenState();
}

class _UserAuthScreenState extends State<_UserAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _vehicle = TextEditingController();
  var _vehicleType = VehicleType.car;
  var _isSignUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Park Here',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('Sign in with Firebase to load live parking data.'),
              const SizedBox(height: 18),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              if (_isSignUp) ...[
                const SizedBox(height: 10),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _vehicle,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle number',
                  ),
                ),
                const SizedBox(height: 10),
                SegmentedButton<VehicleType>(
                  segments: VehicleType.values
                      .map(
                        (type) =>
                            ButtonSegment(value: type, label: Text(type.label)),
                      )
                      .toList(),
                  selected: {_vehicleType},
                  onSelectionChanged: (value) =>
                      setState(() => _vehicleType = value.first),
                ),
              ],
              if (widget.error != null) ...[
                const SizedBox(height: 12),
                StatusStrip(message: widget.error!, isError: true),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: Icon(_isSignUp ? Icons.person_add_alt : Icons.login),
                label: Text(_isSignUp ? 'Create user account' : 'Sign in'),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'I already have an account'
                      : 'Create a new user account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (_isSignUp) {
      widget.onSignUp(
        email: _email.text.trim(),
        password: _password.text,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        vehicleNumber: _vehicle.text.trim(),
        vehicleType: _vehicleType,
      );
    } else {
      widget.onSignIn(email: _email.text.trim(), password: _password.text);
    }
  }
}
