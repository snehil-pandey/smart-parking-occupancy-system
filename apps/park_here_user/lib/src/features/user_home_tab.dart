import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:park_here_shared/park_here_shared.dart';

import '../user_app_controller.dart';
import '../widgets/park_here_loading.dart';
import '../widgets/user_status_strip.dart';

class UserHomeTab extends StatelessWidget {
  const UserHomeTab({required this.state, required this.controller, super.key});

  final UserAppState state;
  final UserAppController controller;

  @override
  Widget build(BuildContext context) {
    final visibleLocations = state.visibleLocations;
    return Stack(
      children: [
        Positioned.fill(
          child: InteractiveParkingMap(
            locations: visibleLocations,
            selectedLocation: state.selectedLocation,
            selectedPlace: state.selectedPlace,
            routes: state.routes,
            selectedRouteId: state.selectedRoute?.id,
            position: state.position,
            isRouteLoading: state.isRouteLoading,
            onSelect: controller.selectLocation,
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          top: 14,
          child: _HomeSearchHeader(state: state, controller: controller),
        ),
        if (state.locations.isEmpty && state.error == null)
          const Positioned(
            left: 16,
            right: 16,
            top: 118,
            child: Center(
              child: InlineParkHereLoading(
                message: 'Loading live parking data...',
              ),
            ),
          ),
        DraggableScrollableSheet(
          initialChildSize: state.selectedLocation == null ? 0.34 : 0.42,
          minChildSize: 0.18,
          maxChildSize: 0.82,
          builder: (context, scrollController) {
            return _ParkingDiscoverySheet(
              state: state,
              controller: controller,
              locations: visibleLocations,
              scrollController: scrollController,
            );
          },
        ),
      ],
    );
  }
}

class _HomeSearchHeader extends StatefulWidget {
  const _HomeSearchHeader({required this.state, required this.controller});

  final UserAppState state;
  final UserAppController controller;

  @override
  State<_HomeSearchHeader> createState() => _HomeSearchHeaderState();
}

class _HomeSearchHeaderState extends State<_HomeSearchHeader> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _search = TextEditingController(text: widget.state.searchQuery);
  }

  @override
  void didUpdateWidget(covariant _HomeSearchHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.searchQuery != _search.text) {
      _search.text = widget.state.searchQuery;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.state.user;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi ${user?.name.split(' ').first ?? 'there'}, find parking',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: ParkHereTheme.black,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withAlpha(22),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _search,
                        onChanged: widget.controller.updateSearchQuery,
                        decoration: const InputDecoration(
                          hintText: 'Search SIT places or parking areas',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (_search.text.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear search',
                        onPressed: () {
                          _search.clear();
                          widget.controller.clearSearch();
                        },
                        icon: const Icon(Icons.close),
                      )
                    else
                      IconButton(
                        tooltip: 'Retry live updates',
                        onPressed: widget.state.isRefreshingData
                            ? null
                            : widget.controller.retryRealtime,
                        icon: widget.state.isRefreshingData
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.sync),
                      ),
                  ],
                ),
              ),
              if (widget.state.searchResults.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: widget.state.searchResults.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final result = widget.state.searchResults[index];
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          result.parkingAreaId == null
                              ? Icons.place_outlined
                              : Icons.local_parking,
                        ),
                        title: Text(result.title),
                        subtitle: Text(result.subtitle),
                        onTap: () =>
                            widget.controller.selectSearchResult(result),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _QuickFilters(
          selected: widget.state.parkingFilter,
          onSelected: widget.controller.changeFilter,
        ),
      ],
    );
  }
}

class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.selected, required this.onSelected});

  final ParkingFilter selected;
  final ValueChanged<ParkingFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      (ParkingFilter.all, 'All', Icons.layers_outlined),
      (ParkingFilter.openNow, 'Open', Icons.check_circle_outline),
      (ParkingFilter.nearest, 'Nearest', Icons.near_me_outlined),
      (ParkingFilter.free, 'Free', Icons.money_off_outlined),
      (ParkingFilter.topRated, 'Top rated', Icons.star_outline),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                selected: selected == item.$1,
                avatar: Icon(item.$3, size: 16),
                label: Text(item.$2),
                onSelected: (_) => onSelected(item.$1),
              ),
            ),
        ],
      ),
    );
  }
}

class InteractiveParkingMap extends StatefulWidget {
  const InteractiveParkingMap({
    required this.locations,
    required this.selectedLocation,
    required this.selectedPlace,
    required this.routes,
    required this.selectedRouteId,
    required this.position,
    required this.isRouteLoading,
    required this.onSelect,
    super.key,
  });

  final List<ParkingLocation> locations;
  final ParkingLocation? selectedLocation;
  final PlaceSearchResult? selectedPlace;
  final List<RouteOption> routes;
  final String? selectedRouteId;
  final UserPosition? position;
  final bool isRouteLoading;
  final ValueChanged<ParkingLocation> onSelect;

  @override
  State<InteractiveParkingMap> createState() => _InteractiveParkingMapState();
}

class _InteractiveParkingMapState extends State<InteractiveParkingMap>
    with SingleTickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _animationController;
  Animation<LatLng>? _centerAnimation;
  Animation<double>? _zoomAnimation;
  bool _tileError = false;
  String? _polygonSignature;
  List<Polygon>? _polygonCache;
  String? _polylineSignature;
  List<Polyline>? _polylineCache;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _animationController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 420),
        )..addListener(() {
          final center = _centerAnimation?.value;
          final zoom = _zoomAnimation?.value;
          if (center != null && zoom != null) {
            _mapController.move(center, zoom);
          }
        });
  }

  @override
  void didUpdateWidget(covariant InteractiveParkingMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedLocation?.id != oldWidget.selectedLocation?.id ||
        widget.selectedPlace?.id != oldWidget.selectedPlace?.id ||
        _routeSignature(selectedRoute) !=
            _routeSignature(_selectedRouteFor(oldWidget))) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusSelected());
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _selectedLatLng() ?? _currentLatLng(),
            initialZoom: 17,
            minZoom: 13,
            maxZoom: 20,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            // Tile layer: real OpenStreetMap raster tiles. No Google Maps API
            // key or billing account is required for local development.
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.parkhere.user',
              errorTileCallback: (_, _, _) {
                if (mounted && !_tileError) {
                  setState(() => _tileError = true);
                }
              },
            ),
            _ParkingPolygonLayer(polygons: _parkingPolygons()),
            _RouteGeometryLayer(polylines: _routePolylines()),
            // Marker layer: GPS, parking centers, gate points, and search pins.
            MarkerLayer(markers: _markers()),
          ],
        ),
        if (_tileError)
          Positioned(
            left: 16,
            right: 16,
            top: 132,
            child: StatusStrip(
              message:
                  'Map tiles are unavailable. Check internet access and retry.',
              isError: true,
            ),
          ),
        if (widget.isRouteLoading)
          const Positioned(
            left: 16,
            right: 16,
            top: 132,
            child: Center(
              child: InlineParkHereLoading(message: 'Calculating route...'),
            ),
          ),
        Positioned(
          right: 14,
          bottom: 170,
          child: Column(
            children: [
              _MapRoundButton(
                icon: Icons.add,
                tooltip: 'Zoom in',
                onPressed: () => _zoomBy(1),
              ),
              const SizedBox(height: 8),
              _MapRoundButton(
                icon: Icons.remove,
                tooltip: 'Zoom out',
                onPressed: () => _zoomBy(-1),
              ),
              const SizedBox(height: 8),
              _MapRoundButton(
                icon: Icons.my_location,
                tooltip: 'Focus current location',
                onPressed: _focusCurrentLocation,
              ),
            ],
          ),
        ),
        Positioned(
          left: 16,
          bottom: 176,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(236),
              borderRadius: BorderRadius.circular(8),
              boxShadow: const [
                BoxShadow(color: Color(0x22000000), blurRadius: 10),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.polyline_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    widget.routes.isEmpty
                        ? 'Road route unavailable'
                        : selectedRoute?.isFallback == true
                        ? 'Fallback campus road graph'
                        : '${widget.routes.length} road route option${widget.routes.length == 1 ? '' : 's'}',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Polygon> _parkingPolygons() {
    final signature = widget.locations
        .map(
          (location) =>
              '${location.id}:${location.boundaryPoints.length}:${location.isBookable}:${location.id == widget.selectedLocation?.id}',
        )
        .join('|');
    if (_polygonSignature == signature && _polygonCache != null) {
      return _polygonCache!;
    }
    _polygonSignature = signature;
    _polygonCache = [
      for (final location in widget.locations)
        if (location.boundaryPoints.length >= 3)
          Polygon(
            points: location.boundaryPoints
                .map((point) => LatLng(point.latitude, point.longitude))
                .toList(),
            color: location.id == widget.selectedLocation?.id
                ? ParkHereTheme.yellow.withAlpha(110)
                : location.isBookable
                ? const Color(0xFF2E7D32).withAlpha(74)
                : Colors.grey.withAlpha(88),
            borderColor: location.id == widget.selectedLocation?.id
                ? ParkHereTheme.black
                : location.isBookable
                ? const Color(0xFF2E7D32)
                : Colors.grey,
            borderStrokeWidth: location.id == widget.selectedLocation?.id
                ? 3
                : 2,
          ),
    ];
    return _polygonCache!;
  }

  List<Polyline> _routePolylines() {
    final signature =
        '${widget.selectedRouteId}:${widget.routes.map(_routeSignature).join('|')}';
    if (_polylineSignature == signature && _polylineCache != null) {
      return _polylineCache!;
    }
    _polylineSignature = signature;
    _polylineCache = [
      for (final route in widget.routes)
        Polyline(
          points: route.points
              .map((point) => LatLng(point.latitude, point.longitude))
              .toList(),
          color: route.id == selectedRoute?.id
              ? ParkHereTheme.black
              : const Color(0xFF5C6BC0).withAlpha(150),
          strokeWidth: route.id == selectedRoute?.id ? 5 : 3,
        ),
    ];
    return _polylineCache!;
  }

  List<Marker> _markers() => [
    if (widget.position != null)
      Marker(
        point: _currentLatLng(),
        width: 44,
        height: 44,
        child: const _CurrentLocationMarker(),
      ),
    for (final location in widget.locations)
      Marker(
        point: _latLngForLocation(location),
        width: 54,
        height: 54,
        child: _ParkingMapMarker(
          location: location,
          selected: location.id == widget.selectedLocation?.id,
          onTap: () => widget.onSelect(location),
        ),
      ),
    for (final location in widget.locations)
      for (final gate in location.gatePoints)
        Marker(
          point: LatLng(gate.latitude, gate.longitude),
          width: 28,
          height: 28,
          child: Tooltip(
            message: gate.name,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.login, size: 18, color: Color(0xFF3949AB)),
            ),
          ),
        ),
    if (widget.selectedPlace != null)
      Marker(
        point: LatLng(
          widget.selectedPlace!.latitude,
          widget.selectedPlace!.longitude,
        ),
        width: 42,
        height: 42,
        child: const Icon(
          Icons.location_pin,
          color: Color(0xFFD32F2F),
          size: 40,
        ),
      ),
  ];

  void _zoomBy(double delta) {
    _mapController.move(
      _mapController.camera.center,
      (_mapController.camera.zoom + delta).clamp(13, 20),
    );
  }

  void _focusCurrentLocation() {
    if (widget.position == null) {
      return;
    }
    _animateTo(_currentLatLng(), zoom: 18);
  }

  void _focusSelected() {
    final route = selectedRoute;
    if (route != null && route.points.length >= 2) {
      _fitRoute(route);
      return;
    }
    final selected = widget.selectedLocation;
    if (selected != null) {
      _animateTo(_latLngForLocation(selected), zoom: 18);
      return;
    }
    final place = widget.selectedPlace;
    if (place != null) {
      _animateTo(LatLng(place.latitude, place.longitude), zoom: 18);
    }
  }

  void _animateTo(LatLng target, {double zoom = 17.5}) {
    if (!mounted) {
      return;
    }
    _centerAnimation =
        _LatLngTween(begin: _mapController.camera.center, end: target).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _zoomAnimation = Tween<double>(begin: _mapController.camera.zoom, end: zoom)
        .animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );
    _animationController.forward(from: 0);
  }

  void _fitRoute(RouteOption route) {
    final points = route.points
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
    if (points.length < 2) {
      return;
    }
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(points),
        padding: const EdgeInsets.fromLTRB(42, 180, 42, 260),
      ),
    );
  }

  LatLng _latLngForLocation(ParkingLocation location) =>
      LatLng(location.latitude, location.longitude);

  LatLng _currentLatLng() => LatLng(
    widget.position?.latitude ?? 13.3281211,
    widget.position?.longitude ?? 77.1256930,
  );

  LatLng? _selectedLatLng() {
    final selected = widget.selectedLocation;
    if (selected != null) {
      return _latLngForLocation(selected);
    }
    final place = widget.selectedPlace;
    if (place != null) {
      return LatLng(place.latitude, place.longitude);
    }
    return null;
  }

  RouteOption? get selectedRoute =>
      widget.routes
          .where((route) => route.id == widget.selectedRouteId)
          .firstOrNull ??
      widget.routes.where((route) => route.isBest).firstOrNull ??
      widget.routes.firstOrNull;

  RouteOption? _selectedRouteFor(InteractiveParkingMap value) =>
      value.routes
          .where((route) => route.id == value.selectedRouteId)
          .firstOrNull ??
      value.routes.where((route) => route.isBest).firstOrNull ??
      value.routes.firstOrNull;

  String _routeSignature(RouteOption? route) {
    if (route == null) {
      return '';
    }
    return '${route.id}:${route.points.length}:${route.distanceKm}:${route.durationMinutes}';
  }
}

class _LatLngTween extends Tween<LatLng> {
  _LatLngTween({required super.begin, required super.end});

  @override
  LatLng lerp(double t) => LatLng(
    begin!.latitude + (end!.latitude - begin!.latitude) * t,
    begin!.longitude + (end!.longitude - begin!.longitude) * t,
  );
}

class _ParkingPolygonLayer extends StatelessWidget {
  const _ParkingPolygonLayer({required this.polygons});

  final List<Polygon> polygons;

  @override
  Widget build(BuildContext context) {
    return PolygonLayer(polygons: polygons);
  }
}

class _RouteGeometryLayer extends StatelessWidget {
  const _RouteGeometryLayer({required this.polylines});

  final List<Polyline> polylines;

  @override
  Widget build(BuildContext context) {
    return PolylineLayer(polylines: polylines);
  }
}

class _ParkingDiscoverySheet extends StatelessWidget {
  const _ParkingDiscoverySheet({
    required this.state,
    required this.controller,
    required this.locations,
    required this.scrollController,
  });

  final UserAppState state;
  final UserAppController controller;
  final List<ParkingLocation> locations;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 18)],
      ),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
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
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Nearby parking',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text('${locations.length} areas'),
            ],
          ),
          if (state.error != null) ...[
            const SizedBox(height: 10),
            StatusStrip(message: state.error!, isError: true),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: state.isRefreshingData
                    ? null
                    : controller.retryRealtime,
                icon: state.isRefreshingData
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.sync),
                label: Text(
                  state.isRefreshingData ? 'Retrying live data' : 'Retry',
                ),
              ),
            ),
          ],
          if (state.isRefreshingData && state.error == null) ...[
            const SizedBox(height: 10),
            const StatusStrip(
              message: 'Reconnecting to live parking updates...',
              isError: false,
            ),
          ],
          if (state.position != null) ...[
            const SizedBox(height: 8),
            StatusStrip(
              message: state.position!.message,
              isError: state.position!.isFallback,
            ),
          ],
          if (state.selectedLocation != null) ...[
            const SizedBox(height: 12),
            _SelectedAreaSummary(state: state, controller: controller),
          ],
          const SizedBox(height: 12),
          if (locations.isEmpty)
            const _EmptyParkingState()
          else
            for (final location in locations)
              ParkingAreaCard(
                location: location,
                thumbnail: state.thumbnailByArea[location.id],
                distanceKm: state.distanceKmFor(location),
                selected: location.id == state.selectedLocation?.id,
                onTap: () => controller.selectLocation(location),
                onDetails: () => _openDetails(context, location),
              ),
        ],
      ),
    );
  }

  void _openDetails(BuildContext context, ParkingLocation location) {
    controller.selectLocation(location);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ParkingAreaDetailScreen(areaId: location.id),
      ),
    );
  }
}

class ParkingAreaCard extends StatelessWidget {
  const ParkingAreaCard({
    required this.location,
    required this.thumbnail,
    required this.distanceKm,
    required this.selected,
    required this.onTap,
    required this.onDetails,
    super.key,
  });

  final ParkingLocation location;
  final ParkingAreaImage? thumbnail;
  final double? distanceKm;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    final disabled = !location.isBookable;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: disabled ? const Color(0xFFEAEAEA) : Colors.white,
        elevation: selected ? 4 : 1,
        shadowColor: Colors.black.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 64,
                    height: 64,
                    child: thumbnail == null
                        ? ColoredBox(
                            color: selected
                                ? ParkHereTheme.yellow
                                : const Color(0xFFEDEDED),
                            child: Icon(
                              disabled ? Icons.block : Icons.local_parking,
                            ),
                          )
                        : Image.memory(
                            thumbnail!.thumbnailBytes,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              location.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (disabled)
                            _StatePill(
                              label: location.isOpen ? 'Full' : 'Closed',
                              isError: true,
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${location.availabilityLabel} - ${distanceKm == null ? 'distance pending' : '${distanceKm!.toStringAsFixed(1)} km'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Colors.amber[800]),
                          const SizedBox(width: 4),
                          Text(location.ratingAverage.toStringAsFixed(1)),
                          const SizedBox(width: 10),
                          Text(formatParkingRate(location.pricePerHour)),
                          const Spacer(),
                          TextButton(
                            onPressed: onDetails,
                            child: const Text('Details'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedAreaSummary extends StatelessWidget {
  const _SelectedAreaSummary({required this.state, required this.controller});

  final UserAppState state;
  final UserAppController controller;

  @override
  Widget build(BuildContext context) {
    final location = state.selectedLocation!;
    final best = state.selectedRoute;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ParkHereTheme.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    location.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                _StatePill(
                  label: location.availabilityLabel,
                  isError: !location.isBookable,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DarkChip(
                  icon: Icons.payments_outlined,
                  label: formatParkingRate(location.pricePerHour),
                ),
                _DarkChip(
                  icon: Icons.star,
                  label:
                      '${location.ratingAverage.toStringAsFixed(1)} (${location.ratingCount})',
                ),
                if (best != null)
                  _DarkChip(
                    icon: Icons.route,
                    label:
                        '${best.distanceKm} km - ${best.durationMinutes} min',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ParkingAreaDetailScreen(areaId: location.id),
                      ),
                    ),
                    icon: const Icon(Icons.info_outline),
                    label: const Text('Details'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: ParkHereTheme.yellow,
                      foregroundColor: ParkHereTheme.black,
                    ),
                    onPressed: location.isBookable
                        ? state.isBookingInProgress
                              ? null
                              : controller.createBooking
                        : null,
                    icon: state.isBookingInProgress
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_2),
                    label: Text(
                      state.isBookingInProgress
                          ? 'Booking...'
                          : location.isBookable
                          ? 'Book'
                          : 'Unavailable',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ParkingAreaDetailScreen extends ConsumerWidget {
  const ParkingAreaDetailScreen({required this.areaId, super.key});

  final String areaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(userAppControllerProvider);
    final controller = ref.read(userAppControllerProvider.notifier);
    final location = state.selectedLocation?.id == areaId
        ? state.selectedLocation
        : state.locations
              .where((location) => location.id == areaId)
              .firstOrNull;
    if (location == null) {
      return const Scaffold(body: Center(child: Text('No parking selected.')));
    }
    final total = location.pricePerHour * state.durationHours;
    return Scaffold(
      appBar: AppBar(title: Text(location.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DetailImageCarousel(images: state.previewImages),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  location.name,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              _StatePill(
                label: location.isBookable
                    ? location.availabilityLabel
                    : location.isOpen
                    ? 'Full'
                    : 'Closed',
                isError: !location.isBookable,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            location.description.isEmpty
                ? location.address
                : location.description,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.payments_outlined),
                label: Text(formatParkingRate(location.pricePerHour)),
              ),
              Chip(
                avatar: const Icon(Icons.local_parking),
                label: Text(
                  '${location.availableSpaces}/${location.totalSpaces} slots',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.star),
                label: Text(
                  '${location.ratingAverage.toStringAsFixed(1)} (${location.ratingCount})',
                ),
              ),
              Chip(
                avatar: const Icon(Icons.two_wheeler),
                label: Text(
                  location.vehicleTypes.map((type) => type.label).join(', '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.routes.isNotEmpty) ...[
            Text(
              'Route options',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final route in state.routes)
              ListTile(
                contentPadding: EdgeInsets.zero,
                selected: route.id == state.selectedRoute?.id,
                leading: Icon(
                  route.id == state.selectedRoute?.id
                      ? Icons.bolt
                      : Icons.alt_route,
                ),
                title: Text(route.name),
                subtitle: Text(
                  '${route.distanceKm} km - ${route.durationMinutes} min'
                  '${route.destinationLabel == null ? '' : ' to ${route.destinationLabel}'}'
                  '${route.isFallback ? ' - fallback' : ''}',
                ),
                onTap: () => controller.selectRoute(route.id),
              ),
          ],
          if (location.gatePoints.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Entry points',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final gate in location.gatePoints)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login),
                title: Text(gate.name),
                subtitle: Text(gate.type.name),
              ),
          ],
          const SizedBox(height: 10),
          Text('Duration', style: Theme.of(context).textTheme.titleMedium),
          Slider(
            min: 1,
            max: 12,
            divisions: 11,
            value: state.durationHours.toDouble(),
            label: '${state.durationHours} hr',
            onChanged: (value) => controller.changeDuration(value.round()),
          ),
          Text('${state.durationHours} hours - Total ${formatInr(total)}'),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: location.isBookable
                ? state.isBookingInProgress
                      ? null
                      : controller.createBooking
                : null,
            icon: state.isBookingInProgress
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.qr_code_2),
            label: Text(
              state.isBookingInProgress
                  ? 'Booking...'
                  : location.isBookable
                  ? 'Book now'
                  : location.availabilityLabel,
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () => _showReviewSheet(context, location, controller),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('Rate and comment'),
          ),
          OutlinedButton.icon(
            onPressed: () => _showIssueSheet(context, location, controller),
            icon: const Icon(Icons.report_problem_outlined),
            label: const Text('Report issue'),
          ),
          if (state.selectedReviews.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text('Comments', style: Theme.of(context).textTheme.titleMedium),
            for (final review in state.selectedReviews)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.star_outline),
                title: Text('${review.rating}/5'),
                subtitle: Text(review.comment),
              ),
          ],
        ],
      ),
    );
  }

  void _showReviewSheet(
    BuildContext context,
    ParkingLocation location,
    UserAppController controller,
  ) {
    final comment = TextEditingController();
    var rating = 5;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
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
                    controller.submitReview(
                      rating: rating,
                      comment: comment.text,
                    );
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save review'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showIssueSheet(
    BuildContext context,
    ParkingLocation location,
    UserAppController controller,
  ) {
    final message = TextEditingController();
    var type = 'availability';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
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
                    DropdownMenuItem(value: 'pricing', child: Text('Pricing')),
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
                    controller.reportIssue(type: type, message: message.text);
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send issue'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailImageCarousel extends StatelessWidget {
  const _DetailImageCarousel({required this.images});

  final List<ParkingAreaImage> images;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFEDEDED),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(child: Icon(Icons.image_outlined, size: 42)),
        ),
      );
    }
    return SizedBox(
      height: 190,
      child: PageView.builder(
        itemCount: images.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                images[index].previewBytes,
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ParkingMapMarker extends StatelessWidget {
  const _ParkingMapMarker({
    required this.location,
    required this.selected,
    required this.onTap,
  });

  final ParkingLocation location;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = !location.isBookable;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: disabled
              ? const Color(0xFFD5D5D5)
              : selected
              ? ParkHereTheme.yellow
              : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? ParkHereTheme.black : Colors.white,
            width: selected ? 3 : 2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Icon(disabled ? Icons.block : Icons.local_parking, size: 20),
      ),
    );
  }
}

class _CurrentLocationMarker extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF1A73E8),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white, width: 4),
      ),
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: Icon(Icons.navigation, color: Colors.white, size: 18),
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      shape: const CircleBorder(),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon),
      ),
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
            Text(label, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label, this.isError = false});

  final String label;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFECEC) : const Color(0xFFEAF7EE),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isError ? const Color(0xFFB3261E) : const Color(0xFF137333),
          ),
        ),
      ),
    );
  }
}

class _EmptyParkingState extends StatelessWidget {
  const _EmptyParkingState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.local_parking_outlined, size: 42, color: Colors.grey[600]),
          const SizedBox(height: 10),
          Text('No parking areas match this filter.'),
        ],
      ),
    );
  }
}
