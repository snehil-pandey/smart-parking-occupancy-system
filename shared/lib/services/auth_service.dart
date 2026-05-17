import '../models/admin_profile.dart';
import '../models/app_user.dart';

abstract interface class AuthService {
  bool get isSignedIn;

  AppUser get currentUser;

  AdminProfile get currentAdmin;

  Stream<bool> authStateChanges();

  Future<AppUser?> loadCurrentUser();

  Future<AdminProfile?> loadCurrentAdmin();

  Future<AppUser> signInUserWithEmail({
    required String email,
    required String password,
  });

  Future<AppUser> signUpUserWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  });

  Future<AdminProfile> signInAdminWithEmail({
    required String email,
    required String password,
  });

  Future<AdminProfile> signUpAdminWithEmail({
    required String email,
    required String password,
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  });

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

  Future<void> signOut();
}
