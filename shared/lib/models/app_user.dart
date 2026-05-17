enum VehicleType { car, bike, van, ev }

extension VehicleTypeLabel on VehicleType {
  String get label => switch (this) {
    VehicleType.car => 'Car',
    VehicleType.bike => 'Bike',
    VehicleType.van => 'Van',
    VehicleType.ev => 'EV',
  };
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.phone,
    required this.vehicleNumber,
    required this.defaultVehicleType,
    this.role = 'user',
  });

  final String id;
  final String name;
  final String phone;
  final String vehicleNumber;
  final VehicleType defaultVehicleType;
  final String role;

  AppUser copyWith({
    String? id,
    String? name,
    String? phone,
    String? vehicleNumber,
    VehicleType? defaultVehicleType,
    String? role,
  }) {
    return AppUser(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      vehicleNumber: vehicleNumber ?? this.vehicleNumber,
      defaultVehicleType: defaultVehicleType ?? this.defaultVehicleType,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'vehicleNumber': vehicleNumber,
    'defaultVehicleType': defaultVehicleType.name,
    'role': role,
  };

  factory AppUser.fromJson(Map<String, Object?> json) => AppUser(
    id: (json['userId'] ?? json['id']) as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    vehicleNumber: json['vehicleNumber'] as String,
    defaultVehicleType: VehicleType.values.byName(
      json['defaultVehicleType'] as String,
    ),
    role: json['role'] as String? ?? 'user',
  );
}
