import 'package:flutter_test/flutter_test.dart';
import 'package:oons/admin_v2/features/category_requests/category_requests_screen.dart';

// Regression test for a status-label bug that shipped twice: first the
// literal "active" key never matched a check for the word "approved", so
// every genuinely-approved category request showed as "Requested"; the fix
// for that then broadly matched the substring "approv", which also matches
// "pending_addition_approval" — a status that is NOT approved, it is
// pending one — so that got mislabeled "Approved" right along with the
// real ones. Pin every real backend status key to its correct label so a
// third variant of this bug fails a test instead of shipping.
void main() {
  test('active is Approved', () {
    expect(categoryRequestStatusLabel('active'), 'Approved');
  });

  test('pending_addition_approval is Requested, not Approved', () {
    expect(categoryRequestStatusLabel('pending_addition_approval'), 'Requested');
  });

  test('pending_initial_vetting is Requested', () {
    expect(categoryRequestStatusLabel('pending_initial_vetting'), 'Requested');
  });

  test('rejected is Rejected', () {
    expect(categoryRequestStatusLabel('rejected'), 'Rejected');
  });

  test('changes_requested is Requested (not Approved, not Rejected)', () {
    expect(categoryRequestStatusLabel('changes_requested'), 'Requested');
  });

  test('is case-insensitive', () {
    expect(categoryRequestStatusLabel('ACTIVE'), 'Approved');
  });
}
