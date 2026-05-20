part of '../../admin_dashboard_screen.dart';

class _RegionManagementPanel extends StatelessWidget {
  const _RegionManagementPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final region = state.region;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Region Management',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  region.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(region.address),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.center_focus_strong, size: 18),
                      label: Text(
                        '${region.centerLat.toStringAsFixed(6)}, ${region.centerLng.toStringAsFixed(6)}',
                      ),
                    ),
                    Chip(
                      avatar: const Icon(Icons.timeline, size: 18),
                      label: Text(
                        '${region.boundaryPoints.length} polygon points',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _ControlledRegionEditor(state: state, controller: controller),
      ],
    );
  }
}

class _ControlledRegionEditor extends StatefulWidget {
  const _ControlledRegionEditor({
    required this.state,
    required this.controller,
    this.mandatory = false,
  });

  final AdminAppState state;
  final AdminAppController controller;
  final bool mandatory;

  @override
  State<_ControlledRegionEditor> createState() =>
      _ControlledRegionEditorState();
}

class _ControlledRegionEditorState extends State<_ControlledRegionEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.state.region.name,
  );
  late final TextEditingController _address = TextEditingController(
    text: widget.state.region.address,
  );

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final controller = widget.controller;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mandatory
                  ? 'Set up controlled region'
                  : 'Edit controlled region',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              widget.mandatory
                  ? 'Create your region before managing parking areas.'
                  : 'Use Add Point or Move Point mode to update the saved region.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Region name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            _AdminOsmGeometryMap(
              title: 'Region boundary',
              regionPoints: state.regionDraftBoundaryPoints,
              areaPoints: const [],
              gatePoints: const [],
              selectedRegionPoint: state.selectedRegionPoint,
              selectedGeometryPoint: null,
              onMapTap: controller.handleRegionMapTap,
              onRegionPointTap: controller.selectRegionPoint,
            ),
            const SizedBox(height: 12),
            SegmentedButton<AdminRegionEditMode>(
              segments: const [
                ButtonSegment(
                  value: AdminRegionEditMode.addPoint,
                  icon: Icon(Icons.add_location_alt_outlined),
                  label: Text('Add Point'),
                ),
                ButtonSegment(
                  value: AdminRegionEditMode.movePoint,
                  icon: Icon(Icons.open_with_outlined),
                  label: Text('Move Point'),
                ),
              ],
              selected: {state.regionEditMode},
              onSelectionChanged: (selection) =>
                  controller.changeRegionEditMode(selection.first),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.polyline_outlined, size: 18),
                  label: Text(
                    '${state.regionDraftBoundaryPoints.length} points',
                  ),
                ),
                if (state.selectedRegionPoint != null)
                  Chip(
                    avatar: const Icon(Icons.ads_click, size: 18),
                    label: Text('Selected ${state.selectedRegionPoint! + 1}'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              state.regionStatusMessage,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: controller.markCurrentPositionAsRegionPoint,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current GPS'),
                ),
                IconButton.filledTonal(
                  tooltip: 'Undo region edit',
                  onPressed: controller.undoLastRegionChange,
                  icon: const Icon(Icons.undo),
                ),
                OutlinedButton.icon(
                  onPressed: controller.undoLastRegionPoint,
                  icon: const Icon(Icons.backspace_outlined),
                  label: const Text('Undo Last Point'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.clearRegionDraft,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear Region'),
                ),
                FilledButton.icon(
                  onPressed: state.isSavingRegion
                      ? null
                      : () => controller.saveControlledRegion(
                          name: _name.text,
                          address: _address.text,
                        ),
                  icon: const Icon(Icons.save_outlined),
                  label: Text(
                    state.isSavingRegion ? 'Saving Region...' : 'Save Region',
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

class _AdminOsmGeometryMap extends StatefulWidget {
  const _AdminOsmGeometryMap({
    required this.title,
    required this.regionPoints,
    required this.areaPoints,
    required this.gatePoints,
    required this.selectedGeometryPoint,
    this.selectedRegionPoint,
    this.onMapTap,
    this.onRegionPointTap,
    this.onCornerTap,
    this.onGateTap,
  });

  final String title;
  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;
  final List<GatePoint> gatePoints;
  final AdminGeometrySelection? selectedGeometryPoint;
  final int? selectedRegionPoint;
  final ValueChanged<GeoPointValue>? onMapTap;
  final ValueChanged<int>? onRegionPointTap;
  final ValueChanged<int>? onCornerTap;
  final ValueChanged<int>? onGateTap;

  @override
  State<_AdminOsmGeometryMap> createState() => _AdminOsmGeometryMapState();
}

class _AdminOsmGeometryMapState extends State<_AdminOsmGeometryMap> {
  bool _tileError = false;

  @override
  Widget build(BuildContext context) {
    final points = [
      ...widget.regionPoints,
      ...widget.areaPoints,
      ...widget.gatePoints.map(
        (gate) =>
            GeoPointValue(latitude: gate.latitude, longitude: gate.longitude),
      ),
    ];
    final center = points.isEmpty
        ? const LatLng(13.3281211, 77.1256930)
        : _toLatLng(GeometryUtils.calculatePolygonCenter(points));
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 520 ? 280.0 : 380.0;
        return SizedBox(
          height: height,
          width: double.infinity,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: center,
                    initialZoom: points.length >= 2 ? 18 : 16,
                    initialCameraFit: points.length >= 2
                        ? CameraFit.bounds(
                            bounds: LatLngBounds.fromPoints(
                              points.map(_toLatLng).toList(),
                            ),
                            padding: const EdgeInsets.all(36),
                          )
                        : null,
                    minZoom: 13,
                    maxZoom: 20,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onTap: (_, latLng) => widget.onMapTap?.call(
                      GeoPointValue(
                        latitude: latLng.latitude,
                        longitude: latLng.longitude,
                      ),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.parkhere.admin',
                      errorTileCallback: (_, _, _) {
                        if (mounted && !_tileError) {
                          setState(() => _tileError = true);
                        }
                      },
                    ),
                    PolygonLayer(polygons: _polygons()),
                    PolylineLayer(polylines: _polylines()),
                    MarkerLayer(markers: _markers(context)),
                  ],
                ),
                Positioned(
                  left: 12,
                  top: 12,
                  right: 12,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(235),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Text(
                        widget.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                if (_tileError)
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: _ErrorBanner(
                      message:
                          'Map tiles are unavailable. Check internet access and retry.',
                      onRefresh: () async => setState(() => _tileError = false),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Polygon> _polygons() {
    return [
      if (widget.regionPoints.length >= 3)
        Polygon(
          points: widget.regionPoints.map(_toLatLng).toList(),
          color: ParkHereTheme.adminBlue.withAlpha(38),
          borderColor: ParkHereTheme.adminBlue,
          borderStrokeWidth: 3,
        ),
      if (widget.areaPoints.length >= 3)
        Polygon(
          points: widget.areaPoints.map(_toLatLng).toList(),
          color: ParkHereTheme.yellow.withAlpha(90),
          borderColor: ParkHereTheme.black,
          borderStrokeWidth: 2,
        ),
    ];
  }

  List<Polyline> _polylines() {
    return [
      if (widget.regionPoints.length == 2)
        Polyline(
          points: widget.regionPoints.map(_toLatLng).toList(),
          color: ParkHereTheme.adminBlue,
          strokeWidth: 3,
        ),
      if (widget.areaPoints.length == 2)
        Polyline(
          points: widget.areaPoints.map(_toLatLng).toList(),
          color: ParkHereTheme.black,
          strokeWidth: 2,
        ),
    ];
  }

  List<Marker> _markers(BuildContext context) {
    return [
      for (var index = 0; index < widget.regionPoints.length; index++)
        Marker(
          point: _toLatLng(widget.regionPoints[index]),
          width: 42,
          height: 42,
          child: _NumberMarker(
            label: '${index + 1}',
            selected: widget.selectedRegionPoint == index,
            color: ParkHereTheme.adminBlue,
            onTap: () => widget.onRegionPointTap?.call(index),
          ),
        ),
      for (var index = 0; index < widget.areaPoints.length; index++)
        Marker(
          point: _toLatLng(widget.areaPoints[index]),
          width: 42,
          height: 42,
          child: _NumberMarker(
            label: '${index + 1}',
            selected:
                widget.selectedGeometryPoint?.kind ==
                    AdminGeometryPointKind.corner &&
                widget.selectedGeometryPoint?.index == index,
            color: ParkHereTheme.black,
            onTap: () => widget.onCornerTap?.call(index),
          ),
        ),
      for (var index = 0; index < widget.gatePoints.length; index++)
        Marker(
          point: LatLng(
            widget.gatePoints[index].latitude,
            widget.gatePoints[index].longitude,
          ),
          width: 42,
          height: 42,
          child: _NumberMarker(
            label: 'G',
            selected:
                widget.selectedGeometryPoint?.kind ==
                    AdminGeometryPointKind.gate &&
                widget.selectedGeometryPoint?.index == index,
            color: Colors.green.shade700,
            onTap: () => widget.onGateTap?.call(index),
          ),
        ),
    ];
  }
}

class _NumberMarker extends StatelessWidget {
  const _NumberMarker({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? ParkHereTheme.yellow : color,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? ParkHereTheme.black : Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

LatLng _toLatLng(GeoPointValue point) =>
    LatLng(point.latitude, point.longitude);
