class FirebaseErrorMessages {
  const FirebaseErrorMessages._();

  static const indexBuilding =
      'Firebase index is still building. Please wait a few minutes and refresh.';

  static String friendlyMessage(Object error) {
    if (isIndexBuildingError(error)) {
      return indexBuilding;
    }
    return error.toString();
  }

  static bool isIndexBuildingError(Object error) {
    final message = error.toString().toLowerCase();
    return message.contains('index') &&
        (message.contains('failed-precondition') ||
            message.contains('failed_precondition') ||
            message.contains('requires an index') ||
            message.contains('currently building') ||
            message.contains('cannot be used yet'));
  }
}
