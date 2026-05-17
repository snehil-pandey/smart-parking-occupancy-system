class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.businessName,
    required this.phone,
    required this.ownerName,
    this.upiId,
    this.role = 'admin',
  });

  final String id;
  final String businessName;
  final String phone;
  final String ownerName;
  final String? upiId;
  final String role;

  AdminProfile copyWith({
    String? id,
    String? businessName,
    String? phone,
    String? ownerName,
    String? upiId,
    String? role,
  }) {
    return AdminProfile(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      phone: phone ?? this.phone,
      ownerName: ownerName ?? this.ownerName,
      upiId: upiId ?? this.upiId,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'businessName': businessName,
    'phone': phone,
    'ownerName': ownerName,
    'upiId': upiId,
    'role': role,
  };

  factory AdminProfile.fromJson(Map<String, Object?> json) => AdminProfile(
    id: (json['adminId'] ?? json['id']) as String,
    businessName: json['businessName'] as String,
    phone: json['phone'] as String,
    ownerName: json['ownerName'] as String? ?? '',
    upiId: json['upiId'] as String?,
    role: json['role'] as String? ?? 'admin',
  );
}
