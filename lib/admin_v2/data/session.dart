import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/data/api.dart';

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
  final String? viewAsRole;
  final String? impersonatingId;
  final String? impersonatingName;
  final String? impersonatingKind;
  final String? impersonateToken;

  bool get authed => token != null;
  bool get isImpersonating => (impersonatingId ?? '').isNotEmpty;

  String get effectiveRole {
    if (staffRole == roleSuper && (viewAsRole ?? '').isNotEmpty) return viewAsRole!;
    return staffRole;
  }
}

final staffSessionProvider = StateNotifierProvider<StaffSession, StaffState>((ref) => StaffSession());

class StaffSession extends StateNotifier<StaffState> {
  StaffSession() : super(const StaffState()) {
    _restore();
  }

  Future<void> _restore() async {
    final t = staffClient.readToken();
    if (t == null) {
      state = const StaffState(ready: true);
      return;
    }
    staffClient.token = t;
    try {
      final me = await staffClient.get('/admin/me');
      state = StaffState(
        token: t,
        staffRole: '${me['staffRole'] ?? ''}',
        staff: me['staff'] is Map ? me['staff'] as Map : null,
        ready: true,
      );
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) await staffClient.persistToken(null);
      state = const StaffState(ready: true);
    } catch (_) {
      state = const StaffState(ready: true);
    }
  }

  Future<void> login(String email, String password) async {
    final r = await staffClient.post('/admin/login', data: {'email': email, 'password': password});
    final token = r['accessToken'] as String;
    staffClient.token = token;
    state = StaffState(
      token: token,
      staffRole: '${r['staffRole'] ?? ''}',
      staff: r['staff'] is Map ? r['staff'] as Map : null,
      ready: true,
    );
    await staffClient.persistToken(token);
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
    staffClient.subjectToken = token;
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
    staffClient.subjectToken = null;
    state = StaffState(
      token: state.token,
      staffRole: state.staffRole,
      staff: state.staff,
      ready: state.ready,
      viewAsRole: state.viewAsRole,
    );
  }

  Future<void> signOut() async {
    await staffClient.persistToken(null);
    state = const StaffState(ready: true);
  }
}

String locName(dynamic v, String lang) {
  if (v is Map) return '${v[lang] ?? v['ar'] ?? v['en'] ?? ''}'.trim();
  if (v == null) return '';
  final s = '$v'.trim();
  return s == 'null' ? '' : s;
}

int asInt(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) {
    final t = v.trim();
    if (t.isEmpty) return 0;
    return int.tryParse(t) ?? double.tryParse(t)?.toInt() ?? 0;
  }
  return 0;
}

double asDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse('$v') ?? 0;
}
