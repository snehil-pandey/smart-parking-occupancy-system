# Routing Engine

Park Here keeps routing behind a `RouteProvider` interface. The UI asks for route options; it does not know whether those routes came from a local graph, Google Maps, OSRM, or another provider.

## Dijkstra Simply

A route graph has:

- **Nodes**: places or intersections.
- **Edges**: roads between nodes.
- **Weights**: cost to travel an edge, usually distance or time.

Dijkstra’s algorithm starts at the origin, repeatedly picks the cheapest known next node, and relaxes its neighbors until it reaches the destination. The result is the lowest-weight path.

## In This MVP

`DijkstraRouteEngine` receives demo nodes and edges from `DemoSeed.routeEngine()`. When the driver selects a parking location, the user app:

1. Creates an origin point for the driver.
2. Creates a destination point from the parking location.
3. Calls `RouteProvider.findRoutes`.
4. Shows the shortest route and an alternate route when available.

## Replacing With Real Maps

Production routing should keep the same contract:

```dart
abstract interface class RouteProvider {
  Future<List<RouteOption>> findRoutes({
    required RoutePoint origin,
    required RoutePoint destination,
  });
}
```

A Google/OSRM provider can call an API, map its response into `RouteOption`, and leave the UI untouched.

