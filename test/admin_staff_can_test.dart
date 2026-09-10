import 'package:flutter_test/flutter_test.dart';
import 'package:oons/admin/session.dart';

void main() {
  group('staffCan', () {
    test('super sees everything', () {
      expect(staffCan(roleSuper, 'staff.write'), isTrue);
      expect(staffCan(roleSuper, 'coupons.write'), isTrue);
      expect(staffCan(roleSuper, 'users.impersonate'), isTrue);
    });

    test('ops day-to-day reach', () {
      expect(staffCan(roleOps, 'bookings.write'), isTrue);
      expect(staffCan(roleOps, 'providers.vet'), isTrue);
      expect(staffCan(roleOps, 'claims.write'), isTrue);
      expect(staffCan(roleOps, 'coupons.write'), isTrue);
      expect(staffCan(roleOps, 'staff.write'), isFalse);
      expect(staffCan(roleOps, 'payments.settings'), isFalse);
    });

    test('finance money + read-only coupons', () {
      expect(staffCan(roleFinance, 'payouts.write'), isTrue);
      expect(staffCan(roleFinance, 'ledger.read'), isTrue);
      expect(staffCan(roleFinance, 'payments.settings'), isTrue);
      expect(staffCan(roleFinance, 'coupons.read'), isTrue);
      expect(staffCan(roleFinance, 'coupons.write'), isFalse);
      expect(staffCan(roleFinance, 'providers.vet'), isFalse);
    });

    test('vendor acquisition vetting', () {
      expect(staffCan(roleVendor, 'providers.read'), isTrue);
      expect(staffCan(roleVendor, 'providers.vet'), isTrue);
      expect(staffCan(roleVendor, 'provider_categories.write'), isTrue);
      expect(staffCan(roleVendor, 'bookings.write'), isFalse);
    });
  });
}
