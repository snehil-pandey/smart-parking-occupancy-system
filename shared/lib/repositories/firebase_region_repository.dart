import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/parking_region.dart';
import '../services/firebase_collection_paths.dart';
import '../services/firestore_model_mapper.dart';
import 'firebase_repository_exception.dart';
import 'region_repository.dart';

class FirebaseRegionRepository implements RegionRepository {
  FirebaseRegionRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const mainRegionId = 'region_sit_tumkur';

  final FirebaseFirestore _firestore;

  @override
  Future<ParkingRegion> getMainRegion() async {
    final doc = await _regionDoc.get();
    if (!doc.exists || doc.data() == null) {
      throw const FirebaseRepositoryException(
        'SIT Tumkur region is missing in Firestore. Run demo/seed_firebase_demo.py or create /regions/region_sit_tumkur.',
      );
    }
    return FirestoreModelMapper.regionFromDoc(doc);
  }

  @override
  Stream<ParkingRegion> watchMainRegion() {
    return _regionDoc.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        throw const FirebaseRepositoryException(
          'SIT Tumkur region is missing in Firestore.',
        );
      }
      return FirestoreModelMapper.regionFromDoc(doc);
    });
  }

  @override
  Future<void> upsertRegion(ParkingRegion region) async {
    await _firestore
        .collection(FirebaseCollectionPaths.regions)
        .doc(region.regionId)
        .set(
          FirestoreModelMapper.regionToFirestore(region),
          SetOptions(merge: true),
        );
  }

  DocumentReference<Map<String, dynamic>> get _regionDoc =>
      _firestore.collection(FirebaseCollectionPaths.regions).doc(mainRegionId);
}
