import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'qr_models.dart';

class ScannerLocationOptions {
  const ScannerLocationOptions({
    required this.regions,
    required this.parkingAreas,
  });

  final List<ParkingRegionSummary> regions;
  final List<ParkingAreaSummary> parkingAreas;

  bool get isEmpty => parkingAreas.isEmpty;
}

class ScannerLocationService {
  ScannerLocationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static const _storageKey = 'park_here_scanner_location';

  final FirebaseFirestore _firestore;

  Future<ScannerLocationOptions> loadOptions() async {
    final regionSnapshot = await _firestore.collection('regions').get();
    final areaSnapshot = await _firestore.collection('parking_areas').get();

    final regions =
        regionSnapshot.docs.map(ParkingRegionSummary.fromDoc).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    final areas = areaSnapshot.docs.map(ParkingAreaSummary.fromDoc).toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    debugPrint(
      'Park Here Scanner: loaded ${regions.length} regions and ${areas.length} areas for scanner location.',
    );
    return ScannerLocationOptions(regions: regions, parkingAreas: areas);
  }

  Future<ScannerLocationContext?> loadSavedContext() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, Object?>;
      final context = ScannerLocationContext.fromJson(decoded);
      if (context.areaId.isEmpty || context.gateId.isEmpty) {
        return null;
      }
      return context;
    } on Object catch (error) {
      debugPrint('Park Here Scanner: failed to load saved location: $error');
      return null;
    }
  }

  Future<void> saveContext(ScannerLocationContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(context.toJson()));
    debugPrint(
      'Park Here Scanner: saved scanner location ${context.areaId}/${context.gateId}.',
    );
  }

  Future<void> clearContext() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
  }
}
