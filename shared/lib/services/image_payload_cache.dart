import '../models/parking_area_image.dart';

class ImagePayloadCache {
  ImagePayloadCache({this.maxEntries = 80});

  final int maxEntries;
  final _items = <String, ParkingAreaImage>{};

  ParkingAreaImage? get(String imageId) {
    final image = _items.remove(imageId);
    if (image != null) {
      _items[imageId] = image;
    }
    return image;
  }

  void put(ParkingAreaImage image) {
    _items[image.imageId] = image;
    while (_items.length > maxEntries) {
      _items.remove(_items.keys.first);
    }
  }

  List<ParkingAreaImage> getMany(Iterable<String> ids) {
    return [
      for (final id in ids)
        if (_items[id] != null) _items[id]!,
    ];
  }
}
