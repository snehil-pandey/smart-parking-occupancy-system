import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:park_here_shared/park_here_shared.dart';

import 'admin_app_controller.dart';

part 'features/auth/admin_auth_section.dart';
part 'features/dashboard/dashboard_section.dart';
part 'features/region/region_section.dart';
part 'features/parking_areas/parking_areas_section.dart';
part 'features/issues/issues_section.dart';
part 'features/bookings/bookings_section.dart';
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
            tooltip: 'Refresh Firebase data',
            onPressed: () {
              controller.load();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Owner profile',
            onPressed: () => _showAdminProfileSheet(context, ref),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: controller.signOut,
            icon: const Icon(Icons.logout),
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
              if (state.error != null) ...[
                const SizedBox(height: 12),
                _ErrorBanner(message: state.error!, onRefresh: controller.load),
              ],
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
    final lat = TextEditingController(text: '13.3281');
    final lon = TextEditingController(text: '77.1257');
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
