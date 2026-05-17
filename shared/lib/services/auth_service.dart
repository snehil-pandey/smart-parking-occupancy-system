import '../models/admin_profile.dart';
import '../models/app_user.dart';

abstract interface class AuthService {
  AppUser get currentUser;

  AdminProfile get currentAdmin;

  Future<AppUser> signInUser({
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  });

  Future<AdminProfile> signInAdmin({
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  });
}
