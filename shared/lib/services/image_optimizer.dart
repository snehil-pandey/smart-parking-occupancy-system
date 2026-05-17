import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/parking_area_image.dart';

class ImageOptimizationException implements Exception {
  const ImageOptimizationException(this.message);

  final String message;

  @override
  String toString() => 'ImageOptimizationException: $message';
}

class ImageOptimizationLimits {
  const ImageOptimizationLimits({
    this.maxOriginalBytes = 700 * 1024,
    this.maxThumbnailBytes = 30 * 1024,
    this.maxPreviewBytes = 120 * 1024,
    this.thumbnailMaxDimension = 160,
    this.previewMaxDimension = 720,
  });

  final int maxOriginalBytes;
  final int maxThumbnailBytes;
  final int maxPreviewBytes;
  final int thumbnailMaxDimension;
  final int previewMaxDimension;
}

class ImageOptimizer {
  const ImageOptimizer({this.limits = const ImageOptimizationLimits()});

  final ImageOptimizationLimits limits;

  OptimizedImagePayload optimize(Uint8List originalBytes) {
    if (originalBytes.length > limits.maxOriginalBytes) {
      throw ImageOptimizationException(
        'Image is ${(originalBytes.length / 1024).round()}KB. '
        'Upload an image under ${(limits.maxOriginalBytes / 1024).round()}KB.',
      );
    }

    final decoded = img.decodeImage(originalBytes);
    if (decoded == null) {
      throw const ImageOptimizationException(
        'Unsupported image. Use JPG or PNG.',
      );
    }

    final thumbnail = _encodeWithinLimit(
      source: decoded,
      maxDimension: limits.thumbnailMaxDimension,
      maxBytes: limits.maxThumbnailBytes,
      startingQuality: 72,
    );
    final preview = _encodeWithinLimit(
      source: decoded,
      maxDimension: limits.previewMaxDimension,
      maxBytes: limits.maxPreviewBytes,
      startingQuality: 82,
    );

    return OptimizedImagePayload(
      thumbnailBase64: base64Encode(thumbnail),
      previewBase64: base64Encode(preview),
      mimeType: 'image/jpeg',
      thumbnailSizeBytes: thumbnail.length,
      previewSizeBytes: preview.length,
    );
  }

  Uint8List _encodeWithinLimit({
    required img.Image source,
    required int maxDimension,
    required int maxBytes,
    required int startingQuality,
  }) {
    var dimension = maxDimension;
    var quality = startingQuality;

    while (dimension >= 48) {
      final resized = img.copyResize(
        source,
        width: source.width >= source.height ? dimension : null,
        height: source.height > source.width ? dimension : null,
        interpolation: img.Interpolation.average,
      );

      while (quality >= 42) {
        final encoded = Uint8List.fromList(
          img.encodeJpg(resized, quality: quality),
        );
        if (encoded.length <= maxBytes) {
          return encoded;
        }
        quality -= 10;
      }

      dimension = (dimension * 0.78).round();
      quality = startingQuality - 12;
    }

    throw ImageOptimizationException(
      'Could not compress image below ${(maxBytes / 1024).round()}KB.',
    );
  }
}
