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

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  @override
  Widget build(BuildContext context) {
    ref.listen<UserAppState>(userAppControllerProvider, (previous, next) {
      final confirmation = next.bookingConfirmation;
      if (confirmation == null ||
          previous?.bookingConfirmation?.booking.id ==
              confirmation.booking.id) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        _showBookingConfirmation(confirmation);
      });
    });

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

  Future<void> _showBookingConfirmation(
    UserBookingConfirmation confirmation,
  ) async {
    final controller = ref.read(userAppControllerProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _BookingConfirmationSheet(
        confirmation: confirmation,
        onViewTicket: () {
          Navigator.of(context).pop();
          controller.clearBookingConfirmation();
          controller.changeTab(UserTab.bookings);
        },
        onViewDetails: () {
          Navigator.of(context).pop();
          controller.clearBookingConfirmation();
          controller.changeTab(UserTab.bookings);
        },
      ),
    );
    controller.clearBookingConfirmation();
  }
}

class _BookingConfirmationSheet extends StatelessWidget {
  const _BookingConfirmationSheet({
    required this.confirmation,
    required this.onViewTicket,
    required this.onViewDetails,
  });

  final UserBookingConfirmation confirmation;
  final VoidCallback onViewTicket;
  final VoidCallback onViewDetails;

  @override
  Widget build(BuildContext context) {
    final booking = confirmation.booking;
    final location = confirmation.location;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: Color(0xFF1B5E20),
                  foregroundColor: Colors.white,
                  child: Icon(Icons.check),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Booking confirmed',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(location.name, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            _ConfirmationRow(
              label: 'Ticket',
              value: confirmation.shortTicketId,
            ),
            _ConfirmationRow(
              label: 'Booking ID',
              value: booking.id.length <= 18
                  ? booking.id
                  : '${booking.id.substring(0, 18)}...',
            ),
            _ConfirmationRow(
              label: 'Valid from',
              value: _formatTicketTime(booking.startTime),
            ),
            _ConfirmationRow(
              label: 'Valid until',
              value: _formatTicketTime(booking.endTime),
            ),
            _ConfirmationRow(label: 'Price', value: formatInr(booking.price)),
            const SizedBox(height: 8),
            const StatusStrip(
              message: 'QR ticket is ready in the Bookings tab.',
              isError: false,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onViewTicket,
                    icon: const Icon(Icons.qr_code_2),
                    label: const Text('View Ticket'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onViewDetails,
                    icon: const Icon(Icons.confirmation_number_outlined),
                    label: const Text('View Booking Details'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfirmationRow extends StatelessWidget {
  const _ConfirmationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTicketTime(DateTime value) {
  final date = '${value.day}/${value.month}/${value.year}';
  final time =
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
  return '$date, $time';
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
