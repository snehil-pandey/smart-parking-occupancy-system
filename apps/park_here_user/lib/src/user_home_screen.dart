import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:park_here_shared/park_here_shared.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'user_app_controller.dart';

class UserHomeScreen extends ConsumerWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userAppControllerProvider);
    final controller = ref.read(userAppControllerProvider.notifier);
    final firebase = ref.watch(firebaseReadinessProvider);

    return Scaffold(
      body: SafeArea(
        child: state.isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  Positioned.fill(
                    child: RouteMapCanvas(
                      locations: state.locations,
                      selectedLocation: state.selectedLocation,
                      routes: state.routes,
                      onSelect: controller.selectLocation,
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    top: 16,
                    child: _SearchPanel(
                      user: state.user,
                      firebase: firebase,
                      onProfileTap: () => _showProfileSheet(context, ref),
                    ),
                  ),
                  DraggableScrollableSheet(
                    initialChildSize: 0.45,
                    minChildSize: 0.24,
                    maxChildSize: 0.82,
                    builder: (context, scrollController) {
                      return _ParkingBottomSheet(
                        state: state,
                        controller: controller,
                        scrollController: scrollController,
                      );
                    },
                  ),
                ],
              ),
      ),
    );
  }

  void _showProfileSheet(BuildContext context, WidgetRef ref) {
    final state = ref.read(userAppControllerProvider);
    final name = TextEditingController(text: state.user.name);
    final phone = TextEditingController(text: state.user.phone);
    final vehicle = TextEditingController(text: state.user.vehicleNumber);
    var vehicleType = state.user.defaultVehicleType;

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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver profile',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(labelText: 'Name'),
                  ),
                  TextField(
                    controller: phone,
                    decoration: const InputDecoration(labelText: 'Phone'),
                  ),
                  TextField(
                    controller: vehicle,
                    decoration: const InputDecoration(
                      labelText: 'Vehicle number',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<VehicleType>(
                    segments: VehicleType.values
                        .map(
                          (type) => ButtonSegment(
                            value: type,
                            label: Text(type.label),
                          ),
                        )
                        .toList(),
                    selected: {vehicleType},
                    onSelectionChanged: (selection) => setSheetState(() {
                      vehicleType = selection.first;
                    }),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      ref
                          .read(userAppControllerProvider.notifier)
                          .updateProfile(
                            name: name.text,
                            phone: phone.text,
                            vehicleNumber: vehicle.text,
                            vehicleType: vehicleType,
                          );
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save profile'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.user,
    required this.firebase,
    required this.onProfileTap,
  });

  final AppUser user;
  final FirebaseReadiness firebase;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withAlpha(24),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                const Icon(Icons.search),
                const SizedBox(width: 8),
                const Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search destination or parking',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Profile',
                  onPressed: onProfileTap,
                  icon: const Icon(Icons.account_circle_outlined),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        DecoratedBox(
          decoration: BoxDecoration(
            color: firebase.isConfigured
                ? const Color(0xFFEAF7EE)
                : const Color(0xFFFFF4CF),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(
                  firebase.isConfigured
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${user.vehicleNumber} - ${firebase.message}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RouteMapCanvas extends StatelessWidget {
  const RouteMapCanvas({
    required this.locations,
    required this.selectedLocation,
    required this.routes,
    required this.onSelect,
    super.key,
  });

  final List<ParkingLocation> locations;
  final ParkingLocation? selectedLocation;
  final List<RouteOption> routes;
  final ValueChanged<ParkingLocation> onSelect;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CustomPaint(
          painter: _MapPainter(routes: routes),
          child: const SizedBox.expand(),
        ),
        ...locations.map((location) {
          final left = ((location.longitude - 77.585) / 0.04).clamp(0.06, 0.86);
          final top = ((12.99 - location.latitude) / 0.035).clamp(0.16, 0.68);
          final selected = location.id == selectedLocation?.id;
          return Positioned(
            left: MediaQuery.sizeOf(context).width * left,
            top: MediaQuery.sizeOf(context).height * top,
            child: GestureDetector(
              onTap: () => onSelect(location),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? ParkHereTheme.yellow : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ParkHereTheme.black,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.local_parking, size: 18),
                    const SizedBox(width: 4),
                    Text('${location.availableSpaces}'),
                  ],
                ),
              ),
            ),
          );
        }),
        const Positioned(left: 24, top: 180, child: _DriverMarker()),
      ],
    );
  }
}

class _DriverMarker extends StatelessWidget {
  const _DriverMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ParkHereTheme.black,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white, width: 3),
      ),
      child: const Padding(
        padding: EdgeInsets.all(9),
        child: Icon(Icons.navigation, color: Colors.white, size: 18),
      ),
    );
  }
}

class _MapPainter extends CustomPainter {
  const _MapPainter({required this.routes});

  final List<RouteOption> routes;

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFE9E4D5);
    canvas.drawRect(Offset.zero & size, background);

    final roadPaint = Paint()
      ..color = Colors.white.withAlpha(190)
      ..strokeWidth = 20
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.12 + i * 0.12);
      canvas.drawLine(
        Offset(-30, y),
        Offset(size.width + 30, y + sin(i) * 34),
        roadPaint,
      );
    }
    for (var i = 0; i < 5; i++) {
      final x = size.width * (0.12 + i * 0.2);
      canvas.drawLine(
        Offset(x, -20),
        Offset(x + cos(i) * 46, size.height + 20),
        roadPaint,
      );
    }

    if (routes.isEmpty) {
      return;
    }
    for (final route in routes.reversed) {
      final paint = Paint()
        ..color = route.isBest ? ParkHereTheme.black : const Color(0xFF6E8E9E)
        ..strokeWidth = route.isBest ? 6 : 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(size.width * 0.14, size.height * 0.24);
      for (var i = 1; i < route.points.length; i++) {
        final t = i / max(1, route.points.length - 1);
        path.lineTo(
          size.width * (0.14 + t * 0.62),
          size.height * (0.24 + sin(t * pi) * 0.18),
        );
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapPainter oldDelegate) =>
      oldDelegate.routes != routes;
}

class _ParkingBottomSheet extends StatelessWidget {
  const _ParkingBottomSheet({
    required this.state,
    required this.controller,
    required this.scrollController,
  });

  final UserAppState state;
  final UserAppController controller;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedLocation;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD8D8D8),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (state.activeBooking != null)
            _ActiveBookingCard(
              booking: state.activeBooking!,
              activeQrTicket: state.activeQrTicket,
            ),
          if (state.actionMessage != null) ...[
            _StatusStrip(message: state.actionMessage!),
            const SizedBox(height: 10),
          ],
          if (state.error != null) ...[
            _StatusStrip(message: state.error!, isError: true),
            const SizedBox(height: 10),
          ],
          Text('Nearby parking', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final location in state.locations)
            _LocationTile(
              location: location,
              thumbnail: state.thumbnailByArea[location.id],
              selected: location.id == selected?.id,
              onTap: () {
                controller.selectLocation(location);
              },
            ),
          if (selected != null) ...[
            const SizedBox(height: 12),
            _RouteSummary(routes: state.routes),
            const SizedBox(height: 12),
            _BookingPanel(
              location: selected,
              previewImages: state.previewImages,
              reviews: state.selectedReviews,
              durationHours: state.durationHours,
              onDurationChanged: controller.changeDuration,
              onBook: controller.createBooking,
              onReview: controller.submitReview,
              onReport: controller.reportIssue,
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.message, this.isError = false});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFECEC) : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

class _ActiveBookingCard extends StatelessWidget {
  const _ActiveBookingCard({
    required this.booking,
    required this.activeQrTicket,
  });

  final Booking booking;
  final ActiveQrTicket? activeQrTicket;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFFFF9E2),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            QrImageView(
              data: booking.qrPayload,
              size: 86,
              backgroundColor: Colors.white,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Active QR ticket',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(booking.vehicleNumber),
                  Text(
                    '${formatInr(booking.price)} - ${booking.durationHours} hours',
                  ),
                  Text(
                    activeQrTicket == null
                        ? 'QR waiting for active ticket sync'
                        : 'QR ${activeQrTicket!.status.name} until ${activeQrTicket!.expiresAt.hour.toString().padLeft(2, '0')}:${activeQrTicket!.expiresAt.minute.toString().padLeft(2, '0')}',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationTile extends StatelessWidget {
  const _LocationTile({
    required this.location,
    required this.thumbnail,
    required this.selected,
    required this.onTap,
  });

  final ParkingLocation location;
  final ParkingAreaImage? thumbnail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        selected: selected,
        selectedTileColor: const Color(0xFFFFF4BC),
        tileColor: const Color(0xFFF8F8F8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 52,
            height: 52,
            child: thumbnail == null
                ? ColoredBox(
                    color: selected
                        ? ParkHereTheme.yellow
                        : const Color(0xFFEDEDED),
                    child: const Icon(Icons.local_parking),
                  )
                : Image.memory(
                    thumbnail!.thumbnailBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
          ),
        ),
        title: Text(
          location.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${location.availableSpaces}/${location.totalSpaces} slots - ${location.ratingAverage.toStringAsFixed(1)} star - ${location.address}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatInr(location.pricePerHour),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const Text('/hr'),
          ],
        ),
      ),
    );
  }
}

class _RouteSummary extends StatelessWidget {
  const _RouteSummary({required this.routes});

  final List<RouteOption> routes;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: routes
          .map(
            (route) => Chip(
              avatar: Icon(
                route.isBest ? Icons.bolt : Icons.alt_route,
                size: 18,
              ),
              label: Text(
                '${route.name}: ${route.distanceKm} km - ${route.durationMinutes} min',
              ),
            ),
          )
          .toList(),
    );
  }
}

class _BookingPanel extends StatelessWidget {
  const _BookingPanel({
    required this.location,
    required this.previewImages,
    required this.reviews,
    required this.durationHours,
    required this.onDurationChanged,
    required this.onBook,
    required this.onReview,
    required this.onReport,
  });

  final ParkingLocation location;
  final List<ParkingAreaImage> previewImages;
  final List<ParkingReview> reviews;
  final int durationHours;
  final ValueChanged<int> onDurationChanged;
  final Future<void> Function() onBook;
  final Future<void> Function({required int rating, required String comment})
  onReview;
  final Future<void> Function({required String type, required String message})
  onReport;

  @override
  Widget build(BuildContext context) {
    final total = location.pricePerHour * durationHours;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ParkHereTheme.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              location.name,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            if (location.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                location.description,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DarkChip(
                  icon: Icons.star,
                  label:
                      '${location.ratingAverage.toStringAsFixed(1)} (${location.ratingCount})',
                ),
                _DarkChip(
                  icon: Icons.local_parking,
                  label:
                      '${location.availableSpaces}/${location.totalSpaces} slots',
                ),
                _DarkChip(
                  icon: Icons.two_wheeler,
                  label: location.vehicleTypes
                      .map((type) => type.label)
                      .join(', '),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (previewImages.isNotEmpty) ...[
              SizedBox(
                height: 118,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: previewImages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final image = previewImages[index];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        image.previewBytes,
                        width: 180,
                        height: 118,
                        fit: BoxFit.cover,
                        gaplessPlayback: true,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                const Text('Duration', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 12,
                    divisions: 11,
                    value: durationHours.toDouble(),
                    label: '$durationHours hr',
                    onChanged: (value) => onDurationChanged(value.round()),
                  ),
                ),
                Text(
                  '$durationHours hr',
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (reviews.isNotEmpty) ...[
              Text(
                'Recent comments',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              for (final review in reviews.take(2))
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${review.rating}/5 - ${review.comment}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              const SizedBox(height: 6),
            ],
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ParkHereTheme.yellow,
                    foregroundColor: ParkHereTheme.black,
                  ),
                  onPressed: onBook,
                  icon: const Icon(Icons.qr_code_2),
                  label: Text('Book slot - ${formatInr(total)}'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () => _showReviewSheet(context, onReview),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Rate'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                  ),
                  onPressed: () => _showIssueSheet(context, onReport),
                  icon: const Icon(Icons.report_problem_outlined),
                  label: const Text('Report'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showReviewSheet(
    BuildContext context,
    Future<void> Function({required int rating, required String comment})
    onSubmit,
  ) {
    final comment = TextEditingController();
    var rating = 5;
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rate ${location.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 1, label: Text('1')),
                      ButtonSegment(value: 2, label: Text('2')),
                      ButtonSegment(value: 3, label: Text('3')),
                      ButtonSegment(value: 4, label: Text('4')),
                      ButtonSegment(value: 5, label: Text('5')),
                    ],
                    selected: {rating},
                    onSelectionChanged: (value) =>
                        setSheetState(() => rating = value.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: comment,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comment',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      onSubmit(rating: rating, comment: comment.text);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save review'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showIssueSheet(
    BuildContext context,
    Future<void> Function({required String type, required String message})
    onSubmit,
  ) {
    final message = TextEditingController();
    var type = 'availability';
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report ${location.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    items: const [
                      DropdownMenuItem(
                        value: 'availability',
                        child: Text('Availability'),
                      ),
                      DropdownMenuItem(
                        value: 'pricing',
                        child: Text('Pricing'),
                      ),
                      DropdownMenuItem(value: 'access', child: Text('Access')),
                      DropdownMenuItem(value: 'safety', child: Text('Safety')),
                    ],
                    onChanged: (value) =>
                        setSheetState(() => type = value ?? type),
                    decoration: const InputDecoration(
                      labelText: 'Issue type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: message,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      onSubmit(type: type, message: message.text);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.send_outlined),
                    label: const Text('Send issue'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _DarkChip extends StatelessWidget {
  const _DarkChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                style: const TextStyle(color: Colors.white),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
