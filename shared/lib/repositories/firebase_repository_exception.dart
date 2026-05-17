class FirebaseRepositoryException implements Exception {
  const FirebaseRepositoryException(this.message);

  final String message;

  @override
  String toString() => 'FirebaseRepositoryException: $message';
}
