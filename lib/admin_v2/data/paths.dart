/// Browser paths for Ops Console v2 (`--base-href /`).
abstract final class V2Paths {
  static const root = '/';
  static const login = '/login';
  static const home = '/home';
  static const live = '/live';
  static const bookings = '/bookings';
  static const customers = '/customers';
  static const providers = '/providers';
  static const claims = '/claims';
  static const categoryRequests = '/category-requests';
  static const serviceRequests = '/service-requests';
  static const payouts = '/payouts';
  static const ledger = '/ledger';
  static const coupons = '/coupons';
  static const batches = '/batches';
  static const categories = '/categories';
  static const areas = '/areas';
  static const staff = '/staff';
  static const matrix = '/matrix';
  static const payments = '/payments';
  static const corporate = '/corporate';
  static const audit = '/audit';
  static const heatmap = '/heatmap';
  static const vetting = '/vetting';
  static const workerVetting = '/worker-vetting';
  static const impersonate = '/impersonate';
  static const refunds = '/refunds';
  static const analytics = '/analytics';
  static const liveMap = '/live-map';

  static String booking(String id) => '$bookings/$id';
  static String customer(String id) => '$customers/$id';
  static String provider(String id) => '$providers/$id';
  static String impersonateSubject(String id, {String kind = 'provider'}) =>
      '$impersonate/$id?kind=$kind';
}

/// Nav groups matching the HTML prototype.
class NavGroup {
  const NavGroup(this.labelEn, this.labelAr, this.items);
  final String labelEn;
  final String labelAr;
  final List<NavItem> items;
}

class NavItem {
  const NavItem(this.id, this.path, this.labelEn, this.labelAr, {this.permScreen});
  final String id;
  final String path;
  final String labelEn;
  final String labelAr;
  final String? permScreen;
}

const v2Nav = [
  NavGroup('Daily ops', 'التشغيل اليومي', [
    NavItem('home', V2Paths.home, 'Ops console', 'لوحة التشغيل'),
    NavItem('live', V2Paths.live, 'Live visits', 'زيارات مباشرة'),
    NavItem('bookings', V2Paths.bookings, 'Bookings', 'الحجوزات'),
    NavItem('claims', V2Paths.claims, 'Claims', 'المطالبات'),
  ]),
  NavGroup('People', 'الأشخاص', [
    NavItem('customers', V2Paths.customers, 'Customers', 'العميلات'),
    NavItem('providers', V2Paths.providers, 'Providers', 'المهنيات'),
    NavItem('categoryRequests', V2Paths.categoryRequests, 'Category requests', 'طلبات التخصص'),
    NavItem('serviceRequests', V2Paths.serviceRequests, 'Service requests', 'خدمات قيد الموافقة'),
  ]),
  NavGroup('Money', 'المال', [
    NavItem('payouts', V2Paths.payouts, 'Payouts', 'السحوبات'),
    NavItem('ledger', V2Paths.ledger, 'Ledger', 'الأرصدة'),
    NavItem('coupons', V2Paths.coupons, 'Coupons', 'الكوبونات'),
    NavItem('batches', V2Paths.batches, 'Batch history', 'سجل الدفعات'),
    NavItem('refunds', V2Paths.refunds, 'Refunds', 'المرتجعات'),
  ]),
  NavGroup('Admin', 'الإدارة', [
    NavItem('categories', V2Paths.categories, 'Categories', 'الفئات'),
    NavItem('areas', V2Paths.areas, 'Coverage areas', 'مناطق التغطية'),
    NavItem('staff', V2Paths.staff, 'Staff', 'الفريق'),
    NavItem('payments', V2Paths.payments, 'Payments', 'المدفوعات'),
    NavItem('corporate', V2Paths.corporate, 'Corporate', 'الشركات'),
    NavItem('audit', V2Paths.audit, 'Audit', 'سجل التدقيق'),
    NavItem('analytics', V2Paths.analytics, 'Analytics', 'التحليلات'),
  ]),
  NavGroup('Insights', 'رؤى', [
    NavItem('heatmap', V2Paths.heatmap, 'Heatmap', 'الخريطة الحرارية'),
    NavItem('liveMap', V2Paths.liveMap, 'Live map', 'الخريطة المباشرة'),
    NavItem('vetting', V2Paths.vetting, 'Vetting SLA', 'مهلة التحقق'),
    NavItem('workerVetting', V2Paths.workerVetting, 'Team vetting', 'توثيق فرق العمل'),
  ]),
];
