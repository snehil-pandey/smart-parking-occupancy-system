import 'dart:convert';
import 'dart:typed_data';

class ParkingAreaImage {
  const ParkingAreaImage({
    required this.imageId,
    required this.areaId,
    required this.uploadedByAdminId,
    required this.thumbnailBase64,
    required this.previewBase64,
    required this.mimeType,
    required this.uploadedAt,
  });

  final String imageId;
  final String areaId;
  final String uploadedByAdminId;
  final String thumbnailBase64;
  final String previewBase64;
  final String mimeType;
  final DateTime uploadedAt;

  static final Expando<Uint8List> _thumbnailByteCache = Expando<Uint8List>(
    'thumbnailBytes',
  );

  static final Expando<Uint8List> _previewByteCache = Expando<Uint8List>(
    'previewBytes',
  );

  Uint8List get thumbnailBytes =>
      _thumbnailByteCache[this] ??= base64Decode(thumbnailBase64);

  Uint8List get previewBytes =>
      _previewByteCache[this] ??= base64Decode(previewBase64);

  int get thumbnailSizeBytes => thumbnailBytes.length;

  int get previewSizeBytes => previewBytes.length;

  Map<String, Object?> toJson() => {
    'imageId': imageId,
    'areaId': areaId,
    'uploadedByAdminId': uploadedByAdminId,
    'thumbnailBase64': thumbnailBase64,
    'previewBase64': previewBase64,
    'mimeType': mimeType,
    'uploadedAt': uploadedAt.toIso8601String(),
  };

  factory ParkingAreaImage.fromJson(Map<String, Object?> json) {
    return ParkingAreaImage(
      imageId: json['imageId'] as String,
      areaId: json['areaId'] as String,
      uploadedByAdminId: json['uploadedByAdminId'] as String,
      thumbnailBase64: json['thumbnailBase64'] as String,
      previewBase64: json['previewBase64'] as String,
      mimeType: json['mimeType'] as String,
      uploadedAt: DateTime.parse(json['uploadedAt'] as String),
    );
  }
}

class OptimizedImagePayload {
  const OptimizedImagePayload({
    required this.thumbnailBase64,
    required this.previewBase64,
    required this.mimeType,
    required this.thumbnailSizeBytes,
    required this.previewSizeBytes,
  });

  final String thumbnailBase64;
  final String previewBase64;
  final String mimeType;
  final int thumbnailSizeBytes;
  final int previewSizeBytes;
}
