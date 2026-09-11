/// Staff roles as returned by the API (server source of truth keys).
const roleSuper = 'super_admin';
const roleOps = 'operations';
const roleFinance = 'finance';
const roleVendor = 'vendor_acquisition';
const roleAm = 'account_manager';

/// Prototype labels mapped onto API roles.
String roleLabel(String apiRole) {
  switch (apiRole) {
    case roleSuper:
      return 'super_admin';
    case roleOps:
      return 'ops';
    case roleFinance:
      return 'finance';
    case roleVendor:
      return 'vendor_acq';
    case roleAm:
      return 'account_manager';
    default:
      return apiRole;
  }
}

/// Grant map fetched from `GET /admin/rbac/matrix` on sign-in — the server's
/// `staffrbac.Can` table. `staffCan` consults this first; the switch below is
/// only a pre-login / offline fallback.
Map<String, Map<String, bool>> _serverGrants = const {};

void setStaffGrants(Map<String, Map<String, bool>> grants) => _serverGrants = grants;

/// Screen / action permissions. Prefers the server RBAC matrix; falls back to
/// the local table (which mirrors `staffrbac.Can`).
bool staffCan(String role, String perm) {
  if (role == roleSuper) return true;
  final row = _serverGrants[role];
  if (row != null) {
    if (row[perm] == true) return true;
    if (row['*'] == true) return true;
    // Server row present but perm absent/false → trust it, skip the fallback.
    if (row.containsKey(perm)) return false;
  }
  switch (perm) {
    case 'staff.write':
      return false;
    case 'corporate.write':
      return false;
    case 'payments.settings':
      return role == roleFinance;
    case 'providers.vet':
    case 'id.photos':
      return role == roleOps || role == roleVendor;
    case 'providers.read':
      return role == roleVendor || role == roleOps || role == roleAm;
    case 'bookings.read':
      return role == roleOps || role == roleAm || role == roleFinance;
    case 'bookings.write':
      return role == roleOps;
    case 'payouts.read':
    case 'payouts.write':
      return role == roleFinance || role == roleOps;
    case 'ledger.read':
      return role == roleFinance;
    case 'audit.read':
      return role == roleOps;
    case 'users.read':
      return role == roleOps || role == roleAm || role == roleFinance;
    case 'users.write':
      return role == roleOps || role == roleAm;
    case 'providers.impersonate':
    case 'users.impersonate':
      return role == roleOps;
    case 'notes.write':
      return role == roleAm || role == roleOps;
    case 'categories.write':
    case 'areas.write':
      return role == roleOps;
    case 'provider_categories.write':
    case 'service_requests.write':
      return role == roleVendor || role == roleOps;
    case 'claims.read':
      return role == roleOps || role == roleFinance;
    case 'claims.write':
      return role == roleOps;
    case 'coupons.read':
      return role == roleOps || role == roleFinance;
    case 'coupons.write':
      return role == roleOps;
    case 'home.read':
      return true;
  }
  return false;
}

/// Whether a nav screen id is visible for [role] (prototype PERMS.read).
bool canSeeScreen(String role, String screenId) {
  if (role == roleSuper) return true;
  // staff / matrix / corporate — super only (early return above)
  const ops = {
    'home', 'live', 'bookings', 'booking', 'claims', 'customers', 'customer',
    'providers', 'provider', 'categoryRequests', 'serviceRequests', 'batches', 'heatmap', 'vetting', 'workerVetting', 'audit',
    'coupons', 'categories', 'areas', 'impersonate',
    'refunds', 'analytics', 'liveMap',
  };
  const finance = {
    'home', 'payouts', 'ledger', 'coupons', 'batches', 'payments', 'audit', 'bookings', 'booking',
    'refunds',
  };
  const vendor = {
    'home', 'providers', 'provider', 'categoryRequests', 'serviceRequests', 'vetting', 'workerVetting', 'heatmap',
  };
  const am = {
    'home', 'bookings', 'booking', 'customers', 'customer', 'providers', 'provider',
  };
  switch (role) {
    case roleOps:
      return ops.contains(screenId);
    case roleFinance:
      return finance.contains(screenId);
    case roleVendor:
      return vendor.contains(screenId);
    case roleAm:
      return am.contains(screenId);
    default:
      return false;
  }
}

const allPermKeys = [
  'home.read',
  'bookings.read',
  'bookings.write',
  'providers.read',
  'providers.vet',
  'providers.impersonate',
  'users.read',
  'users.write',
  'users.impersonate',
  'claims.read',
  'claims.write',
  'payouts.read',
  'payouts.write',
  'ledger.read',
  'coupons.read',
  'coupons.write',
  'categories.write',
  'areas.write',
  'provider_categories.write',
  'service_requests.write',
  'payments.settings',
  'staff.write',
  'corporate.write',
  'audit.read',
  'notes.write',
  'id.photos',
];
