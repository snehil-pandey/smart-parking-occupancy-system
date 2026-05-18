enum GatePointType { entry, exit, both }

class GatePoint {
  const GatePoint({
    required this.gateId,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.type,
    required this.createdAt,
  });

  final String gateId;
  final String name;
  final double latitude;
  final double longitude;
  final GatePointType type;
  final DateTime createdAt;

  GatePoint copyWith({
    String? gateId,
    String? name,
    double? latitude,
    double? longitude,
    GatePointType? type,
    DateTime? createdAt,
  }) {
    return GatePoint(
      gateId: gateId ?? this.gateId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toJson() => {
    'gateId': gateId,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
    'type': type.name,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GatePoint.fromJson(Map<String, Object?> json) {
    return GatePoint(
      gateId: json['gateId'] as String,
      name: json['name'] as String? ?? 'Gate',
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      type: GatePointType.values.byName(json['type'] as String? ?? 'both'),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
