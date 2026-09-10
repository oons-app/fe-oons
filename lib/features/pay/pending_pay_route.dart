/// Routes for unfinished checkouts (card / InstaPay / Fawry).
String pendingPayRoute(String bookingId, {String? paymentMethod, String? fawryCode}) {
  final m = (paymentMethod ?? '').toLowerCase().trim();
  if (m == 'fawry' || (fawryCode != null && fawryCode.isNotEmpty)) {
    return '/pay/$bookingId/fawry';
  }
  if (m == 'instapay' || m == 'wallet') {
    return '/pay/$bookingId/instapay';
  }
  if (m == 'card') {
    return '/pay/$bookingId/card';
  }
  // Method not chosen yet — back to checkout method frames.
  return '/checkout/$bookingId';
}
