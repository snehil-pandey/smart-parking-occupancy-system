import 'app_user.dart';
import 'geo_point.dart';

class ParkingLocation {
  const ParkingLocation({
    required this.id,
    this.regionId = 'region_sit_tumkur',
    required this.adminId,
    required this.name,
    this.description = '',
    required this.address,
    this.boundaryPoints = const [],
    required this.latitude,
    required this.longitude,
    required this.totalSpaces,
    required this.availableSpaces,
    required this.pricePerHour,
    required this.vehicleTypes,
    required this.thumbnailRefs,
    required this.imagePreviewRefs,
    required this.isOpen,
    required this.openingTime,
    required this.closingTime,
    required this.createdAt,
    required this.updatedAt,
    this.ratingAverage = 0,
    this.ratingCount = 0,
  });

  final String id;
  final String regionId;
  final String adminId;
  final String name;
  final String description;
  final String address;
  final List<GeoPointValue> boundaryPoints;
  final double latitude;
  final double longitude;
  final int totalSpaces;
  final int availableSpaces;
  final double pricePerHour;
  final List<VehicleType> vehicleTypes;
  final List<String> thumbnailRefs;
  final List<String> imagePreviewRefs;
  final bool isOpen;
  final String openingTime;
  final String closingTime;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double ratingAverage;
  final int ratingCount;

  String get areaId => id;

  double get centerLat => latitude;

  double get centerLng => longitude;

  bool supports(VehicleType type) => vehicleTypes.contains(type);

  ParkingLocation copyWith({
    String? id,
    String? regionId,
    String? adminId,
    String? name,
    String? description,
    String? address,
    List<GeoPointValue>? boundaryPoints,
    double? latitude,
    double? longitude,
    int? totalSpaces,
    int? availableSpaces,
    double? pricePerHour,
    List<VehicleType>? vehicleTypes,
    List<String>? thumbnailRefs,
    List<String>? imagePreviewRefs,
    bool? isOpen,
    String? openingTime,
    String? closingTime,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? ratingAverage,
    int? ratingCount,
  }) {
    return ParkingLocation(
      id: id ?? this.id,
      regionId: regionId ?? this.regionId,
      adminId: adminId ?? this.adminId,
      name: name ?? this.name,
      description: description ?? this.description,
      address: address ?? this.address,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      totalSpaces: totalSpaces ?? this.totalSpaces,
      availableSpaces: availableSpaces ?? this.availableSpaces,
      pricePerHour: pricePerHour ?? this.pricePerHour,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      thumbnailRefs: thumbnailRefs ?? this.thumbnailRefs,
      imagePreviewRefs: imagePreviewRefs ?? this.imagePreviewRefs,
      isOpen: isOpen ?? this.isOpen,
      openingTime: openingTime ?? this.openingTime,
      closingTime: closingTime ?? this.closingTime,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      ratingAverage: ratingAverage ?? this.ratingAverage,
      ratingCount: ratingCount ?? this.ratingCount,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'areaId': id,
    'regionId': regionId,
    'adminId': adminId,
    'name': name,
    'description': description,
    'address': address,
    'boundaryPoints': boundaryPoints.map((point) => point.toJson()).toList(),
    'latitude': latitude,
    'longitude': longitude,
    'centerLat': latitude,
    'centerLng': longitude,
    'totalSpaces': totalSpaces,
    'availableSpaces': availableSpaces,
    'pricePerHour': pricePerHour,
    'vehicleTypes': vehicleTypes.map((type) => type.name).toList(),
    'thumbnailRefs': thumbnailRefs,
    'imagePreviewRefs': imagePreviewRefs,
    'isOpen': isOpen,
    'openingTime': openingTime,
    'closingTime': closingTime,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'ratingAverage': ratingAverage,
    'ratingCount': ratingCount,
  };

  factory ParkingLocation.fromJson(Map<String, Object?> json) {
    return ParkingLocation(
      id: (json['areaId'] ?? json['id']) as String,
      regionId: json['regionId'] as String? ?? 'region_sit_tumkur',
      adminId: json['adminId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      address: json['address'] as String,
      boundaryPoints: (json['boundaryPoints'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(GeoPointValue.fromJson)
          .toList(),
      latitude: ((json['centerLat'] ?? json['latitude']) as num).toDouble(),
      longitude: ((json['centerLng'] ?? json['longitude']) as num).toDouble(),
      totalSpaces: json['totalSpaces'] as int,
      availableSpaces: json['availableSpaces'] as int,
      pricePerHour: (json['pricePerHour'] as num).toDouble(),
      vehicleTypes: (json['vehicleTypes'] as List<Object?>)
          .cast<String>()
          .map(VehicleType.values.byName)
          .toList(),
      thumbnailRefs: (json['thumbnailRefs'] as List<Object?>? ?? const [])
          .cast<String>(),
      imagePreviewRefs: (json['imagePreviewRefs'] as List<Object?>? ?? const [])
          .cast<String>(),
      isOpen: json['isOpen'] as bool,
      openingTime: json['openingTime'] as String,
      closingTime: json['closingTime'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      ratingAverage: (json['ratingAverage'] as num? ?? 0).toDouble(),
      ratingCount: json['ratingCount'] as int? ?? 0,
    );
  }
}
