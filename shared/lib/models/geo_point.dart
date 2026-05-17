class GeoPointValue {
  const GeoPointValue({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;

  Map<String, Object?> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };

  factory GeoPointValue.fromJson(Map<String, Object?> json) {
    return GeoPointValue(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}
