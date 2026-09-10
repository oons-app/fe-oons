/// Browser paths for the staff dashboard (Ops Console v2).
///
/// The admin Flutter web build for bo.oons.app uses `--base-href /`.
class AdminPaths {
  static const root = '/';
  static const login = '/login';
  static const home = '/home';
  static const live = '/live';
  static const customers = '/customers';
  static const providers = '/providers';
  static const bookings = '/bookings';
  static const payouts = '/payouts';
  static const ledger = '/ledger';
  static const staff = '/staff';
  static const payments = '/payments';
  static const audit = '/audit';
  static const categories = '/categories';
  static const areas = '/areas';
  static const categoryRequests = '/category-requests';
  static const claims = '/claims';
  static const coupons = '/coupons';
  static const batches = '/batches';
  static const corporate = '/corporate';
  static const heatmap = '/heatmap';
  static const vetting = '/vetting';
  static const matrix = '/matrix';
  static const impersonate = '/impersonate';

  static String customer(String id) => '$customers/$id';
  static String provider(String id) => '$providers/$id';
  static String booking(String id) => '$bookings/$id';
  static String impersonateProvider(String id) => '$impersonate/$id?kind=provider';
  static String impersonateCustomer(String id) => '$impersonate/$id?kind=customer';
}
