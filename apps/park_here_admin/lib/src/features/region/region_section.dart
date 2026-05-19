part of '../../admin_dashboard_screen.dart';

class _RegionManagementPanel extends StatelessWidget {
  const _RegionManagementPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final region = state.region;
    return Card(
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
            Text(region.name, style: Theme.of(context).textTheme.titleLarge),
            Text(region.address),
            const SizedBox(height: 12),
            _MiniBoundaryMap(
              title: 'SIT Tumkur region geometry preview',
              regionPoints: region.boundaryPoints,
              areaPoints: const [],
              gatePoints: const [],
              selectedGeometryPoint: null,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.center_focus_strong, size: 18),
                  label: Text('${region.centerLat}, ${region.centerLng}'),
                ),
                Chip(
                  avatar: const Icon(Icons.timeline, size: 18),
                  label: Text('${region.boundaryPoints.length} polygon points'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: controller.nudgeRegionBoundary,
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Mark/edit region boundary'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniBoundaryMap extends StatelessWidget {
  const _MiniBoundaryMap({
    required this.title,
    required this.regionPoints,
    required this.areaPoints,
    required this.gatePoints,
    required this.selectedGeometryPoint,
    this.onMapTap,
    this.onCornerTap,
    this.onGateTap,
  });

  final String title;
  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;
  final List<GatePoint> gatePoints;
  final AdminGeometrySelection? selectedGeometryPoint;
  final ValueChanged<GeoPointValue>? onMapTap;
  final ValueChanged<int>? onCornerTap;
  final ValueChanged<int>? onGateTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final height = constraints.maxWidth < 520 ? 240.0 : 320.0;
        return SizedBox(
          height: height,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFFE9EFEA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD5DFDA)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _handleTap(
                  details.localPosition,
                  Size(constraints.maxWidth, height),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BoundaryPainter(
                          regionPoints: regionPoints,
                          areaPoints: areaPoints,
                          gatePoints: gatePoints,
                          selectedGeometryPoint: selectedGeometryPoint,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 12,
                      top: 12,
                      right: 12,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleTap(Offset offset, Size size) {
    final viewport = _GeometryViewport(
      size: size,
      regionPoints: regionPoints,
      areaPoints: areaPoints,
      gatePoints: gatePoints,
    );
    final hit = viewport.hitTest(offset);
    if (hit != null) {
      if (hit.kind == AdminGeometryPointKind.corner) {
        onCornerTap?.call(hit.index);
      } else {
        onGateTap?.call(hit.index);
      }
      return;
    }
    onMapTap?.call(viewport.unproject(offset));
  }
}

class _BoundaryPainter extends CustomPainter {
  const _BoundaryPainter({
    required this.regionPoints,
    required this.areaPoints,
    required this.gatePoints,
    required this.selectedGeometryPoint,
  });

  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;
  final List<GatePoint> gatePoints;
  final AdminGeometrySelection? selectedGeometryPoint;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withAlpha(110)
      ..strokeWidth = 1;
    for (var x = size.width * 0.2; x < size.width; x += size.width * 0.2) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (var y = size.height * 0.25; y < size.height; y += size.height * 0.25) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    _drawPolygon(
      canvas,
      size,
      regionPoints,
      _GeometryViewport(
        size: size,
        regionPoints: regionPoints,
        areaPoints: areaPoints,
        gatePoints: gatePoints,
      ).project,
      Paint()
        ..color = ParkHereTheme.adminBlue.withAlpha(42)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = ParkHereTheme.adminBlue
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    _drawPolygon(
      canvas,
      size,
      areaPoints,
      _GeometryViewport(
        size: size,
        regionPoints: regionPoints,
        areaPoints: areaPoints,
        gatePoints: gatePoints,
      ).project,
      Paint()
        ..color = ParkHereTheme.yellow.withAlpha(90)
        ..style = PaintingStyle.fill,
      Paint()
        ..color = ParkHereTheme.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    _drawPoints(canvas, size, areaPoints, gatePoints);
  }

  void _drawPolygon(
    Canvas canvas,
    Size size,
    List<GeoPointValue> points,
    Offset Function(GeoPointValue point) project,
    Paint fill,
    Paint stroke,
  ) {
    if (points.length < 2) {
      return;
    }

    final path = Path()
      ..moveTo(project(points.first).dx, project(points.first).dy);
    for (final point in points.skip(1)) {
      path.lineTo(project(point).dx, project(point).dy);
    }
    if (points.length >= 3) {
      path.close();
      canvas.drawPath(path, fill);
    }
    canvas.drawPath(path, stroke);
  }

  void _drawPoints(
    Canvas canvas,
    Size size,
    List<GeoPointValue> corners,
    List<GatePoint> gates,
  ) {
    final project = _GeometryViewport(
      size: size,
      regionPoints: regionPoints,
      areaPoints: areaPoints,
      gatePoints: gatePoints,
    ).project;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var index = 0; index < corners.length; index++) {
      final offset = project(corners[index]);
      final selected =
          selectedGeometryPoint?.kind == AdminGeometryPointKind.corner &&
          selectedGeometryPoint?.index == index;
      canvas.drawCircle(
        offset,
        selected ? 12 : 8,
        Paint()..color = selected ? ParkHereTheme.yellow : ParkHereTheme.black,
      );
      canvas.drawCircle(offset, 6, Paint()..color = ParkHereTheme.black);
      textPainter.text = TextSpan(
        text: '${index + 1}',
        style: const TextStyle(color: Colors.white, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset - const Offset(3, 6));
    }
    for (final gate in gates) {
      final index = gates.indexOf(gate);
      final offset = project(
        GeoPointValue(latitude: gate.latitude, longitude: gate.longitude),
      );
      final selected =
          selectedGeometryPoint?.kind == AdminGeometryPointKind.gate &&
          selectedGeometryPoint?.index == index;
      canvas.drawCircle(
        offset,
        selected ? 13 : 9,
        Paint()
          ..color = selected ? ParkHereTheme.yellow : Colors.green.shade700,
      );
      canvas.drawCircle(offset, 7, Paint()..color = Colors.green.shade700);
      textPainter.text = const TextSpan(
        text: 'G',
        style: TextStyle(color: Colors.white, fontSize: 11),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset - const Offset(4, 7));
    }
  }

  @override
  bool shouldRepaint(covariant _BoundaryPainter oldDelegate) =>
      oldDelegate.regionPoints != regionPoints ||
      oldDelegate.areaPoints != areaPoints ||
      oldDelegate.gatePoints != gatePoints ||
      oldDelegate.selectedGeometryPoint != selectedGeometryPoint;
}

class _GeometryViewport {
  _GeometryViewport({
    required this.size,
    required this.regionPoints,
    required this.areaPoints,
    required this.gatePoints,
  }) {
    final gateGeoPoints = gatePoints
        .map(
          (gate) =>
              GeoPointValue(latitude: gate.latitude, longitude: gate.longitude),
        )
        .toList();
    final points = [...regionPoints, ...areaPoints, ...gateGeoPoints];
    final allPoints = points.isEmpty ? [_defaultCenter] : points;
    minLat = allPoints
        .map((point) => point.latitude)
        .reduce((a, b) => a < b ? a : b);
    maxLat = allPoints
        .map((point) => point.latitude)
        .reduce((a, b) => a > b ? a : b);
    minLng = allPoints
        .map((point) => point.longitude)
        .reduce((a, b) => a < b ? a : b);
    maxLng = allPoints
        .map((point) => point.longitude)
        .reduce((a, b) => a > b ? a : b);
    if ((maxLat - minLat).abs() < 0.0004) {
      minLat -= 0.0002;
      maxLat += 0.0002;
    }
    if ((maxLng - minLng).abs() < 0.0004) {
      minLng -= 0.0002;
      maxLng += 0.0002;
    }
  }

  static const _defaultCenter = GeoPointValue(
    latitude: 13.3281211,
    longitude: 77.1256930,
  );

  final Size size;
  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;
  final List<GatePoint> gatePoints;
  late double minLat;
  late double maxLat;
  late double minLng;
  late double maxLng;

  Offset project(GeoPointValue point) {
    final x = (point.longitude - minLng) / (maxLng - minLng);
    final y = (maxLat - point.latitude) / (maxLat - minLat);
    return Offset(24 + x * (size.width - 48), 24 + y * (size.height - 48));
  }

  GeoPointValue unproject(Offset offset) {
    final x = ((offset.dx - 24) / (size.width - 48)).clamp(0.0, 1.0);
    final y = ((offset.dy - 24) / (size.height - 48)).clamp(0.0, 1.0);
    return GeoPointValue(
      latitude: maxLat - y * (maxLat - minLat),
      longitude: minLng + x * (maxLng - minLng),
    );
  }

  AdminGeometrySelection? hitTest(Offset offset) {
    const threshold = 20.0;
    for (var index = 0; index < areaPoints.length; index++) {
      if ((project(areaPoints[index]) - offset).distance <= threshold) {
        return AdminGeometrySelection(
          kind: AdminGeometryPointKind.corner,
          index: index,
        );
      }
    }
    for (var index = 0; index < gatePoints.length; index++) {
      final point = GeoPointValue(
        latitude: gatePoints[index].latitude,
        longitude: gatePoints[index].longitude,
      );
      if ((project(point) - offset).distance <= threshold) {
        return AdminGeometrySelection(
          kind: AdminGeometryPointKind.gate,
          index: index,
        );
      }
    }
    return null;
  }
}
