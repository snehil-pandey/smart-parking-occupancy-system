class AdminProfile {
  const AdminProfile({
    required this.id,
    required this.businessName,
    required this.phone,
    required this.ownerName,
    this.upiId,
    this.regionId,
    this.onboardingCompleted = false,
    this.role = 'admin',
  });

  final String id;
  final String businessName;
  final String phone;
  final String ownerName;
  final String? upiId;
  final String? regionId;
  final bool onboardingCompleted;
  final String role;

  AdminProfile copyWith({
    String? id,
    String? businessName,
    String? phone,
    String? ownerName,
    String? upiId,
    String? regionId,
    bool? onboardingCompleted,
    String? role,
  }) {
    return AdminProfile(
      id: id ?? this.id,
      businessName: businessName ?? this.businessName,
      phone: phone ?? this.phone,
      ownerName: ownerName ?? this.ownerName,
      upiId: upiId ?? this.upiId,
      regionId: regionId ?? this.regionId,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      role: role ?? this.role,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'businessName': businessName,
    'phone': phone,
    'ownerName': ownerName,
    'upiId': upiId,
    'regionId': regionId,
    'onboardingCompleted': onboardingCompleted,
    'role': role,
  };

  factory AdminProfile.fromJson(Map<String, Object?> json) => AdminProfile(
    id: (json['adminId'] ?? json['id']) as String,
    businessName: json['businessName'] as String,
    phone: json['phone'] as String,
    ownerName: json['ownerName'] as String? ?? '',
    upiId: json['upiId'] as String?,
    regionId: json['regionId'] as String?,
    onboardingCompleted: json['onboardingCompleted'] as bool? ?? false,
    role: json['role'] as String? ?? 'admin',
  );
}
