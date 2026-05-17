import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:park_here_shared/services/firestore_model_mapper.dart';

void main() {
  test('mapper converts ISO date strings to Firestore timestamps', () {
    final encoded = FirestoreModelMapper.toFirestore({
      'createdAt': '2026-05-17T10:00:00.000',
      'openingTime': '06:00',
    });

    expect(encoded['createdAt'], isA<Timestamp>());
    expect(encoded['openingTime'], '06:00');
  });

  test('mapper converts Firestore timestamps back to ISO strings', () {
    final decoded = FirestoreModelMapper.fromFirestore({
      'updatedAt': Timestamp.fromDate(DateTime(2026, 5, 17, 10)),
    });

    expect(decoded['updatedAt'], startsWith('2026-05-17T10:00:00.000'));
  });
}
