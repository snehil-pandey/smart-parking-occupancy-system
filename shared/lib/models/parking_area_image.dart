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

  int get thumbnailSizeBytes => base64Decode(thumbnailBase64).length;

  int get previewSizeBytes => base64Decode(previewBase64).length;

  Uint8List get thumbnailBytes => base64Decode(thumbnailBase64);

  Uint8List get previewBytes => base64Decode(previewBase64);

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
