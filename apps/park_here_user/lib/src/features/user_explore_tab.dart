import 'package:flutter/material.dart';
import 'package:park_here_shared/park_here_shared.dart';

import '../user_app_controller.dart';
import 'user_home_tab.dart';

class UserExploreTab extends StatelessWidget {
  const UserExploreTab({
    required this.state,
    required this.controller,
    super.key,
  });

  final UserAppState state;
  final UserAppController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Explore', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 6),
        const Text('Realtime parking picks from Firebase, sorted around you.'),
        const SizedBox(height: 18),
        _Section(
          title: 'Nearby available',
          locations: state.nearbyAvailableLocations.take(6).toList(),
          state: state,
          controller: controller,
          emptyText: 'No open parking areas with free slots right now.',
        ),
        _Section(
          title: 'Recently used',
          locations: state.recentlyUsedLocations.take(4).toList(),
          state: state,
          controller: controller,
          emptyText: 'Your recent parking areas will appear here.',
        ),
        _Section(
          title: 'Free parking',
          locations: state.freeLocations
              .where((location) => location.isBookable)
              .take(4)
              .toList(),
          state: state,
          controller: controller,
          emptyText: 'No free parking areas are available right now.',
        ),
        _Section(
          title: 'Cheapest parking',
          locations: state.cheapestLocations
              .where((location) => location.isBookable)
              .take(4)
              .toList(),
          state: state,
          controller: controller,
        ),
        _Section(
          title: 'Top rated',
          locations: state.topRatedLocations
              .where((location) => location.isBookable)
              .take(4)
              .toList(),
          state: state,
          controller: controller,
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.locations,
    required this.state,
    required this.controller,
    this.emptyText = 'No matching parking areas yet.',
  });

  final String title;
  final List<ParkingLocation> locations;
  final UserAppState state;
  final UserAppController controller;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          if (locations.isEmpty)
            Text(emptyText)
          else
            for (final location in locations)
              ParkingAreaCard(
                location: location,
                thumbnail: state.thumbnailByArea[location.id],
                distanceKm: state.distanceKmFor(location),
                selected: location.id == state.selectedLocation?.id,
                onTap: () {
                  controller.selectLocation(location);
                  controller.changeTab(UserTab.home);
                },
                onDetails: () {
                  controller.selectLocation(location);
                  controller.changeTab(UserTab.home);
                },
              ),
        ],
      ),
    );
  }
}
