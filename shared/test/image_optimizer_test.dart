import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:park_here_shared/park_here_shared.dart';

void main() {
  test('optimizer keeps Firestore image payloads within limits', () {
    final optimizer = ImageOptimizer();
    final payload = optimizer.optimize(
      Uint8List.fromList(DemoSeed.demoUploadBytes()),
    );

    expect(payload.thumbnailSizeBytes, lessThanOrEqualTo(30 * 1024));
    expect(payload.previewSizeBytes, lessThanOrEqualTo(120 * 1024));
    expect(payload.mimeType, 'image/jpeg');
  });

  test(
    'image repository stores optimized records separately from areas',
    () async {
      final repository = InMemoryImageRepository(seed: const []);
      final image = await repository.uploadOptimizedAreaImage(
        areaId: 'area_test',
        uploadedByAdminId: 'admin_test',
        originalBytes: Uint8List.fromList(DemoSeed.demoUploadBytes()),
      );

      final thumbnails = await repository.getThumbnailsForArea(
        areaId: 'area_test',
        limit: 1,
      );
      final previews = await repository.getPreviewsForArea(
        areaId: 'area_test',
        limit: 1,
      );

      expect(thumbnails.single.imageId, image.imageId);
      expect(previews.single.previewSizeBytes, lessThanOrEqualTo(120 * 1024));
    },
  );
}
