import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'admin_app_controller.dart';

part 'features/auth/admin_auth_section.dart';
part 'features/dashboard/dashboard_section.dart';
part 'features/region/region_section.dart';
part 'features/parking_areas/parking_areas_section.dart';
part 'features/issues/issues_section.dart';
part 'features/bookings/bookings_section.dart';
part 'features/profile/profile_section.dart';
part 'widgets/admin_common_widgets.dart';

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
      return const Scaffold(body: _AdminLoadingScreen());
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

    if (state.requiresRegionSetup) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Region Setup'),
          actions: [
            IconButton(
              tooltip: 'Sign out',
              onPressed: controller.signOut,
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            if (state.error != null) ...[
              _ErrorBanner(message: state.error!, onRefresh: controller.load),
              const SizedBox(height: 12),
            ],
            _ControlledRegionEditor(
              state: state,
              controller: controller,
              mandatory: true,
            ),
          ],
        ),
      );
    }

    return _AdminNavigationShell(
      firebase: firebase,
      state: state,
      controller: controller,
      onAddArea: () => _showRegisterLocationSheet(context, ref),
    );
  }

  void _showRegisterLocationSheet(BuildContext context, WidgetRef ref) {
    final state = ref.read(adminAppControllerProvider);
    final name = TextEditingController(text: 'New Parking Area');
    final address = TextEditingController(text: state.region.address);
    final description = TextEditingController(text: 'Managed parking area.');
    final total = TextEditingController(text: '36');
    final available = TextEditingController(text: '20');
    final price = TextEditingController(text: '20');
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
                      'Add parking area inside your region',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    _AdminOsmGeometryMap(
                      title: 'Controlled region for new area',
                      regionPoints: state.region.boundaryPoints,
                      areaPoints: const [],
                      gatePoints: const [],
                      selectedGeometryPoint: null,
                    ),
                    const SizedBox(height: 12),
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
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
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
                              description: description.text,
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

class _AdminNavigationShell extends StatelessWidget {
  const _AdminNavigationShell({
    required this.firebase,
    required this.state,
    required this.controller,
    required this.onAddArea,
  });

  final FirebaseReadiness firebase;
  final AdminAppState state;
  final AdminAppController controller;
  final VoidCallback onAddArea;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _sectionIndex(state.section);
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 860;
        return Scaffold(
          appBar: AppBar(
            title: Text(_adminDestinations[selectedIndex].label),
            actions: [
              IconButton(
                tooltip: 'Retry Firebase streams',
                onPressed: controller.load,
                icon: const Icon(Icons.refresh),
              ),
              IconButton(
                tooltip: 'Profile and settings',
                onPressed: () => controller.changeSection(AdminSection.profile),
                icon: const Icon(Icons.account_circle_outlined),
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: controller.signOut,
                icon: const Icon(Icons.logout),
              ),
            ],
          ),
          floatingActionButton: state.section == AdminSection.parkingAreas
              ? FloatingActionButton.extended(
                  onPressed: onAddArea,
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Add area'),
                )
              : null,
          bottomNavigationBar: wide
              ? null
              : NavigationBar(
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (index) => controller.changeSection(
                    _adminDestinations[index].section,
                  ),
                  destinations: [
                    for (final destination in _adminDestinations)
                      NavigationDestination(
                        icon: Icon(destination.icon),
                        selectedIcon: Icon(destination.selectedIcon),
                        label: destination.label,
                      ),
                  ],
                ),
          body: wide
              ? Row(
                  children: [
                    NavigationRail(
                      extended: constraints.maxWidth >= 1120,
                      selectedIndex: selectedIndex,
                      onDestinationSelected: (index) => controller
                          .changeSection(_adminDestinations[index].section),
                      labelType: constraints.maxWidth >= 1120
                          ? NavigationRailLabelType.none
                          : NavigationRailLabelType.all,
                      destinations: [
                        for (final destination in _adminDestinations)
                          NavigationRailDestination(
                            icon: Icon(destination.icon),
                            selectedIcon: Icon(destination.selectedIcon),
                            label: Text(destination.label),
                          ),
                      ],
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: _AdminSectionView(
                        firebase: firebase,
                        state: state,
                        controller: controller,
                      ),
                    ),
                  ],
                )
              : _AdminSectionView(
                  firebase: firebase,
                  state: state,
                  controller: controller,
                ),
        );
      },
    );
  }
}

class _AdminSectionView extends StatelessWidget {
  const _AdminSectionView({
    required this.firebase,
    required this.state,
    required this.controller,
  });

  final FirebaseReadiness firebase;
  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        _SetupBanner(firebase: firebase, admin: state.admin!),
        if (state.error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: state.error!, onRefresh: controller.load),
        ],
        const SizedBox(height: 16),
        switch (state.section) {
          AdminSection.dashboard => _DashboardSection(
            state: state,
            controller: controller,
          ),
          AdminSection.region => _RegionManagementPanel(
            state: state,
            controller: controller,
          ),
          AdminSection.parkingAreas => _LocationsPanel(
            state: state,
            controller: controller,
          ),
          AdminSection.bookings => _BookingPanel(
            state: state,
            controller: controller,
          ),
          AdminSection.issues => _IssuesPanel(
            state: state,
            controller: controller,
          ),
          AdminSection.profile => _ProfileSection(
            firebase: firebase,
            state: state,
            controller: controller,
          ),
        },
      ],
    );
  }
}

class _AdminDestination {
  const _AdminDestination({
    required this.section,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final AdminSection section;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

const _adminDestinations = [
  _AdminDestination(
    section: AdminSection.dashboard,
    label: 'Dashboard',
    icon: Icons.dashboard_outlined,
    selectedIcon: Icons.dashboard,
  ),
  _AdminDestination(
    section: AdminSection.region,
    label: 'Region',
    icon: Icons.polyline_outlined,
    selectedIcon: Icons.polyline,
  ),
  _AdminDestination(
    section: AdminSection.parkingAreas,
    label: 'Areas',
    icon: Icons.local_parking_outlined,
    selectedIcon: Icons.local_parking,
  ),
  _AdminDestination(
    section: AdminSection.bookings,
    label: 'Bookings',
    icon: Icons.confirmation_number_outlined,
    selectedIcon: Icons.confirmation_number,
  ),
  _AdminDestination(
    section: AdminSection.issues,
    label: 'Issues',
    icon: Icons.report_problem_outlined,
    selectedIcon: Icons.report_problem,
  ),
  _AdminDestination(
    section: AdminSection.profile,
    label: 'Profile',
    icon: Icons.manage_accounts_outlined,
    selectedIcon: Icons.manage_accounts,
  ),
];

int _sectionIndex(AdminSection section) {
  final index = _adminDestinations.indexWhere(
    (destination) => destination.section == section,
  );
  return index < 0 ? 0 : index;
}
