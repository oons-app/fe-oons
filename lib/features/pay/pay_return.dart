/// Paymob redirects here after card / wallet. Stay in-app and poll status.
bool isPayReturnUrl(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'oons') return true;
  if (scheme != 'http' && scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  final ours = host == 'lady.oons.app' ||
      host == 'www.oons.app' ||
      host == 'oons.app' ||
      host.endsWith('.oons.app');
  if (!ours) return false;
  final path = uri.path.toLowerCase();
  return path.startsWith('/confirmed') ||
      path.startsWith('/pay') ||
      path.startsWith('/booking') ||
      path.startsWith('/bookings') ||
      path.startsWith('/payfail');
}
