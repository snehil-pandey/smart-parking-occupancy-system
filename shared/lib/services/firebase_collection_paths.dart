class FirebaseCollectionPaths {
  const FirebaseCollectionPaths._();

  static const users = 'users';
  static const admins = 'admins';
  static const regions = 'regions';
  static const parkingLocations = 'parking_locations';
  static const parkingAreas = 'parking_areas';
  static const parkingAreaImages = 'parking_area_images';
  static const bookings = 'bookings';
  static const activeQrTickets = 'active_qr_tickets';
  static const reviews = 'reviews';
  static const issueReports = 'issue_reports';
  static const payments = 'payments';

  static String user(String userId) => '$users/$userId';
  static String admin(String adminId) => '$admins/$adminId';
  static String region(String regionId) => '$regions/$regionId';
  static String parkingLocation(String locationId) =>
      '$parkingLocations/$locationId';
  static String parkingArea(String areaId) => '$parkingAreas/$areaId';
  static String parkingAreaImage(String imageId) =>
      '$parkingAreaImages/$imageId';
  static String booking(String bookingId) => '$bookings/$bookingId';
  static String activeQrTicket(String qrId) => '$activeQrTickets/$qrId';
  static String review(String reviewId) => '$reviews/$reviewId';
  static String issueReport(String issueId) => '$issueReports/$issueId';
  static String payment(String paymentId) => '$payments/$paymentId';
}
