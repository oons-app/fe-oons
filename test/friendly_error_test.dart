import 'package:flutter_test/flutter_test.dart';
import 'package:oons/data/api.dart';
import 'package:oons/l10n/errors.dart';

void main() {
  test('an Arabic provider reason is not replaced by the generic form sentence', () {
    const generic = 'هناك بيانات غير صحيحة في النموذج. راجعيها وحاولي مرة أخرى.';
    const reasons = [
      'اقبلي الزيارة الأول عشان تشوفي بيانات العميلة.',
      'تقدري تتحركي بعد ما الدفع يتأكد.',
      'الزيارة دي مش مستنياكي.',
      'ابدئي الطريق الأول.',
      'صوّري المكان وابعتي موقعك قبل ما تدخلي.',
    ];
    for (final msg in reasons) {
      expect(friendlyError(ApiException(409, msg), 'ar'), msg);
      expect(friendlyError(ApiException(409, msg), 'ar'), isNot(generic));
    }
  });
}
