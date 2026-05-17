import 'dart:convert';

import 'package:park_here_shared/utils/demo_seed.dart';

void main() {
  final bookings = DemoSeed.bookings();
  final payload = {
    'parking_locations': {
      for (final location in DemoSeed.parkingLocations)
        location.id: location.toJson(),
    },
    'bookings': {for (final booking in bookings) booking.id: booking.toJson()},
  };

  const encoder = JsonEncoder.withIndent('  ');
  print(encoder.convert(payload));
}
