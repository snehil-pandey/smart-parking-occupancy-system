import 'app_user.dart';
import 'gate_point.dart';
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
    this.gatePoints = const [],
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
    this.minLat,
    this.maxLat,
    this.minLng,
    this.maxLng,
    this.ratingAverage = 0,
    this.ratingCount = 0,
  }) : assert(pricePerHour >= 0 && pricePerHour <= 100);

  final String id;
  final String regionId;
  final String adminId;
  final String name;
  final String description;
  final String address;
  final List<GeoPointValue> boundaryPoints;
  final List<GatePoint> gatePoints;
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
  final double? minLat;
  final double? maxLat;
  final double? minLng;
  final double? maxLng;
  final double ratingAverage;
  final int ratingCount;

  String get areaId => id;

  double get centerLat => latitude;

  double get centerLng => longitude;

  bool supports(VehicleType type) => vehicleTypes.contains(type);

  bool get isUserVisibleParkingArea {
    final normalizedId = id.trim();
    final normalizedRegionId = regionId.trim();
    return normalizedId.isNotEmpty &&
        normalizedRegionId.isNotEmpty &&
        adminId.trim().isNotEmpty &&
        normalizedId != normalizedRegionId &&
        !normalizedId.startsWith('region_') &&
        totalSpaces > 0 &&
        availableSpaces >= 0 &&
        availableSpaces <= totalSpaces;
  }

  bool get isBookable =>
      isUserVisibleParkingArea && isOpen && availableSpaces > 0;

  String get availabilityLabel {
    if (!isOpen) {
      return 'Closed';
    }
    if (availableSpaces <= 0) {
      return 'Full';
    }
    return '$availableSpaces available';
  }

  static bool isValidPrice(double pricePerHour) =>
      pricePerHour >= 0 && pricePerHour <= 100;

  static void validatePrice(double pricePerHour) {
    if (!isValidPrice(pricePerHour)) {
      throw ArgumentError.value(
        pricePerHour,
        'pricePerHour',
        'Parking price must be between Rs. 0 and Rs. 100 per hour.',
      );
    }
  }

  ParkingLocation copyWith({
    String? id,
    String? regionId,
    String? adminId,
    String? name,
    String? description,
    String? address,
    List<GeoPointValue>? boundaryPoints,
    List<GatePoint>? gatePoints,
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
    double? minLat,
    double? maxLat,
    double? minLng,
    double? maxLng,
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
      gatePoints: gatePoints ?? this.gatePoints,
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
      minLat: minLat ?? this.minLat,
      maxLat: maxLat ?? this.maxLat,
      minLng: minLng ?? this.minLng,
      maxLng: maxLng ?? this.maxLng,
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
    'gatePoints': gatePoints.map((point) => point.toJson()).toList(),
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
    'minLat': minLat,
    'maxLat': maxLat,
    'minLng': minLng,
    'maxLng': maxLng,
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
      gatePoints: (json['gatePoints'] as List<Object?>? ?? const [])
          .cast<Map<String, Object?>>()
          .map(GatePoint.fromJson)
          .toList(),
      latitude: ((json['centerLat'] ?? json['latitude']) as num).toDouble(),
      longitude: ((json['centerLng'] ?? json['longitude']) as num).toDouble(),
      totalSpaces: json['totalSpaces'] as int,
      availableSpaces: json['availableSpaces'] as int,
      pricePerHour: (json['pricePerHour'] as num).toDouble(),
      vehicleTypes: (json['vehicleTypes'] as List<Object?>)
          .map(parseVehicleType)
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
      minLat: (json['minLat'] as num?)?.toDouble(),
      maxLat: (json['maxLat'] as num?)?.toDouble(),
      minLng: (json['minLng'] as num?)?.toDouble(),
      maxLng: (json['maxLng'] as num?)?.toDouble(),
      ratingAverage: (json['ratingAverage'] as num? ?? 0).toDouble(),
      ratingCount: json['ratingCount'] as int? ?? 0,
    );
  }
}
