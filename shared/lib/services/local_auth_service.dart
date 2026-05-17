import '../models/admin_profile.dart';
import '../models/app_user.dart';
import 'auth_service.dart';

class LocalAuthService implements AuthService {
  LocalAuthService()
    : _currentUser = const AppUser(
        id: 'user_demo_001',
        name: 'Ananya',
        phone: '+91 90000 11111',
        vehicleNumber: 'KA 05 MN 4242',
        defaultVehicleType: VehicleType.car,
      ),
      _currentAdmin = const AdminProfile(
        id: 'admin_demo_001',
        businessName: 'Metro Park Hub',
        ownerName: 'Ravi Kumar',
        phone: '+91 90000 22222',
        upiId: 'metropark@upi',
      );

  AppUser _currentUser;
  AdminProfile _currentAdmin;

  @override
  bool get isSignedIn => true;

  @override
  AppUser get currentUser => _currentUser;

  @override
  AdminProfile get currentAdmin => _currentAdmin;

  @override
  Stream<bool> authStateChanges() => Stream.value(true);

  @override
  Future<AppUser?> loadCurrentUser() async => _currentUser;

  @override
  Future<AdminProfile?> loadCurrentAdmin() async => _currentAdmin;

  @override
  Future<AppUser> signInUserWithEmail({
    required String email,
    required String password,
  }) async {
    return _currentUser;
  }

  @override
  Future<AppUser> signUpUserWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  }) {
    return signInUser(
      name: name,
      phone: phone,
      vehicleNumber: vehicleNumber,
      vehicleType: vehicleType,
    );
  }

  @override
  Future<AdminProfile> signInAdminWithEmail({
    required String email,
    required String password,
  }) async {
    return _currentAdmin;
  }

  @override
  Future<AdminProfile> signUpAdminWithEmail({
    required String email,
    required String password,
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  }) {
    return signInAdmin(
      businessName: businessName,
      ownerName: ownerName,
      phone: phone,
      upiId: upiId,
    );
  }

  @override
  Future<AppUser> signInUser({
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  }) async {
    _currentUser = AppUser(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      phone: phone,
      vehicleNumber: vehicleNumber,
      defaultVehicleType: vehicleType,
    );
    return _currentUser;
  }

  @override
  Future<AdminProfile> signInAdmin({
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  }) async {
    _currentAdmin = AdminProfile(
      id: 'admin_${DateTime.now().millisecondsSinceEpoch}',
      businessName: businessName,
      ownerName: ownerName,
      phone: phone,
      upiId: upiId,
    );
    return _currentAdmin;
  }

  @override
  Future<void> signOut() async {}
}
