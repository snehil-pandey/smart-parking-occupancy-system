String formatInr(num value) {
  final rounded = value.round();
  return 'Rs. $rounded';
}

String formatParkingRate(num pricePerHour) {
  if (pricePerHour <= 0) {
    return 'Free';
  }
  return '${formatInr(pricePerHour)}/hr';
}
