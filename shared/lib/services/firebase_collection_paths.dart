class FirebaseCollectionPaths {
  const FirebaseCollectionPaths._();

  static const users = 'users';
  static const admins = 'admins';
  static const parkingLocations = 'parking_locations';
  static const bookings = 'bookings';
  static const payments = 'payments';

  static String user(String userId) => '$users/$userId';
  static String admin(String adminId) => '$admins/$adminId';
  static String parkingLocation(String locationId) =>
      '$parkingLocations/$locationId';
  static String booking(String bookingId) => '$bookings/$bookingId';
  static String payment(String paymentId) => '$payments/$paymentId';
}
