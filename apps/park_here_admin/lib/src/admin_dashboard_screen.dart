import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'admin_app_controller.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebase = ref.watch(adminFirebaseReadinessProvider);

    if (!firebase.isConfigured) {
      return _FirebaseSetupErrorScreen(message: firebase.message);
    }
    final state = ref.watch(adminAppControllerProvider);
    final controller = ref.read(adminAppControllerProvider.notifier);

    if (state.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (state.authStatus == AdminAuthStatus.signedOut) {
      return Scaffold(
        body: _AdminAuthScreen(
          error: state.error,
          onSignIn: controller.signIn,
          onSignUp: controller.signUp,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Park Here: Location Administrator'),
        actions: [
          IconButton(
            tooltip: 'Owner profile',
            onPressed: () => _showAdminProfileSheet(context, ref),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.section == AdminSection.parkingAreas
            ? () => _showRegisterLocationSheet(context, ref)
            : null,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add area'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > 900;
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              _SetupBanner(firebase: firebase, admin: state.admin!),
              const SizedBox(height: 16),
              _AdminSectionTabs(state: state, controller: controller),
              const SizedBox(height: 16),
              _StatsGrid(state: state),
              const SizedBox(height: 16),
              if (state.section == AdminSection.region)
                _RegionManagementPanel(state: state, controller: controller)
              else if (state.section == AdminSection.issues)
                _IssuesPanel(state: state, controller: controller)
              else if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _LocationsPanel(
                        state: state,
                        controller: controller,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 4,
                      child: _BookingPanel(
                        state: state,
                        controller: controller,
                      ),
                    ),
                  ],
                )
              else ...[
                _LocationsPanel(state: state, controller: controller),
                const SizedBox(height: 16),
                _BookingPanel(state: state, controller: controller),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showAdminProfileSheet(BuildContext context, WidgetRef ref) {
    final state = ref.read(adminAppControllerProvider);
    final admin = state.admin;
    if (admin == null) {
      return;
    }
    final business = TextEditingController(text: admin.businessName);
    final owner = TextEditingController(text: admin.ownerName);
    final phone = TextEditingController(text: admin.phone);
    final upi = TextEditingController(text: admin.upiId ?? '');

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Owner profile',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            TextField(
              controller: business,
              decoration: const InputDecoration(labelText: 'Business name'),
            ),
            TextField(
              controller: owner,
              decoration: const InputDecoration(labelText: 'Owner name'),
            ),
            TextField(
              controller: phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            TextField(
              controller: upi,
              decoration: const InputDecoration(labelText: 'UPI/payment id'),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                ref
                    .read(adminAppControllerProvider.notifier)
                    .updateAdminProfile(
                      businessName: business.text,
                      ownerName: owner.text,
                      phone: phone.text,
                      upiId: upi.text.isEmpty ? null : upi.text,
                    );
                Navigator.pop(context);
              },
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save profile'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRegisterLocationSheet(BuildContext context, WidgetRef ref) {
    final name = TextEditingController(text: 'New SIT Parking Area');
    final address = TextEditingController(text: 'SIT Tumkur Campus');
    final lat = TextEditingController(text: '13.3500');
    final lon = TextEditingController(text: '77.1020');
    final total = TextEditingController(text: '36');
    final available = TextEditingController(text: '20');
    final price = TextEditingController(text: '70');
    final opening = TextEditingController(text: '06:00');
    final closing = TextEditingController(text: '23:00');
    var selectedTypes = <VehicleType>{VehicleType.car, VehicleType.bike};

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add parking area inside SIT Tumkur',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Parking name',
                      ),
                    ),
                    TextField(
                      controller: address,
                      decoration: const InputDecoration(labelText: 'Address'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: lat,
                            decoration: const InputDecoration(
                              labelText: 'Latitude',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: lon,
                            decoration: const InputDecoration(
                              labelText: 'Longitude',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: total,
                            decoration: const InputDecoration(
                              labelText: 'Total spaces',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: available,
                            decoration: const InputDecoration(
                              labelText: 'Available spaces',
                            ),
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: price,
                      decoration: const InputDecoration(
                        labelText: 'Price per hour',
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: opening,
                            decoration: const InputDecoration(
                              labelText: 'Opening time',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: closing,
                            decoration: const InputDecoration(
                              labelText: 'Closing time',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: VehicleType.values.map((type) {
                        return FilterChip(
                          label: Text(type.label),
                          selected: selectedTypes.contains(type),
                          onSelected: (selected) => setSheetState(() {
                            selected
                                ? selectedTypes.add(type)
                                : selectedTypes.remove(type);
                          }),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        ref
                            .read(adminAppControllerProvider.notifier)
                            .registerLocation(
                              name: name.text,
                              address: address.text,
                              latitude: double.tryParse(lat.text) ?? 0,
                              longitude: double.tryParse(lon.text) ?? 0,
                              totalSpaces: int.tryParse(total.text) ?? 0,
                              availableSpaces:
                                  int.tryParse(available.text) ?? 0,
                              pricePerHour: double.tryParse(price.text) ?? 0,
                              vehicleTypes: selectedTypes.toList(),
                              openingTime: opening.text,
                              closingTime: closing.text,
                            );
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.add_business_outlined),
                      label: const Text('Create location'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _FirebaseSetupErrorScreen extends StatelessWidget {
  const _FirebaseSetupErrorScreen({required this.message});

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
                  'Run FlutterFire configuration for the admin app and enable Firebase Auth and Firestore.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminAuthScreen extends StatefulWidget {
  const _AdminAuthScreen({
    required this.onSignIn,
    required this.onSignUp,
    this.error,
  });

  final Future<void> Function({required String email, required String password})
  onSignIn;
  final Future<void> Function({
    required String email,
    required String password,
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  })
  onSignUp;
  final String? error;

  @override
  State<_AdminAuthScreen> createState() => _AdminAuthScreenState();
}

class _AdminAuthScreenState extends State<_AdminAuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _businessName = TextEditingController();
  final _ownerName = TextEditingController();
  final _phone = TextEditingController();
  final _upi = TextEditingController();
  var _isSignUp = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _businessName.dispose();
    _ownerName.dispose();
    _phone.dispose();
    _upi.dispose();
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
                'Location Administrator',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 6),
              const Text('Sign in with Firebase to manage live parking data.'),
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
                  controller: _businessName,
                  decoration: const InputDecoration(labelText: 'Business name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _ownerName,
                  decoration: const InputDecoration(labelText: 'Owner name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _upi,
                  decoration: const InputDecoration(
                    labelText: 'UPI/payment id optional',
                  ),
                ),
              ],
              if (widget.error != null) ...[
                const SizedBox(height: 12),
                Text(
                  widget.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submit,
                icon: Icon(_isSignUp ? Icons.person_add_alt : Icons.login),
                label: Text(_isSignUp ? 'Create admin account' : 'Sign in'),
              ),
              TextButton(
                onPressed: () => setState(() => _isSignUp = !_isSignUp),
                child: Text(
                  _isSignUp
                      ? 'I already have an admin account'
                      : 'Create a new admin account',
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
        businessName: _businessName.text.trim(),
        ownerName: _ownerName.text.trim(),
        phone: _phone.text.trim(),
        upiId: _upi.text.trim().isEmpty ? null : _upi.text.trim(),
      );
    } else {
      widget.onSignIn(email: _email.text.trim(), password: _password.text);
    }
  }
}

class _SetupBanner extends StatelessWidget {
  const _SetupBanner({required this.firebase, required this.admin});

  final FirebaseReadiness firebase;
  final AdminProfile admin;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: firebase.isConfigured
            ? const Color(0xFFEAF7EE)
            : const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE7DEC1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.storefront_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${admin.businessName} - ${firebase.message}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminSectionTabs extends StatelessWidget {
  const _AdminSectionTabs({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AdminSection>(
      segments: const [
        ButtonSegment(
          value: AdminSection.region,
          icon: Icon(Icons.polyline_outlined),
          label: Text('Region Management'),
        ),
        ButtonSegment(
          value: AdminSection.parkingAreas,
          icon: Icon(Icons.local_parking),
          label: Text('Parking Areas'),
        ),
        ButtonSegment(
          value: AdminSection.issues,
          icon: Icon(Icons.report_problem_outlined),
          label: Text('Issues Received'),
        ),
      ],
      selected: {state.section},
      onSelectionChanged: (selection) {
        controller.changeSection(selection.first);
      },
    );
  }
}

class _RegionManagementPanel extends StatelessWidget {
  const _RegionManagementPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final region = state.region;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(region.name, style: Theme.of(context).textTheme.titleLarge),
            Text(region.address),
            const SizedBox(height: 12),
            _MiniBoundaryMap(
              title: 'SIT Tumkur region boundary',
              regionPoints: region.boundaryPoints,
              areaPoints: const [],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.center_focus_strong, size: 18),
                  label: Text('${region.centerLat}, ${region.centerLng}'),
                ),
                Chip(
                  avatar: const Icon(Icons.timeline, size: 18),
                  label: Text('${region.boundaryPoints.length} polygon points'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.nudgeRegionBoundary,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Mark/edit region boundary'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBoundaryMap extends StatelessWidget {
  const _MiniBoundaryMap({
    required this.title,
    required this.regionPoints,
    required this.areaPoints,
  });

  final String title;
  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE9EFEA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD5DFDA)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BoundaryPainter(
                  regionPoints: regionPoints,
                  areaPoints: areaPoints,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(title),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryPainter extends CustomPainter {
  const _BoundaryPainter({
    required this.regionPoints,
    required this.areaPoints,
  });

  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;

  @override
  void paint(Canvas canvas, Size size) {
    final road = Paint()
      ..color = Colors.white.withAlpha(160)
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.08, size.height * 0.72),
      Offset(size.width * 0.92, size.height * 0.22),
      road,
    );
    _drawPolygon(
      canvas,
      size,
      regionPoints,
      Paint()
        ..color = ParkHereTheme.adminBlue.withAlpha(42)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = ParkHereTheme.adminBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _drawPolygon(
      canvas,
      size,
      areaPoints,
      Paint()
        ..color = ParkHereTheme.yellow.withAlpha(90)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = ParkHereTheme.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    List<GeoPointValue> points,
    Paint fill,
    Paint stroke,
  ) {
    if (points.length < 3) {
      return;
    }
    final minLat = points
        .map((point) => point.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = points
        .map((point) => point.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = points
        .map((point) => point.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = points
        .map((point) => point.longitude)
        .reduce((a, b) => a > b ? a : b);
    Offset project(GeoPointValue point) {
      final x =
          (point.longitude - minLng) / ((maxLng - minLng).abs() + 0.00001);
      final y = (maxLat - point.latitude) / ((maxLat - minLat).abs() + 0.00001);
      return Offset(24 + x * (size.width - 48), 24 + y * (size.height - 48));
    }

    final path = Path()
      ..moveTo(project(points.first).dx, project(points.first).dy);
    for (final point in points.skip(1)) {
      path.lineTo(project(point).dx, project(point).dy);
    }
    path.close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _BoundaryPainter oldDelegate) =>
      oldDelegate.regionPoints != regionPoints ||
      oldDelegate.areaPoints != areaPoints;
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.state});

  final AdminAppState state;

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Total spaces', '${state.totalSpaces}', Icons.grid_view_outlined),
      ('Available', '${state.availableSpaces}', Icons.event_available_outlined),
      (
        'Active bookings',
        '${state.activeBookings}',
        Icons.confirmation_number_outlined,
      ),
      ('Today income', formatInr(state.todaysIncome), Icons.payments_outlined),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: stats.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MediaQuery.sizeOf(context).width > 1100 ? 4 : 2,
        childAspectRatio: 1.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final stat = stats[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(child: Icon(stat.$3)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stat.$1,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          stat.$2,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LocationsPanel extends StatelessWidget {
  const _LocationsPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedLocation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parking areas in SIT Tumkur',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (state.locations.isEmpty)
              const _EmptyState(message: 'No parking areas yet.')
            else
              for (final location in state.locations)
                ListTile(
                  selected: selected?.id == location.id,
                  onTap: () {
                    controller.selectLocation(location);
                  },
                  leading: const Icon(Icons.local_parking),
                  title: Text(location.name),
                  subtitle: Text(
                    '${location.availableSpaces}/${location.totalSpaces} spaces - ${formatInr(location.pricePerHour)}/hr - ${location.ratingAverage.toStringAsFixed(1)} rating',
                  ),
                  trailing: Icon(
                    location.isOpen ? Icons.lock_open : Icons.lock_outline,
                  ),
                ),
            if (selected != null) ...[
              const Divider(height: 28),
              _AreaBoundaryEditor(
                region: state.region,
                location: selected,
                controller: controller,
              ),
              const Divider(height: 28),
              _AvailabilityEditor(location: selected, controller: controller),
              const Divider(height: 28),
              _ImageManager(state: state, controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

class _AreaBoundaryEditor extends StatelessWidget {
  const _AreaBoundaryEditor({
    required this.region,
    required this.location,
    required this.controller,
  });

  final ParkingRegion region;
  final ParkingLocation location;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Area editor map', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _MiniBoundaryMap(
          title: location.name,
          regionPoints: region.boundaryPoints,
          areaPoints: location.boundaryPoints,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.polyline_outlined, size: 18),
              label: Text('${location.boundaryPoints.length} area points'),
            ),
            Chip(
              avatar: const Icon(Icons.pin_drop_outlined, size: 18),
              label: Text('${location.centerLat}, ${location.centerLng}'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: controller.nudgeSelectedAreaBoundary,
          icon: const Icon(Icons.edit_location_outlined),
          label: const Text('Draw/mark area boundary'),
        ),
      ],
    );
  }
}

class _IssuesPanel extends StatelessWidget {
  const _IssuesPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final byArea = {
      for (final location in state.locations) location.id: location.name,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issues Received',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (state.issues.isEmpty)
              const _EmptyState(message: 'No parking area issues received.')
            else
              for (final issue in state.issues)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    issue.status == IssueStatus.resolved
                        ? Icons.task_alt
                        : Icons.report_problem_outlined,
                  ),
                  title: Text(
                    '${issue.type} - ${byArea[issue.areaId] ?? issue.areaId}',
                  ),
                  subtitle: Text('${issue.message}\n${issue.createdAt}'),
                  isThreeLine: true,
                  trailing: DropdownButton<IssueStatus>(
                    value: issue.status,
                    onChanged: (status) {
                      if (status != null) {
                        controller.updateIssueStatus(issue, status);
                      }
                    },
                    items: IssueStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _ImageManager extends StatelessWidget {
  const _ImageManager({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optimized images',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          state.imageStatusMessage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.imageUploadProgress > 0 && state.imageUploadProgress < 1) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: state.imageUploadProgress),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final image in state.selectedImages)
              SizedBox(
                width: 154,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDE5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Image.memory(
                          image.previewBytes,
                          width: 154,
                          height: 92,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(image.previewSizeBytes / 1024).toStringAsFixed(1)}KB preview',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Replace image',
                                  onPressed: () =>
                                      controller.replaceImage(image),
                                  icon: const Icon(
                                    Icons.change_circle_outlined,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove image',
                                  onPressed: () =>
                                      controller.removeImage(image),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(
              width: 154,
              height: 148,
              child: OutlinedButton.icon(
                key: const ValueKey('upload-optimized-image'),
                onPressed: controller.uploadDemoImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Upload optimized image'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AvailabilityEditor extends StatefulWidget {
  const _AvailabilityEditor({required this.location, required this.controller});

  final ParkingLocation location;
  final AdminAppController controller;

  @override
  State<_AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<_AvailabilityEditor> {
  late double total = widget.location.totalSpaces.toDouble();
  late double available = widget.location.availableSpaces.toDouble();
  late double price = widget.location.pricePerHour;
  late bool isOpen = widget.location.isOpen;

  @override
  void didUpdateWidget(covariant _AvailabilityEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.id != widget.location.id) {
      total = widget.location.totalSpaces.toDouble();
      available = widget.location.availableSpaces.toDouble();
      price = widget.location.pricePerHour;
      isOpen = widget.location.isOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage availability',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Location open'),
          value: isOpen,
          onChanged: (value) => setState(() => isOpen = value),
        ),
        _LabeledSlider(
          label: 'Total spaces',
          value: total,
          min: 1,
          max: 200,
          onChanged: (value) => setState(() => total = value),
        ),
        _LabeledSlider(
          label: 'Available spaces',
          value: available.clamp(0, total),
          min: 0,
          max: total,
          onChanged: (value) => setState(() => available = value),
        ),
        _LabeledSlider(
          label: 'Price per hour',
          value: price,
          min: 10,
          max: 250,
          onChanged: (value) => setState(() => price = value),
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () => widget.controller.updateSelectedAvailability(
            totalSpaces: total.round(),
            availableSpaces: available.round(),
            isOpen: isOpen,
            pricePerHour: price.roundToDouble(),
          ),
          icon: const Icon(Icons.tune),
          label: const Text('Update location'),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 118, child: Text(label)),
        Expanded(
          child: Slider(
            min: min,
            max: max <= min ? min + 1 : max,
            divisions: (max - min).round().clamp(1, 200),
            value: value.clamp(min, max <= min ? min + 1 : max),
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(width: 48, child: Text(value.round().toString())),
      ],
    );
  }
}

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bookings', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            if (state.bookings.isEmpty)
              const _EmptyState(
                message:
                    'Bookings will appear here once drivers reserve slots.',
              )
            else
              for (final booking in state.bookings)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.qr_code_2),
                  title: Text(booking.vehicleNumber),
                  subtitle: Text(
                    '${booking.id} • ${booking.status.name} • ${formatInr(booking.price)}',
                  ),
                  trailing: booking.status == BookingStatus.active
                      ? IconButton(
                          tooltip: 'Mark completed',
                          onPressed: () => controller.markCompleted(booking),
                          icon: const Icon(Icons.check_circle_outline),
                        )
                      : const Icon(Icons.done_all),
                  onTap: () => _showBookingDetails(context, booking),
                ),
            const Divider(height: 28),
            Text(
              'Weekly/monthly income',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const LinearProgressIndicator(value: 0.62),
            const SizedBox(height: 8),
            const Text('Placeholder for chart-backed income analytics.'),
          ],
        ),
      ),
    );
  }

  void _showBookingDetails(BuildContext context, Booking booking) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(booking.id),
        content: SelectableText(booking.qrPayload),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
        ),
      ),
    );
  }
}
