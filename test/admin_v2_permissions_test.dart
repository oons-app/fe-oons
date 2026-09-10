import 'package:flutter_test/flutter_test.dart';
import 'package:oons/admin_v2/chrome/bulk_pay_bar.dart';
import 'package:oons/admin_v2/data/permissions.dart';

void main() {
  group('staffCan v2', () {
    test('super sees everything', () {
      expect(staffCan(roleSuper, 'staff.write'), isTrue);
      expect(staffCan(roleSuper, 'coupons.write'), isTrue);
      expect(staffCan(roleSuper, 'users.write'), isTrue);
      expect(staffCan(roleSuper, 'corporate.write'), isTrue);
      expect(canSeeScreen(roleSuper, 'matrix'), isTrue);
      expect(canSeeScreen(roleSuper, 'liveMap'), isTrue);
    });

    test('ops day-to-day', () {
      expect(staffCan(roleOps, 'bookings.write'), isTrue);
      expect(staffCan(roleOps, 'providers.vet'), isTrue);
      expect(staffCan(roleOps, 'users.write'), isTrue);
      expect(staffCan(roleOps, 'users.impersonate'), isTrue);
      expect(staffCan(roleOps, 'staff.write'), isFalse);
      expect(canSeeScreen(roleOps, 'refunds'), isTrue);
      expect(canSeeScreen(roleOps, 'liveMap'), isTrue);
      expect(canSeeScreen(roleOps, 'analytics'), isTrue);
      expect(canSeeScreen(roleOps, 'staff'), isFalse);
    });

    test('finance coupons read-only', () {
      expect(staffCan(roleFinance, 'coupons.read'), isTrue);
      expect(staffCan(roleFinance, 'coupons.write'), isFalse);
      expect(staffCan(roleFinance, 'payouts.write'), isTrue);
      expect(canSeeScreen(roleFinance, 'payments'), isTrue);
      expect(canSeeScreen(roleFinance, 'refunds'), isTrue);
    });

    test('vendor vetting', () {
      expect(staffCan(roleVendor, 'providers.vet'), isTrue);
      expect(canSeeScreen(roleVendor, 'providers'), isTrue);
      expect(canSeeScreen(roleVendor, 'payouts'), isFalse);
      expect(staffCan(roleVendor, 'users.write'), isFalse);
    });

    test('account manager users write', () {
      expect(staffCan(roleAm, 'users.write'), isTrue);
      expect(staffCan(roleAm, 'bookings.write'), isFalse);
    });
  });

  group('providerGrossFromBooking', () {
    test('excludes trust fee', () {
      expect(
        providerGrossFromBooking({'total': 50000, 'trustFeeAmount': 10000}),
        40000,
      );
    });

    test('never negative', () {
      expect(
        providerGrossFromBooking({'total': 1000, 'trustFeeAmount': 5000}),
        0,
      );
    });
  });
}
