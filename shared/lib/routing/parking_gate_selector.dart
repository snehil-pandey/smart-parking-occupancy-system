import '../models/gate_point.dart';
import '../models/parking_location.dart';
import 'route_provider.dart';

class ParkingGateSelector {
  const ParkingGateSelector();

  RoutePoint destinationFor({
    required RoutePoint origin,
    required ParkingLocation location,
  }) {
    final candidates = location.gatePoints
        .where(
          (gate) =>
              gate.type == GatePointType.entry ||
              gate.type == GatePointType.both,
        )
        .toList();
    if (candidates.isEmpty) {
      return RoutePoint(
        id: '${location.id}_center',
        label: '${location.name} center',
        latitude: location.latitude,
        longitude: location.longitude,
      );
    }
    candidates.sort(
      (a, b) => _distanceScore(origin, a).compareTo(_distanceScore(origin, b)),
    );
    final gate = candidates.first;
    return RoutePoint(
      id: gate.gateId,
      label: gate.name.isEmpty ? '${location.name} gate' : gate.name,
      latitude: gate.latitude,
      longitude: gate.longitude,
    );
  }

  double _distanceScore(RoutePoint origin, GatePoint gate) {
    final lat = origin.latitude - gate.latitude;
    final lon = origin.longitude - gate.longitude;
    return lat * lat + lon * lon;
  }
}
