import 'dijkstra_route_engine.dart';
import 'route_provider.dart';

class SitTumkurRoadGraphRouteProvider extends DijkstraRouteEngine {
  SitTumkurRoadGraphRouteProvider()
    : super(nodes: _nodes, edges: _bidirectionalEdges(_edgePairs));

  static final _nodes = <String, RoutePoint>{
    'sit_main_gate': const RoutePoint(
      id: 'sit_main_gate',
      label: 'SIT Main Gate road node',
      latitude: 13.32916,
      longitude: 77.12502,
    ),
    'sit_admin_road': const RoutePoint(
      id: 'sit_admin_road',
      label: 'Admin Block road',
      latitude: 13.32873,
      longitude: 77.12558,
    ),
    'sit_library_road': const RoutePoint(
      id: 'sit_library_road',
      label: 'Library road',
      latitude: 13.32818,
      longitude: 77.1261,
    ),
    'sit_academic_road': const RoutePoint(
      id: 'sit_academic_road',
      label: 'Academic Block road',
      latitude: 13.32774,
      longitude: 77.12652,
    ),
    'sit_auditorium_road': const RoutePoint(
      id: 'sit_auditorium_road',
      label: 'Auditorium road',
      latitude: 13.32737,
      longitude: 77.12582,
    ),
    'sit_hostel_road': const RoutePoint(
      id: 'sit_hostel_road',
      label: 'Hostel side road',
      latitude: 13.32686,
      longitude: 77.12496,
    ),
    'sit_sports_road': const RoutePoint(
      id: 'sit_sports_road',
      label: 'Sports ground road',
      latitude: 13.3264,
      longitude: 77.12622,
    ),
  };

  static const _edgePairs = <_EdgePair>[
    _EdgePair('sit_main_gate', 'sit_admin_road', 0.09),
    _EdgePair('sit_admin_road', 'sit_library_road', 0.09),
    _EdgePair('sit_library_road', 'sit_academic_road', 0.08),
    _EdgePair('sit_academic_road', 'sit_auditorium_road', 0.09),
    _EdgePair('sit_auditorium_road', 'sit_hostel_road', 0.12),
    _EdgePair('sit_academic_road', 'sit_sports_road', 0.15),
    _EdgePair('sit_library_road', 'sit_auditorium_road', 0.11),
  ];
}

Map<String, List<GraphEdge>> _bidirectionalEdges(List<_EdgePair> pairs) {
  final edges = <String, List<GraphEdge>>{};
  for (final pair in pairs) {
    edges.putIfAbsent(pair.from, () => []).add(GraphEdge(pair.to, pair.km));
    edges.putIfAbsent(pair.to, () => []).add(GraphEdge(pair.from, pair.km));
  }
  return edges;
}

class _EdgePair {
  const _EdgePair(this.from, this.to, this.km);

  final String from;
  final String to;
  final double km;
}
