import 'package:flutter_test/flutter_test.dart';
import 'package:oons/core/format.dart';
import 'package:oons/features/pay/pay_return.dart';

void main() {
  test('Paymob return URLs stay in-app', () {
    expect(isPayReturnUrl('https://lady.oons.app/confirmed/abc'), isTrue);
    expect(isPayReturnUrl('https://lady.oons.app/payfail'), isTrue);
    expect(isPayReturnUrl('oons://pay/done'), isTrue);
    expect(isPayReturnUrl('https://accept.paymob.com/unifiedcheckout/?x=1'), isFalse);
    expect(isPayReturnUrl('https://accept.paymob.com/api/acceptance/iframes/1'), isFalse);
    expect(isPayReturnUrl('https://acs.bank.com/3ds'), isFalse);
  });

  test('payment method labels include InstaPay transfer', () {
    expect(paymentMethodLabel('manual', 'en'), 'InstaPay');
    expect(paymentMethodLabel('instapay_manual', 'ar'), 'إنستاباي');
    expect(paymentMethodLabel('instapay', 'en'), 'Mobile Wallet');
    expect(paymentMethodLabel('card', 'en'), 'Credit Card');
  });
}
