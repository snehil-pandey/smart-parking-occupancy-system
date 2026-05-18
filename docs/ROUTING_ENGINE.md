# Routing Engine

Park Here keeps routing behind a `RouteProvider` interface. The UI asks for route options; it does not know whether those routes came from a local graph, Google Maps, OSRM, or another provider.

## Dijkstra Simply

A route graph has:

- **Nodes**: places or intersections.
- **Edges**: roads between nodes.
- **Weights**: cost to travel an edge, usually distance or time.

Dijkstra's algorithm starts at the origin, repeatedly picks the cheapest known next node, and relaxes its neighbors until it reaches the destination. The result is the lowest-weight path.

## In This MVP

`DijkstraRouteEngine` receives demo nodes and edges from `DemoSeed.routeEngine()`. When the driver selects a parking area, the user app:

1. Creates an origin point for the driver.
2. Creates a destination point from the parking area's center point.
3. Calls `RouteProvider.findRoutes`.
4. Shows the shortest route and an alternate route when available.

## Region-Aware Routing

The SIT Tumkur region is an admin organization boundary, not a user destination. Routing should only target `parking_areas/{areaId}` center points or future entrance nodes. When real maps are added, keep the provider behind `RouteProvider` and prefer these inputs:

- origin: user GPS/current map pin
- destination: selected parking area entry point or center
- alternatives: shortest, fastest, and least congested when provider data allows

The local Dijkstra fallback remains useful for demos, offline testing, and explaining the shortest-route choice without tying the UI to any paid routing API.

## Replacing With Real Routing

Production routing should keep the same contract:

```dart
abstract interface class RouteProvider {
  Future<List<RouteOption>> findRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
  });
}
```

The user app already renders real OpenStreetMap tiles. A Google/OSRM/OpenRouteService routing provider can call an API, map its response into `RouteOption`, and leave the UI untouched.
