import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

import '../models/admin_profile.dart';
import '../models/app_user.dart';
import 'auth_service.dart';
import 'firebase_collection_paths.dart';
import 'firestore_model_mapper.dart';

class FirebaseAuthService implements AuthService {
  FirebaseAuthService({
    firebase_auth.FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? firebase_auth.FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final firebase_auth.FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  AppUser? _currentUser;
  AdminProfile? _currentAdmin;

  @override
  bool get isSignedIn => _auth.currentUser != null;

  @override
  AppUser get currentUser {
    final user = _currentUser;
    if (user == null) {
      throw StateError('No Firebase user profile is loaded.');
    }
    return user;
  }

  @override
  AdminProfile get currentAdmin {
    final admin = _currentAdmin;
    if (admin == null) {
      throw StateError('No Firebase admin profile is loaded.');
    }
    return admin;
  }

  @override
  Stream<bool> authStateChanges() {
    return _auth.authStateChanges().map((user) => user != null);
  }

  @override
  Future<AppUser?> loadCurrentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      return null;
    }
    final doc = await _firestore
        .collection(FirebaseCollectionPaths.users)
        .doc(firebaseUser.uid)
        .get();
    if (!doc.exists || doc.data() == null) {
      _currentUser = null;
      return null;
    }
    _currentUser = AppUser.fromJson(
      FirestoreModelMapper.fromFirestore(doc.data()!, documentId: doc.id),
    );
    return _currentUser;
  }

  Future<AppUser> _createMinimalUserProfile(firebase_auth.User firebaseUser) {
    final name = firebaseUser.displayName?.trim().isNotEmpty == true
        ? firebaseUser.displayName!.trim()
        : (firebaseUser.email ?? 'Park Here user');
    return signInUser(
      name: name,
      phone: '',
      vehicleNumber: '',
      vehicleType: VehicleType.car,
    );
  }

  @override
  Future<AdminProfile?> loadCurrentAdmin() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _currentAdmin = null;
      return null;
    }
    final doc = await _firestore
        .collection(FirebaseCollectionPaths.admins)
        .doc(firebaseUser.uid)
        .get();
    if (!doc.exists || doc.data() == null) {
      _currentAdmin = null;
      return null;
    }
    _currentAdmin = AdminProfile.fromJson(
      FirestoreModelMapper.fromFirestore(doc.data()!, documentId: doc.id),
    );
    return _currentAdmin;
  }

  Future<AdminProfile> _createMinimalAdminProfile(
    firebase_auth.User firebaseUser,
  ) {
    final businessName = firebaseUser.displayName?.trim().isNotEmpty == true
        ? firebaseUser.displayName!.trim()
        : (firebaseUser.email ?? 'Park Here administrator');
    return signInAdmin(businessName: businessName, ownerName: '', phone: '');
  }

  @override
  Future<AppUser> signInUserWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final firebaseUser = _auth.currentUser;
    var profile = await loadCurrentUser();
    if (profile == null && firebaseUser != null) {
      profile = await _createMinimalUserProfile(firebaseUser);
    }
    if (profile == null || profile.role != 'user') {
      await _auth.signOut();
      throw StateError('No user profile exists for this account.');
    }
    return profile;
  }

  @override
  Future<AppUser> signUpUserWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final profile = AppUser(
      id: uid,
      name: name,
      phone: phone,
      vehicleNumber: vehicleNumber,
      defaultVehicleType: vehicleType,
    );
    await _firestore.collection(FirebaseCollectionPaths.users).doc(uid).set({
      ...profile.toJson(),
      'userId': uid,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
    _currentUser = profile;
    return profile;
  }

  @override
  Future<AdminProfile> signInAdminWithEmail({
    required String email,
    required String password,
  }) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    final firebaseUser = _auth.currentUser;
    var profile = await loadCurrentAdmin();
    if (profile == null && firebaseUser != null) {
      profile = await _createMinimalAdminProfile(firebaseUser);
    }
    if (profile == null || profile.role != 'admin') {
      await _auth.signOut();
      throw StateError('No admin profile exists for this account.');
    }
    return profile;
  }

  @override
  Future<AdminProfile> signUpAdminWithEmail({
    required String email,
    required String password,
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final uid = credential.user!.uid;
    final profile = AdminProfile(
      id: uid,
      businessName: businessName,
      ownerName: ownerName,
      phone: phone,
      upiId: upiId,
    );
    await _firestore.collection(FirebaseCollectionPaths.admins).doc(uid).set({
      ...profile.toJson(),
      'adminId': uid,
      'createdAt': Timestamp.fromDate(DateTime.now()),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    }, SetOptions(merge: true));
    _currentAdmin = profile;
    return profile;
  }

  @override
  Future<AppUser> signInUser({
    required String name,
    required String phone,
    required String vehicleNumber,
    required VehicleType vehicleType,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Sign in before updating your profile.');
    }
    final profile = AppUser(
      id: firebaseUser.uid,
      name: name,
      phone: phone,
      vehicleNumber: vehicleNumber,
      defaultVehicleType: vehicleType,
    );
    await _firestore
        .collection(FirebaseCollectionPaths.users)
        .doc(firebaseUser.uid)
        .set({
          ...profile.toJson(),
          'userId': firebaseUser.uid,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
    _currentUser = profile;
    return profile;
  }

  @override
  Future<AdminProfile> signInAdmin({
    required String businessName,
    required String ownerName,
    required String phone,
    String? upiId,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      throw StateError('Sign in before updating your admin profile.');
    }
    final profile = AdminProfile(
      id: firebaseUser.uid,
      businessName: businessName,
      ownerName: ownerName,
      phone: phone,
      upiId: upiId,
    );
    await _firestore
        .collection(FirebaseCollectionPaths.admins)
        .doc(firebaseUser.uid)
        .set({
          ...profile.toJson(),
          'adminId': firebaseUser.uid,
          'updatedAt': Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
    _currentAdmin = profile;
    return profile;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _currentAdmin = null;
    await _auth.signOut();
  }
}
