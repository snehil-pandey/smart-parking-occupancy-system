import 'app_user.dart';

class ParkingLocation {
  const ParkingLocation({
    required this.id,
    required this.adminId,
    required this.name,
    required this.address,
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
  });

  final String id;
  final String adminId;
  final String name;
  final String address;
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

  bool supports(VehicleType type) => vehicleTypes.contains(type);

  ParkingLocation copyWith({
    String? id,
    String? adminId,
    String? name,
    String? address,
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
  }) {
    return ParkingLocation(
      id: id ?? this.id,
      adminId: adminId ?? this.adminId,
      name: name ?? this.name,
      address: address ?? this.address,
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
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'adminId': adminId,
    'name': name,
    'address': address,
    'latitude': latitude,
    'longitude': longitude,
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
  };

  factory ParkingLocation.fromJson(Map<String, Object?> json) {
    return ParkingLocation(
      id: json['id'] as String,
      adminId: json['adminId'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
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
    );
  }
}
