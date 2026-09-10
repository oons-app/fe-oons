import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin/api.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/data/api.dart';

const roleSuper = 'super_admin';
const roleOps = 'operations';
const roleFinance = 'finance';
const roleVendor = 'vendor_acquisition';
const roleAm = 'account_manager';

const staffRoleChoices = [roleSuper, roleOps, roleFinance, roleVendor, roleAm];

bool staffCan(String role, String perm) {
  if (role == roleSuper) return true;
  switch (perm) {
    case 'staff.write':
      return false;
    case 'payments.settings':
      return role == roleFinance;
    case 'providers.vet':
      return role == roleOps || role == roleVendor;
    case 'id.photos':
      return role == roleVendor || role == roleOps;
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
    case 'providers.impersonate':
      return role == roleOps || role == roleSuper;
    case 'users.impersonate':
      return role == roleOps || role == roleSuper;
    case 'notes.write':
      return role == roleAm || role == roleOps;
    case 'categories.write':
      return role == roleOps || role == roleSuper;
    case 'areas.write':
      return role == roleOps || role == roleSuper;
    case 'provider_categories.write':
      return role == roleVendor || role == roleOps;
    case 'claims.read':
      return role == roleOps || role == roleFinance;
    case 'claims.write':
      return role == roleOps;
    case 'coupons.read':
      return role == roleOps || role == roleFinance;
    case 'coupons.write':
      return role == roleOps;
  }
  return false;
}

/// Effective role for UI gating (supports super-admin "view as").
String effectiveStaffRole(StaffState s) {
  if (s.staffRole == roleSuper && (s.viewAsRole ?? '').isNotEmpty) {
    return s.viewAsRole!;
  }
  return s.staffRole;
}

class StaffState {
  const StaffState({
    this.token,
    this.staffRole = '',
    this.staff,
    this.ready = false,
    this.viewAsRole,
    this.impersonatingId,
    this.impersonatingName,
    this.impersonatingKind,
    this.impersonateToken,
  });
  final String? token;
  final String staffRole;
  final Map? staff;
  final bool ready;
  /// UI-only role preview for super_admin. Null = use real role.
  final String? viewAsRole;
  /// Active impersonation preview in the admin shell (admin JWT stays active; view is read-only).
  final String? impersonatingId;
  final String? impersonatingName;
  /// `provider` or `customer`
  final String? impersonatingKind;
  final String? impersonateToken;
  bool get authed => token != null;
  bool get isImpersonating => (impersonatingId ?? '').isNotEmpty;

  @Deprecated('Use impersonatingId')
  String? get impersonatingProviderId => impersonatingId;
  @Deprecated('Use impersonatingName')
  String? get impersonatingProviderName => impersonatingName;
}

final staffSessionProvider = StateNotifierProvider<StaffSession, StaffState>((ref) => StaffSession());

class StaffSession extends StateNotifier<StaffState> {
  StaffSession() : super(const StaffState()) {
    _restore();
  }

  Future<void> _restore() async {
    final t = staffApi.readToken();
    if (t == null) {
      state = const StaffState(ready: true);
      return;
    }
    staffApi.token = t;
    try {
      final me = await staffApi.get('/admin/me');
      state = StaffState(
        token: t,
        staffRole: '${me['staffRole'] ?? ''}',
        staff: me['staff'] is Map ? me['staff'] as Map : null,
        ready: true,
      );
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        await staffApi.persistToken(null);
      }
      state = const StaffState(ready: true);
    } catch (_) {
      state = const StaffState(ready: true);
    }
  }

  Future<void> login(String email, String password) async {
    final r = await staffApi.post('/admin/login', data: {'email': email, 'password': password});
    final token = r['accessToken'] as String;
    staffApi.token = token;
    state = StaffState(
      token: token,
      staffRole: '${r['staffRole'] ?? ''}',
      staff: r['staff'] is Map ? r['staff'] as Map : null,
      ready: true,
    );
    await staffApi.persistToken(token);
    await AppAnalytics.staffLogin();
    final sid = '${r['staff'] is Map ? (r['staff'] as Map)['id'] ?? email : email}';
    await AppAnalytics.identify(userId: sid, audience: AnalyticsAudience.admin, country: 'EG');
  }

  void setViewAsRole(String? role) {
    if (state.staffRole != roleSuper) return;
    state = StaffState(
      token: state.token,
      staffRole: state.staffRole,
      staff: state.staff,
      ready: state.ready,
      viewAsRole: (role == null || role == roleSuper) ? null : role,
      impersonatingId: state.impersonatingId,
      impersonatingName: state.impersonatingName,
      impersonatingKind: state.impersonatingKind,
      impersonateToken: state.impersonateToken,
    );
  }

  void startImpersonation({
    required String id,
    required String name,
    required String token,
    String kind = 'provider',
  }) {
    state = StaffState(
      token: state.token,
      staffRole: state.staffRole,
      staff: state.staff,
      ready: state.ready,
      viewAsRole: state.viewAsRole,
      impersonatingId: id,
      impersonatingName: name,
      impersonatingKind: kind,
      impersonateToken: token,
    );
  }

  void clearImpersonation() {
    state = StaffState(
      token: state.token,
      staffRole: state.staffRole,
      staff: state.staff,
      ready: state.ready,
      viewAsRole: state.viewAsRole,
    );
  }

  Future<void> signOut() async {
    await staffApi.persistToken(null);
    state = const StaffState(ready: true);
    await AppAnalytics.clearIdentity();
  }
}

String locName(dynamic v, String lang) {
  if (v is Map) return '${v[lang] ?? v['ar'] ?? v['en'] ?? ''}';
  return v == null ? '' : '$v';
}
