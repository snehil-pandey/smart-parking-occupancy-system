import 'package:flutter/material.dart';
import 'package:park_here_shared/park_here_shared.dart';

import '../user_app_controller.dart';
import '../widgets/user_status_strip.dart';

class UserProfileTab extends StatefulWidget {
  const UserProfileTab({
    required this.state,
    required this.controller,
    required this.firebase,
    super.key,
  });

  final UserAppState state;
  final UserAppController controller;
  final FirebaseReadiness firebase;

  @override
  State<UserProfileTab> createState() => _UserProfileTabState();
}

class _UserProfileTabState extends State<UserProfileTab> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _vehicle;
  late VehicleType _vehicleType;

  @override
  void initState() {
    super.initState();
    final user = widget.state.user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _vehicle = TextEditingController(text: user?.vehicleNumber ?? '');
    _vehicleType = user?.defaultVehicleType ?? VehicleType.car;
  }

  @override
  void didUpdateWidget(covariant UserProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final user = widget.state.user;
    if (user != null && user.id != oldWidget.state.user?.id) {
      _name.text = user.name;
      _phone.text = user.phone;
      _vehicle.text = user.vehicleNumber;
      _vehicleType = user.defaultVehicleType;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _vehicle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(user == null ? 'Firebase user profile' : 'UID: ${user.id}'),
        const SizedBox(height: 16),
        StatusStrip(message: widget.firebase.message),
        const SizedBox(height: 18),
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
          decoration: const InputDecoration(labelText: 'Vehicle number'),
        ),
        const SizedBox(height: 12),
        SegmentedButton<VehicleType>(
          segments: VehicleType.values
              .map(
                (type) => ButtonSegment(value: type, label: Text(type.label)),
              )
              .toList(),
          selected: {_vehicleType},
          onSelectionChanged: (selection) =>
              setState(() => _vehicleType = selection.first),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Save profile'),
        ),
        const SizedBox(height: 18),
        _ProfileStatRow(
          label: 'Bookings',
          value: widget.state.bookings.length.toString(),
        ),
        _ProfileStatRow(
          label: 'Reviews visible',
          value: widget.state.selectedReviews.length.toString(),
        ),
        _ProfileStatRow(
          label: 'Active booking',
          value: widget.state.activeBooking == null ? 'No' : 'Yes',
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: widget.controller.signOut,
          icon: const Icon(Icons.logout),
          label: const Text('Logout'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    await widget.controller.updateProfile(
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      vehicleNumber: _vehicle.text.trim(),
      vehicleType: _vehicleType,
    );
  }
}

class _ProfileStatRow extends StatelessWidget {
  const _ProfileStatRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
  }
}
