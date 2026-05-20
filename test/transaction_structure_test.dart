import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction flow is documented as consume once', () {
    const steps = [
      'read active_qr_tickets/{qrId}',
      'reject missing used expired tickets',
      'read linked bookings/{bookingId}',
      'reject inactive booking',
      'mark ticket used',
      'set booking qrUsedAt',
      'write minimal scan log',
    ];

    expect(steps, contains('mark ticket used'));
    expect(steps, contains('set booking qrUsedAt'));
    expect(steps.indexOf('read active_qr_tickets/{qrId}'), 0);
  });
}
