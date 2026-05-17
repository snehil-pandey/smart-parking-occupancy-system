import 'geo_point.dart';

class ParkingRegion {
  const ParkingRegion({
    required this.regionId,
    required this.name,
    required this.address,
    required this.boundaryPoints,
    required this.centerLat,
    required this.centerLng,
    required this.createdByAdminId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String regionId;
  final String name;
  final String address;
  final List<GeoPointValue> boundaryPoints;
  final double centerLat;
  final double centerLng;
  final String createdByAdminId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ParkingRegion copyWith({
    String? regionId,
    String? name,
    String? address,
    List<GeoPointValue>? boundaryPoints,
    double? centerLat,
    double? centerLng,
    String? createdByAdminId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ParkingRegion(
      regionId: regionId ?? this.regionId,
      name: name ?? this.name,
      address: address ?? this.address,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      centerLat: centerLat ?? this.centerLat,
      centerLng: centerLng ?? this.centerLng,
      createdByAdminId: createdByAdminId ?? this.createdByAdminId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'regionId': regionId,
    'name': name,
    'address': address,
    'boundaryPoints': boundaryPoints.map((point) => point.toJson()).toList(),
    'centerLat': centerLat,
    'centerLng': centerLng,
    'createdByAdminId': createdByAdminId,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ParkingRegion.fromJson(Map<String, Object?> json) {
    return ParkingRegion(
      regionId: json['regionId'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      boundaryPoints: (json['boundaryPoints'] as List<Object?>)
          .cast<Map<String, Object?>>()
          .map(GeoPointValue.fromJson)
          .toList(),
      centerLat: (json['centerLat'] as num).toDouble(),
      centerLng: (json['centerLng'] as num).toDouble(),
      createdByAdminId: json['createdByAdminId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
