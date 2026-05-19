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
  });

  final String title;
  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;
  final List<GatePoint> gatePoints;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFE9EFEA),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD5DFDA)),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _BoundaryPainter(
                  regionPoints: regionPoints,
                  areaPoints: areaPoints,
                  gatePoints: gatePoints,
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
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
                  child: Text(title),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryPainter extends CustomPainter {
  const _BoundaryPainter({
    required this.regionPoints,
    required this.areaPoints,
    required this.gatePoints,
  });

  final List<GeoPointValue> regionPoints;
  final List<GeoPointValue> areaPoints;
  final List<GatePoint> gatePoints;

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
      _projector(size),
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
      _projector(size),
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

  Offset Function(GeoPointValue point) _projector(Size size) {
    final gateGeoPoints = gatePoints
        .map(
          (gate) =>
              GeoPointValue(latitude: gate.latitude, longitude: gate.longitude),
        )
        .toList();
    final allPoints = [...regionPoints, ...areaPoints, ...gateGeoPoints];
    if (allPoints.isEmpty) {
      return (_) => Offset(size.width / 2, size.height / 2);
    }
    final minLat = allPoints
        .map((point) => point.latitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLat = allPoints
        .map((point) => point.latitude)
        .reduce((a, b) => a > b ? a : b);
    final minLng = allPoints
        .map((point) => point.longitude)
        .reduce((a, b) => a < b ? a : b);
    final maxLng = allPoints
        .map((point) => point.longitude)
        .reduce((a, b) => a > b ? a : b);
    return (point) {
      final x =
          (point.longitude - minLng) / ((maxLng - minLng).abs() + 0.00001);
      final y = (maxLat - point.latitude) / ((maxLat - minLat).abs() + 0.00001);
      return Offset(24 + x * (size.width - 48), 24 + y * (size.height - 48));
    };
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
    final project = _projector(size);
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    for (var index = 0; index < corners.length; index++) {
      final offset = project(corners[index]);
      canvas.drawCircle(offset, 8, Paint()..color = ParkHereTheme.black);
      textPainter.text = TextSpan(
        text: '${index + 1}',
        style: const TextStyle(color: Colors.white, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, offset - const Offset(3, 6));
    }
    for (final gate in gates) {
      final offset = project(
        GeoPointValue(latitude: gate.latitude, longitude: gate.longitude),
      );
      canvas.drawCircle(offset, 9, Paint()..color = Colors.green.shade700);
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
      oldDelegate.gatePoints != gatePoints;
}
