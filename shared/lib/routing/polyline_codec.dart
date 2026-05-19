import 'route_provider.dart';

class PolylineCodec {
  const PolylineCodec();

  List<RoutePoint> decode(
    String encoded, {
    String idPrefix = 'polyline',
    String label = 'Route point',
    int precision = 5,
  }) {
    final points = <RoutePoint>[];
    var index = 0;
    var latitude = 0;
    var longitude = 0;
    final factor = _pow10(precision);

    while (index < encoded.length) {
      final latResult = _decodeValue(encoded, index);
      index = latResult.nextIndex;
      latitude += latResult.value;

      final lonResult = _decodeValue(encoded, index);
      index = lonResult.nextIndex;
      longitude += lonResult.value;

      points.add(
        RoutePoint(
          id: '${idPrefix}_${points.length}',
          label: label,
          latitude: latitude / factor,
          longitude: longitude / factor,
        ),
      );
    }

    return points;
  }

  _DecodedValue _decodeValue(String encoded, int startIndex) {
    var result = 0;
    var shift = 0;
    var index = startIndex;
    int byte;
    do {
      if (index >= encoded.length) {
        throw const RoutingException('Invalid encoded route polyline.');
      }
      byte = encoded.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    final value = (result & 1) != 0 ? ~(result >> 1) : result >> 1;
    return _DecodedValue(value, index);
  }

  double _pow10(int precision) {
    var value = 1.0;
    for (var i = 0; i < precision; i++) {
      value *= 10;
    }
    return value;
  }
}

class _DecodedValue {
  const _DecodedValue(this.value, this.nextIndex);

  final int value;
  final int nextIndex;
}
