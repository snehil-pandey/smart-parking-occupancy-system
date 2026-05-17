import 'dart:math';

import 'route_provider.dart';

class GraphEdge {
  const GraphEdge(this.to, this.weightKm);

  final String to;
  final double weightKm;
}

class DijkstraRouteEngine implements RouteProvider {
  DijkstraRouteEngine({
    required Map<String, RoutePoint> nodes,
    required Map<String, List<GraphEdge>> edges,
  }) : _nodes = nodes,
       _edges = edges;

  final Map<String, RoutePoint> _nodes;
  final Map<String, List<GraphEdge>> _edges;

  @override
  Future<List<RouteOption>> findRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
  }) async {
    final nodes = {..._nodes, origin.id: origin, destination.id: destination};
    final edges = _withTemporaryEdges(origin, destination);
    final bestPath = _shortestPath(origin.id, destination.id, edges);
    final bestDistance = _pathDistance(bestPath, edges);

    final alternatives = <RouteOption>[
      _optionFromPath(
        id: 'route_best',
        name: 'Shortest route',
        path: bestPath,
        nodes: nodes,
        distanceKm: bestDistance,
        isBest: true,
      ),
    ];

    if (bestPath.length > 2) {
      final blocked = bestPath[1];
      final alternateEdges = Map<String, List<GraphEdge>>.from(edges);
      alternateEdges[origin.id] = (alternateEdges[origin.id] ?? [])
          .where((edge) => edge.to != blocked)
          .toList();
      final alternatePath = _shortestPath(
        origin.id,
        destination.id,
        alternateEdges,
      );
      if (alternatePath.isNotEmpty) {
        alternatives.add(
          _optionFromPath(
            id: 'route_alt',
            name: 'Alternative route',
            path: alternatePath,
            nodes: nodes,
            distanceKm: _pathDistance(alternatePath, alternateEdges),
            isBest: false,
          ),
        );
      }
    }

    return alternatives;
  }

  Map<String, List<GraphEdge>> _withTemporaryEdges(
    RoutePoint origin,
    RoutePoint destination,
  ) {
    final edges = <String, List<GraphEdge>>{
      for (final entry in _edges.entries) entry.key: [...entry.value],
    };
    for (final node in _nodes.values) {
      final originDistance = _distance(origin, node);
      final destinationDistance = _distance(destination, node);
      edges
          .putIfAbsent(origin.id, () => [])
          .add(GraphEdge(node.id, originDistance));
      edges
          .putIfAbsent(node.id, () => [])
          .add(GraphEdge(destination.id, destinationDistance));
      edges
          .putIfAbsent(node.id, () => [])
          .add(GraphEdge(origin.id, originDistance));
    }
    return edges;
  }

  List<String> _shortestPath(
    String start,
    String target,
    Map<String, List<GraphEdge>> edges,
  ) {
    final distances = <String, double>{start: 0};
    final previous = <String, String>{};
    final queue = <_QueueNode>[_QueueNode(start, 0)];

    while (queue.isNotEmpty) {
      queue.sort((a, b) => a.distance.compareTo(b.distance));
      final current = queue.removeAt(0);
      if (current.id == target) {
        break;
      }
      for (final edge in edges[current.id] ?? const <GraphEdge>[]) {
        final nextDistance = current.distance + edge.weightKm;
        if (nextDistance < (distances[edge.to] ?? double.infinity)) {
          distances[edge.to] = nextDistance;
          previous[edge.to] = current.id;
          queue.add(_QueueNode(edge.to, nextDistance));
        }
      }
    }

    if (!distances.containsKey(target)) {
      return const [];
    }
    final path = <String>[target];
    while (path.last != start) {
      path.add(previous[path.last]!);
    }
    return path.reversed.toList();
  }

  double _pathDistance(List<String> path, Map<String, List<GraphEdge>> edges) {
    var distance = 0.0;
    for (var index = 0; index < path.length - 1; index++) {
      final from = path[index];
      final to = path[index + 1];
      distance += edges[from]!.firstWhere((edge) => edge.to == to).weightKm;
    }
    return distance;
  }

  RouteOption _optionFromPath({
    required String id,
    required String name,
    required List<String> path,
    required Map<String, RoutePoint> nodes,
    required double distanceKm,
    required bool isBest,
  }) {
    return RouteOption(
      id: id,
      name: name,
      points: path.map((id) => nodes[id]!).toList(),
      distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
      durationMinutes: max(3, (distanceKm / 18 * 60).round()),
      isBest: isBest,
    );
  }

  double _distance(RoutePoint a, RoutePoint b) {
    final lat = (a.latitude - b.latitude) * 111;
    final lon = (a.longitude - b.longitude) * 111 * cos(a.latitude * pi / 180);
    return sqrt(lat * lat + lon * lon);
  }
}

class _QueueNode {
  const _QueueNode(this.id, this.distance);

  final String id;
  final double distance;
}
