import 'package:flutter_test/flutter_test.dart';
import 'package:park_here_shared/park_here_shared.dart';

void main() {
  test('recognizes Firestore index building errors', () {
    final error = Exception(
      'FAILED_PRECONDITION: The query requires an index. '
      'That index is currently building and cannot be used yet.',
    );

    expect(FirebaseErrorMessages.isIndexBuildingError(error), isTrue);
    expect(
      FirebaseErrorMessages.friendlyMessage(error),
      FirebaseErrorMessages.indexBuilding,
    );
  });

  test('does not rewrite unrelated Firebase errors', () {
    final error = Exception('permission-denied');

    expect(FirebaseErrorMessages.isIndexBuildingError(error), isFalse);
    expect(FirebaseErrorMessages.friendlyMessage(error), error.toString());
  });
}
