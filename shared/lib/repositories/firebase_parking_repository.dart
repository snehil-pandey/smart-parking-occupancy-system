import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parking_location.dart';
import '../services/firebase_collection_paths.dart';
import '../services/firestore_model_mapper.dart';
import 'parking_repository.dart';

class FirebaseParkingRepository implements ParkingRepository {
  FirebaseParkingRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  @override
  Future<ParkingLocation?> findById(String id) async {
    final doc = await _areas.doc(id).get();
    if (!doc.exists || doc.data() == null) {
      return null;
    }
    return FirestoreModelMapper.parkingAreaFromDoc(doc);
  }

  @override
  Future<List<ParkingLocation>> getByAdmin(String adminId) async {
    final snapshot = await _areas
        .where('adminId', isEqualTo: adminId)
        .orderBy('updatedAt', descending: true)
        .limit(50)
        .get();
    return snapshot.docs.map(FirestoreModelMapper.parkingAreaFromDoc).toList();
  }

  @override
  Stream<List<ParkingLocation>> watchByAdmin(String adminId, {int limit = 50}) {
    return _areas
        .where('adminId', isEqualTo: adminId)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(FirestoreModelMapper.parkingAreaFromDoc)
              .toList(),
        );
  }

  @override
  Future<List<ParkingLocation>> getByRegion(
    String regionId, {
    int limit = 30,
  }) async {
    final snapshot = await _areas.where('regionId', isEqualTo: regionId).get();
    return _sortedAreas(snapshot).take(limit).toList();
  }

  @override
  Stream<List<ParkingLocation>> watchByRegion(
    String regionId, {
    int limit = 30,
  }) {
    return _areas
        .where('regionId', isEqualTo: regionId)
        .snapshots()
        .map((snapshot) => _sortedAreas(snapshot).take(limit).toList());
  }

  @override
  Future<List<ParkingLocation>> getOpenAreas({int limit = 100}) async {
    final snapshot = await _areas.where('isOpen', isEqualTo: true).get();
    return _sortedAreas(snapshot).take(limit).toList();
  }

  @override
  Stream<List<ParkingLocation>> watchOpenAreas({int limit = 100}) {
    return _areas
        .where('isOpen', isEqualTo: true)
        .snapshots()
        .map((snapshot) => _sortedAreas(snapshot).take(limit).toList());
  }

  @override
  Future<List<ParkingLocation>> watchNearby({
    required double latitude,
    required double longitude,
  }) async {
    return getOpenAreas(limit: 100);
  }

  @override
  Future<ParkingLocation> reserveSlot(String areaId) async {
    final areaRef = _areas.doc(areaId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(areaRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Parking area $areaId was not found.');
      }
      final area = FirestoreModelMapper.parkingAreaFromDoc(snapshot);
      if (!area.isOpen || area.availableSpaces < 1) {
        throw StateError('Parking area $areaId has no available slots.');
      }
      final updated = area.copyWith(
        availableSpaces: area.availableSpaces - 1,
        updatedAt: DateTime.now(),
      );
      transaction.update(areaRef, {
        'availableSpaces': updated.availableSpaces,
        'updatedAt': Timestamp.fromDate(updated.updatedAt),
      });
      return updated;
    });
  }

  @override
  Future<ParkingLocation> releaseSlot(String areaId) async {
    final areaRef = _areas.doc(areaId);
    return _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(areaRef);
      if (!snapshot.exists || snapshot.data() == null) {
        throw StateError('Parking area $areaId was not found.');
      }
      final area = FirestoreModelMapper.parkingAreaFromDoc(snapshot);
      final updated = area.copyWith(
        availableSpaces: (area.availableSpaces + 1).clamp(0, area.totalSpaces),
        updatedAt: DateTime.now(),
      );
      transaction.update(areaRef, {
        'availableSpaces': updated.availableSpaces,
        'updatedAt': Timestamp.fromDate(updated.updatedAt),
      });
      return updated;
    });
  }

  @override
  Future<void> updateAvailability({
    required String locationId,
    required int totalSpaces,
    required int availableSpaces,
    required bool isOpen,
    required double pricePerHour,
  }) async {
    ParkingLocation.validatePrice(pricePerHour);
    await _areas.doc(locationId).update({
      'totalSpaces': totalSpaces,
      'availableSpaces': availableSpaces.clamp(0, totalSpaces),
      'isOpen': isOpen,
      'pricePerHour': pricePerHour,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  @override
  Future<void> upsert(ParkingLocation location) async {
    ParkingLocation.validatePrice(location.pricePerHour);
    await _areas
        .doc(location.id)
        .set(
          FirestoreModelMapper.parkingAreaToFirestore(location),
          SetOptions(merge: true),
        );
  }

  CollectionReference<Map<String, dynamic>> get _areas =>
      _firestore.collection(FirebaseCollectionPaths.parkingAreas);

  List<ParkingLocation> _sortedAreas(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final areas =
        snapshot.docs.map(FirestoreModelMapper.parkingAreaFromDoc).toList()
          ..sort((a, b) {
            if (a.isOpen != b.isOpen) {
              return b.isOpen ? 1 : -1;
            }
            final availableCompare = b.availableSpaces.compareTo(
              a.availableSpaces,
            );
            if (availableCompare != 0) {
              return availableCompare;
            }
            return b.updatedAt.compareTo(a.updatedAt);
          });
    return areas;
  }
}
