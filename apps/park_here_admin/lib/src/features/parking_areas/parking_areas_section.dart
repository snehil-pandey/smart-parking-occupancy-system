part of '../../admin_dashboard_screen.dart';

class _LocationsPanel extends StatelessWidget {
  const _LocationsPanel({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final selected = state.selectedLocation;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Parking areas in SIT Tumkur',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 10),
            if (state.locations.isEmpty)
              const _EmptyState(message: 'No parking areas yet.')
            else
              for (final location in state.locations)
                ListTile(
                  selected: selected?.id == location.id,
                  onTap: () {
                    controller.selectLocation(location);
                  },
                  leading: const Icon(Icons.local_parking),
                  title: Text(
                    location.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${location.availableSpaces}/${location.totalSpaces} spaces - ${formatParkingRate(location.pricePerHour)} - ${location.ratingAverage.toStringAsFixed(1)} rating',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    location.isOpen ? Icons.lock_open : Icons.lock_outline,
                  ),
                ),
            if (selected != null) ...[
              const Divider(height: 28),
              _AreaBoundaryEditor(state: state, controller: controller),
              const Divider(height: 28),
              _AvailabilityEditor(location: selected, controller: controller),
              const Divider(height: 28),
              _ImageManager(state: state, controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

class _AreaBoundaryEditor extends StatelessWidget {
  const _AreaBoundaryEditor({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    final location = state.selectedLocation!;
    final gps = state.lastGpsPosition;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Area geometry preview',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 4),
        const Text(
          'Admin OSM tiles are not wired yet; this preview shows saved polygons and GPS gate points only.',
        ),
        const SizedBox(height: 8),
        _MiniBoundaryMap(
          title: location.name,
          regionPoints: state.region.boundaryPoints,
          areaPoints: state.draftBoundaryPoints,
          gatePoints: state.draftGatePoints,
          selectedGeometryPoint: state.selectedGeometryPoint,
          onMapTap: controller.handleMapTap,
          onCornerTap: controller.selectCornerPoint,
          onGateTap: (index) {
            controller.selectGatePoint(index);
            _showGateSheet(context, index: index);
          },
        ),
        const SizedBox(height: 8),
        SegmentedButton<AdminGeometryMode>(
          segments: const [
            ButtonSegment(
              value: AdminGeometryMode.corner,
              icon: Icon(Icons.polyline_outlined),
              label: Text('Corner mode'),
            ),
            ButtonSegment(
              value: AdminGeometryMode.gate,
              icon: Icon(Icons.door_front_door_outlined),
              label: Text('Gate mode'),
            ),
          ],
          selected: {state.geometryMode},
          onSelectionChanged: (selection) =>
              controller.changeGeometryMode(selection.first),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: const Icon(Icons.polyline_outlined, size: 18),
              label: Text('${state.draftBoundaryPoints.length} corners'),
            ),
            Chip(
              avatar: const Icon(Icons.login_outlined, size: 18),
              label: Text('${state.draftGatePoints.length} gates'),
            ),
            Chip(
              avatar: const Icon(Icons.pin_drop_outlined, size: 18),
              label: Text('${location.centerLat}, ${location.centerLng}'),
            ),
            if (gps != null)
              Chip(
                avatar: Icon(
                  gps.accuracyMeters > 25
                      ? Icons.gps_not_fixed
                      : Icons.gps_fixed,
                  size: 18,
                ),
                label: Text('GPS ${gps.accuracyMeters.toStringAsFixed(0)} m'),
              ),
            if (state.selectedGeometryPoint != null)
              Chip(
                avatar: const Icon(Icons.ads_click, size: 18),
                label: Text('Selected ${state.selectedGeometryPoint!.label}'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          state.geometryStatusMessage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (gps != null && gps.accuracyMeters > 25) ...[
          const SizedBox(height: 6),
          const Text(
            'GPS accuracy is poor. Stand outdoors and wait before saving final geometry.',
            style: TextStyle(color: Colors.deepOrange),
          ),
        ],
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              onPressed: controller.markCurrentPositionAsCorner,
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('Mark Current Position as Corner'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showGateSheet(context),
              icon: const Icon(Icons.door_front_door_outlined),
              label: const Text('Mark Current Position as Gate'),
            ),
            IconButton.filledTonal(
              tooltip: 'Undo last geometry change',
              onPressed: controller.undoLastGeometryChange,
              icon: const Icon(Icons.undo),
            ),
            OutlinedButton.icon(
              onPressed: controller.deleteSelectedGeometryPoint,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Selected Point'),
            ),
            OutlinedButton.icon(
              onPressed: controller.clearGeometrySelection,
              icon: const Icon(Icons.deselect_outlined),
              label: const Text('Clear Selection'),
            ),
            OutlinedButton.icon(
              onPressed: controller.clearCorners,
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear Corners'),
            ),
            OutlinedButton.icon(
              onPressed: controller.clearGates,
              icon: const Icon(Icons.clear),
              label: const Text('Clear Gates'),
            ),
            FilledButton.icon(
              onPressed: state.isSavingGeometry
                  ? null
                  : controller.saveAreaGeometry,
              icon: const Icon(Icons.save_outlined),
              label: Text(
                state.isSavingGeometry
                    ? 'Saving Geometry...'
                    : 'Save Area Geometry',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _GateList(state: state, controller: controller, onEdit: _showGateSheet),
      ],
    );
  }

  void _showGateSheet(BuildContext context, {int? index}) {
    final existing = index == null ? null : state.draftGatePoints[index];
    final name = TextEditingController(text: existing?.name ?? 'Main Gate');
    var type = existing?.type ?? GatePointType.both;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
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
                    'Name gate point',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: name.text,
                    decoration: const InputDecoration(
                      labelText: 'Common gate name',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Main Gate',
                        child: Text('Main Gate'),
                      ),
                      DropdownMenuItem(
                        value: 'Exit Gate',
                        child: Text('Exit Gate'),
                      ),
                      DropdownMenuItem(
                        value: 'Staff Gate',
                        child: Text('Staff Gate'),
                      ),
                      DropdownMenuItem(
                        value: 'Student Gate',
                        child: Text('Student Gate'),
                      ),
                    ],
                    onChanged: (value) => name.text = value ?? name.text,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'Gate label',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<GatePointType>(
                    segments: const [
                      ButtonSegment(
                        value: GatePointType.entry,
                        label: Text('Entry'),
                      ),
                      ButtonSegment(
                        value: GatePointType.exit,
                        label: Text('Exit'),
                      ),
                      ButtonSegment(
                        value: GatePointType.both,
                        label: Text('Both'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (value) =>
                        setSheetState(() => type = value.first),
                  ),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: () {
                      if (index == null) {
                        controller.markCurrentPositionAsGate(
                          name: name.text,
                          type: type,
                        );
                      } else {
                        controller.updateGatePoint(
                          index: index,
                          name: name.text,
                          type: type,
                        );
                      }
                      Navigator.pop(context);
                    },
                    icon: Icon(
                      index == null ? Icons.my_location : Icons.save_outlined,
                    ),
                    label: Text(
                      index == null ? 'Use current GPS for gate' : 'Save gate',
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _GateList extends StatelessWidget {
  const _GateList({
    required this.state,
    required this.controller,
    required this.onEdit,
  });

  final AdminAppState state;
  final AdminAppController controller;
  final void Function(BuildContext context, {int? index}) onEdit;

  @override
  Widget build(BuildContext context) {
    if (state.draftGatePoints.isEmpty) {
      return Text(
        'No gates marked yet. Gates are optional but recommended for routing.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gate points', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 6),
        for (var index = 0; index < state.draftGatePoints.length; index++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              selected:
                  state.selectedGeometryPoint?.kind ==
                      AdminGeometryPointKind.gate &&
                  state.selectedGeometryPoint?.index == index,
              leading: const Icon(Icons.door_front_door_outlined),
              title: Text(
                state.draftGatePoints[index].name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '${state.draftGatePoints[index].type.name} - '
                '${state.draftGatePoints[index].latitude.toStringAsFixed(6)}, '
                '${state.draftGatePoints[index].longitude.toStringAsFixed(6)}',
              ),
              onTap: () {
                controller.selectGatePoint(index);
                onEdit(context, index: index);
              },
              trailing: Wrap(
                spacing: 4,
                children: [
                  IconButton(
                    tooltip: 'Select gate',
                    onPressed: () => controller.selectGatePoint(index),
                    icon: const Icon(Icons.ads_click),
                  ),
                  IconButton(
                    tooltip: 'Remove gate',
                    onPressed: () => controller.removeGateAt(index),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ImageManager extends StatelessWidget {
  const _ImageManager({required this.state, required this.controller});

  final AdminAppState state;
  final AdminAppController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Optimized images',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 6),
        Text(
          state.imageStatusMessage,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (state.imageUploadProgress > 0 && state.imageUploadProgress < 1) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: state.imageUploadProgress),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final image in state.selectedImages)
              SizedBox(
                width: 154,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFDDE5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                        child: Image.memory(
                          image.previewBytes,
                          width: 154,
                          height: 92,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${(image.previewSizeBytes / 1024).toStringAsFixed(1)}KB preview',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: 'Replace image',
                                  onPressed: () =>
                                      _replaceImage(controller, image),
                                  icon: const Icon(
                                    Icons.change_circle_outlined,
                                  ),
                                ),
                                IconButton(
                                  tooltip: 'Remove image',
                                  onPressed: () =>
                                      controller.removeImage(image),
                                  icon: const Icon(Icons.delete_outline),
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
            SizedBox(
              width: 154,
              height: 148,
              child: OutlinedButton.icon(
                key: const ValueKey('upload-optimized-image'),
                onPressed: () => _uploadImage(controller),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('Upload optimized image'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _uploadImage(AdminAppController controller) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    await controller.uploadAreaImage(await picked.readAsBytes());
  }

  Future<void> _replaceImage(
    AdminAppController controller,
    ParkingAreaImage image,
  ) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) {
      return;
    }
    await controller.replaceImage(image, await picked.readAsBytes());
  }
}

class _AvailabilityEditor extends StatefulWidget {
  const _AvailabilityEditor({required this.location, required this.controller});

  final ParkingLocation location;
  final AdminAppController controller;

  @override
  State<_AvailabilityEditor> createState() => _AvailabilityEditorState();
}

class _AvailabilityEditorState extends State<_AvailabilityEditor> {
  late double total = widget.location.totalSpaces.toDouble();
  late double available = widget.location.availableSpaces.toDouble();
  late double price = widget.location.pricePerHour;
  late bool isOpen = widget.location.isOpen;

  @override
  void didUpdateWidget(covariant _AvailabilityEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location.id != widget.location.id) {
      total = widget.location.totalSpaces.toDouble();
      available = widget.location.availableSpaces.toDouble();
      price = widget.location.pricePerHour;
      isOpen = widget.location.isOpen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Manage availability',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Location open'),
          value: isOpen,
          onChanged: (value) => setState(() => isOpen = value),
        ),
        _LabeledSlider(
          label: 'Total spaces',
          value: total,
          min: 0,
          max: 200,
          onChanged: (value) => setState(() => total = value),
        ),
        _LabeledSlider(
          label: 'Available spaces',
          value: available.clamp(0, total),
          min: 0,
          max: total,
          onChanged: (value) => setState(() => available = value),
        ),
        _LabeledSlider(
          label: 'Price per hour',
          value: price,
          min: 0,
          max: 100,
          onChanged: (value) => setState(() => price = value),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => widget.controller.updateSelectedAvailability(
              totalSpaces: total.round(),
              availableSpaces: available.round(),
              isOpen: isOpen,
              pricePerHour: price.roundToDouble(),
            ),
            icon: const Icon(Icons.tune),
            label: const Text('Update location'),
          ),
        ),
      ],
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final slider = Slider(
          min: min,
          max: max <= min ? min + 1 : max,
          divisions: (max - min).round().clamp(1, 200),
          value: value.clamp(min, max <= min ? min + 1 : max),
          label: value.round().toString(),
          onChanged: onChanged,
        );
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Text('$label: ${value.round()}'), slider],
          );
        }
        return Row(
          children: [
            SizedBox(width: 118, child: Text(label)),
            Expanded(child: slider),
            SizedBox(width: 48, child: Text(value.round().toString())),
          ],
        );
      },
    );
  }
}
