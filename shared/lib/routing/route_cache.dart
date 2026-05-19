import 'route_provider.dart';

class RouteCache {
  RouteCache({this.maxEntries = 40, this.ttl = const Duration(minutes: 10)});

  final int maxEntries;
  final Duration ttl;
  final _entries = <String, _RouteCacheEntry>{};

  List<RouteOption>? get({
    required RoutePoint origin,
    required RoutePoint destination,
    required RouteProfile profile,
  }) {
    final key = _key(
      origin: origin,
      destination: destination,
      profile: profile,
    );
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }
    if (DateTime.now().difference(entry.createdAt) > ttl) {
      _entries.remove(key);
      return null;
    }
    return entry.routes;
  }

  void put({
    required RoutePoint origin,
    required RoutePoint destination,
    required RouteProfile profile,
    required List<RouteOption> routes,
  }) {
    final key = _key(
      origin: origin,
      destination: destination,
      profile: profile,
    );
    if (_entries.length >= maxEntries && !_entries.containsKey(key)) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = _RouteCacheEntry(routes, DateTime.now());
  }

  String _key({
    required RoutePoint origin,
    required RoutePoint destination,
    required RouteProfile profile,
  }) {
    return [
      profile.name,
      _rounded(origin.latitude),
      _rounded(origin.longitude),
      _rounded(destination.latitude),
      _rounded(destination.longitude),
    ].join('|');
  }

  String _rounded(double value) => value.toStringAsFixed(5);
}

class _RouteCacheEntry {
  const _RouteCacheEntry(this.routes, this.createdAt);

  final List<RouteOption> routes;
  final DateTime createdAt;
}
