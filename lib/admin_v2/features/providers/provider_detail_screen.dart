import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/core/format.dart';
import 'package:oons/data/api.dart';

const _tabs = ['Overview', 'Documents', 'Team', 'Services', 'Coverage', 'Portfolio', 'Money'];

class ProviderDetailScreen extends ConsumerStatefulWidget {
  const ProviderDetailScreen({super.key, required this.providerId, this.initialTab});
  final String providerId;
  final String? initialTab;

  @override
  ConsumerState<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen> {
  Map<String, dynamic>? p;
  Map<String, dynamic> ledger = {};
  List<Map<String, dynamic>> jobs = [];
  bool loading = true;
  String? error;
  String tab = 'Overview';
  List<Map<String, dynamic>> areas = [];
  List<Map<String, dynamic>> workers = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialTab != null && _tabs.contains(widget.initialTab)) {
      tab = widget.initialTab!;
    }
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/providers/${widget.providerId}');
      // The provider DTO carries no ledger or job history — pull them alongside.
      final results = await Future.wait([
        staffClient
            .get('/admin/ledger', query: {'providerId': widget.providerId})
            .catchError((_) => <String, dynamic>{}),
        staffClient
            .get('/admin/bookings', query: {'providerId': widget.providerId, 'limit': 20})
            .catchError((_) => <String, dynamic>{}),
        staffClient
            .get('/admin/providers/${widget.providerId}/workers')
            .catchError((_) => <String, dynamic>{}),
      ]);
      final led = asMapList(results[0]['ledgers'] ?? results[0]['ledger']);
      setState(() {
        p = unwrapEntity(data, const ['provider']);
        ledger = led.isNotEmpty ? led.first : {};
        jobs = asMapList(results[1]['bookings']);
        workers = asMapList(results[2]['workers']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _areasOnce() async {
    if (areas.isNotEmpty) return;
    try {
      final data = await staffClient.get('/admin/areas');
      setState(() => areas = asMapList(data['areas']));
    } catch (e) {
      debugPrint('provider detail: coverage areas fetch failed: $e');
    }
  }

  String get _role => ref.read(staffSessionProvider).effectiveRole;
  String get _roleLabel => roleLabel(_role);

  Future<void> _post(String path, {Object? data, required String okMsg}) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.post(path, data: data);
      if (mounted) {
        v2Toast(context, okMsg);
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, lang == 'ar' ? e.message : e.message, error: true);
    }
  }

  Future<void> _patch(String path, Object data, String okMsg) async {
    try {
      await staffClient.patch(path, data: data);
      if (mounted) {
        v2Toast(context, okMsg);
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _confirmThen(String title, String body, String confirm, VoidCallback run, {bool danger = false}) async {
    final ok = await v2Confirm(context, title: title, body: body, confirmLabel: confirm, danger: danger, roleLabel: _roleLabel);
    if (ok) run();
  }

  Future<void> _impersonate() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final r = await staffClient.post('/admin/providers/${widget.providerId}/impersonate');
      final token = '${r['accessToken'] ?? r['impersonateToken'] ?? ''}';
      if (token.isEmpty) return;
      ref.read(staffSessionProvider.notifier).startImpersonation(
          id: widget.providerId, name: personName(p, lang, fallbackId: widget.providerId), token: token, kind: 'provider');
      if (mounted) context.go(V2Paths.impersonateSubject(widget.providerId, kind: 'provider'));
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _appendNote(String text) async {
    final prov = p ?? {};
    final existing = '${prov['staffNotes'] ?? ''}'.trim();
    final stamp = DateTime.now().toIso8601String().substring(0, 16).replaceFirst('T', ' ');
    final line = '$text  — $_roleLabel · $stamp';
    final next = existing.isEmpty ? line : '$existing\n$line';
    await _patch('/admin/providers/${widget.providerId}/notes', {'notes': next},
        ref.read(localeCodeProvider) == 'ar' ? 'تم حفظ الملاحظة' : 'Note saved');
  }

  Future<void> _editProfile() async {
    final lang = ref.read(localeCodeProvider);
    final prov = p ?? {};
    final first = TextEditingController(text: '${prov['firstName'] ?? ''}');
    final phone = TextEditingController(text: '${prov['phone'] ?? ''}');
    final bio = TextEditingController(text: '${prov['bio'] ?? ''}');
    try {
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'تعديل الملف' : 'Edit profile',
        bodyBuilder: (ctx, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(label: lang == 'ar' ? 'الاسم' : 'Name', child: TextField(controller: first)),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'الهاتف' : 'Phone', child: TextField(controller: phone)),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'نبذة' : 'Bio', child: TextField(controller: bio, maxLines: 3)),
          ],
        ),
      );
      if (ok) {
        _patch('/admin/providers/${widget.providerId}',
            {'firstName': first.text.trim(), 'phone': phone.text.trim(), 'bio': bio.text.trim()},
            lang == 'ar' ? 'تم تحديث الملف' : 'Profile updated');
      }
    } finally {
      first.dispose();
      phone.dispose();
      bio.dispose();
    }
  }

  Future<void> _suspendOrReinstate(bool suspended) async {
    final lang = ref.read(localeCodeProvider);
    if (suspended) {
      _confirmThen(
        lang == 'ar' ? 'إعادة التفعيل؟' : 'Reinstate provider?',
        lang == 'ar' ? 'يعود الملف نشطاً وقابلاً للحجز.' : 'The profile becomes active and bookable again.',
        lang == 'ar' ? 'إعادة تفعيل' : 'Reinstate',
        () => _post('/admin/providers/${widget.providerId}/reinstate',
            okMsg: lang == 'ar' ? 'تمت إعادة التفعيل' : 'Reinstated'),
      );
      return;
    }
    var reason = '';
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'إيقاف المهنية' : 'Suspend provider',
      confirmLabel: lang == 'ar' ? 'إيقاف' : 'Suspend',
      danger: true,
      bodyBuilder: (ctx, _) => V2FormField(
        label: lang == 'ar' ? 'سبب الإيقاف' : 'Suspension reason',
        child: TextField(onChanged: (v) => reason = v, maxLines: 3),
      ),
      onValidate: () {
        if (reason.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'أدخلي سبباً' : 'Enter a reason', error: true);
          return false;
        }
        return true;
      },
    );
    if (ok) {
      _post('/admin/providers/${widget.providerId}/suspend',
          data: {'reason': reason.trim()}, okMsg: lang == 'ar' ? 'تم الإيقاف' : 'Suspended');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'providers.read')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    if (loading) return const Padding(padding: EdgeInsets.only(top: 60), child: V2Loading());
    if (error != null) {
      return Padding(padding: const EdgeInsets.all(Ops.gutter), child: V2ErrorBanner(message: error!, onRetry: _load));
    }
    final prov = p;
    if (prov == null) return const V2Empty();

    final canVet = staffCan(role, 'providers.vet');
    final canWrite = staffCan(role, 'providers.write') || canVet;
    final name = personName(prov, lang, fallbackId: idOf(prov));
    final vetting = providerVetting(prov, lang);
    final state = providerState(prov, lang);
    final suspended = providerState(prov, 'en').toLowerCase() == 'suspended';
    final reverifyAt = parseTime(prov['reverifyAt']);
    final blocker = () {
      if (providerVetting(prov, 'en') == 'Vetted') return lang == 'ar' ? 'كل الفحوصات مكتملة' : 'All checks complete';
      if (providerVetting(prov, 'en') == 'Awaiting docs') {
        return lang == 'ar' ? 'مستندات ناقصة — الهوية والفيش' : 'Documents missing — ID and FISH';
      }
      return lang == 'ar' ? 'المستندات مرفوعة، بانتظار المراجعة' : 'Docs uploaded, awaiting review';
    }();

    return ColoredBox(
      color: Ops.page,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(Ops.gutter, 20, Ops.gutter, 60),
        children: [
          // Header row
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              V2Btn(label: lang == 'ar' ? '→ المهنيات' : '← Providers', onPressed: () => context.go(V2Paths.providers)),
              V2StatusPill(label: vetting, tone: vettingTone(prov), large: true),
              V2StatusPill(label: state, tone: providerStateTone(prov), large: true),
              Text('${prov['phone'] ?? ''}', style: const TextStyle(fontSize: 13, color: Ops.muted, fontFamily: Ops.mono)),
              const SizedBox(width: 1),
              if (staffCan(role, 'providers.impersonate')) V2Btn.imp('Impersonate', onPressed: _impersonate),
              if (canWrite) V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: _editProfile),
            ],
          ),
          const SizedBox(height: 16),

          // Vetting strip
          if (canVet)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 15),
              decoration: BoxDecoration(
                color: Ops.panelSand,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Ops.panelSandBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    reverifyAt != null
                        ? '${lang == 'ar' ? 'التحقق · إعادة في' : 'Vetting · re-verify due'} ${formatDayOnly(prov['reverifyAt'])}'
                        : (lang == 'ar' ? 'التحقق' : 'Vetting'),
                    style: const TextStyle(fontSize: 11.5, color: Ops.muted),
                  ),
                  const SizedBox(height: 2),
                  Text(blocker, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      if (providerVetting(prov, 'en') != 'Vetted')
                        V2Btn(
                          label: lang == 'ar' ? 'تحقّق' : 'Vet',
                          kind: V2BtnKind.primary,
                          size: V2BtnSize.sm,
                          onPressed: () => _confirmThen(
                            lang == 'ar' ? 'التحقق من $name؟' : 'Vet $name?',
                            lang == 'ar' ? 'يجعل الملف موثّقاً وقابلاً للحجز.' : 'Marks the profile vetted and makes it bookable.',
                            lang == 'ar' ? 'تحقّق' : 'Vet',
                            () => _post('/admin/providers/${widget.providerId}/vet',
                                data: {'sexMarkerConfirmed': true}, okMsg: lang == 'ar' ? 'تم التحقق' : '$name vetted'),
                          ),
                        ),
                      V2Btn(
                        label: lang == 'ar' ? 'رفض' : 'Reject',
                        kind: V2BtnKind.danger,
                        size: V2BtnSize.sm,
                        onPressed: () => _confirmThen(
                          lang == 'ar' ? 'رفض $name؟' : 'Reject $name?',
                          lang == 'ar' ? 'تُبلَّغ المهنية ولا تستطيع أخذ حجوزات.' : 'The pro is notified and cannot take bookings.',
                          lang == 'ar' ? 'رفض' : 'Reject',
                          () => _post('/admin/providers/${widget.providerId}/reject',
                              okMsg: lang == 'ar' ? 'تم الرفض' : '$name rejected'),
                          danger: true,
                        ),
                      ),
                      V2Btn(
                        label: suspended
                            ? (lang == 'ar' ? 'إعادة تفعيل' : 'Reinstate')
                            : (lang == 'ar' ? 'إيقاف' : 'Suspend'),
                        kind: V2BtnKind.ghost,
                        size: V2BtnSize.sm,
                        onPressed: () => _suspendOrReinstate(suspended),
                      ),
                      V2Btn(
                        label: lang == 'ar' ? 'جدولة إعادة تحقق' : 'Schedule re-verify',
                        kind: V2BtnKind.ghost,
                        size: V2BtnSize.sm,
                        onPressed: () => _confirmThen(
                          lang == 'ar' ? 'جدولة إعادة التحقق؟' : 'Schedule re-verify?',
                          'POST /admin/providers/${widget.providerId}/reverify — ${lang == 'ar' ? 'يحدد الفحص التالي بعد سنة.' : 'sets the next check one year out.'}',
                          lang == 'ar' ? 'جدولة' : 'Schedule',
                          () => _post('/admin/providers/${widget.providerId}/reverify',
                              okMsg: lang == 'ar' ? 'تمت جدولة إعادة التحقق' : 'Re-verify scheduled for $name'),
                        ),
                      ),
                      V2Btn(
                        label: lang == 'ar' ? 'طلب مستند' : 'Request document',
                        kind: V2BtnKind.ghost,
                        size: V2BtnSize.sm,
                        onPressed: () => _appendNote(lang == 'ar' ? 'طُلب رفع مستند من المهنية' : 'Document re-upload requested'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),

          // Tabs
          V2TabBar(tabs: _tabs, active: tab, onSelect: (t) {
            setState(() => tab = t);
            if (t == 'Coverage') _areasOnce();
          }),
          const SizedBox(height: 16),

          if (tab == 'Overview') _overview(prov, lang, canWrite),
          if (tab == 'Documents') _documents(prov, lang, canVet),
          if (tab == 'Team') _team(lang, canVet),
          if (tab == 'Services') _services(prov, lang, canWrite),
          if (tab == 'Coverage') _coverage(prov, lang, canVet),
          if (tab == 'Portfolio') _portfolio(prov, lang, canVet),
          if (tab == 'Money') _money(prov, lang, canVet),
        ],
      ),
    );
  }

  // ---- Overview -------------------------------------------------------------
  Widget _overview(Map prov, String lang, bool canWrite) {
    final notes = '${prov['staffNotes'] ?? ''}'.trim();
    final years = asInt(prov['years'] ?? prov['experience'] ?? prov['experienceYears']);
    final specialty = locName(prov['specialty'], lang);
    final category = '${prov['service'] ?? prov['category'] ?? prov['vertical'] ?? ''}'
        '${specialty.isNotEmpty ? ' · $specialty' : ''}';
    final done = jobs.where((b) => '${b['status']}'.toLowerCase() == 'completed' || '${b['status']}'.toLowerCase() == 'released').length;
    final facts = <(String, String)>[
      (lang == 'ar' ? 'الاسم على الهوية' : 'Name on ID', personName(prov, lang, fallbackId: idOf(prov))),
      (lang == 'ar' ? 'الرقم القومي' : 'National ID', '${prov['nationalId'] ?? prov['national'] ?? ''}'),
      (lang == 'ar' ? 'الهاتف' : 'Phone', '${prov['phone'] ?? ''}'),
      (lang == 'ar' ? 'الفئة' : 'Category', category),
      (lang == 'ar' ? 'الخبرة' : 'Experience', years > 0 ? '$years ${lang == 'ar' ? 'سنة' : 'yrs'}' : '—'),
      (lang == 'ar' ? 'انضمّت' : 'Joined', formatDayOnly(prov['consentedAt'] ?? prov['createdAt'])),
      (lang == 'ar' ? 'التقييم' : 'Rating', asDouble(prov['rating']).toStringAsFixed(1)),
    ];
    return _twoCol(
      lang,
      leftFlex: 1,
      rightFlex: 12 ~/ 10,
      left: [
        V2SectionCard(
          title: lang == 'ar' ? 'الملف' : 'Profile',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final f in facts) _kv(f.$1, f.$2),
              const SizedBox(height: 4),
              Text(lang == 'ar' ? 'نبذة' : 'Bio', style: const TextStyle(fontSize: 12, color: Ops.muted)),
              const SizedBox(height: 4),
              Text('${prov['bio'] ?? ''}', style: const TextStyle(fontSize: 13, height: 1.6)),
            ],
          ),
        ),
        _registrationSteps(prov, lang),
      ],
      right: [
        V2SectionCard(
          title: lang == 'ar' ? 'الأداء' : 'Performance',
          child: _statGrid([
            (lang == 'ar' ? 'الوظائف' : 'Jobs', '${jobs.length}'),
            (lang == 'ar' ? 'التقييم' : 'Rating', asDouble(prov['rating']).toStringAsFixed(1)),
            (lang == 'ar' ? 'مكتملة' : 'Completed', '$done'),
            (lang == 'ar' ? 'المراجعات' : 'Reviews', '${asInt(prov['reviewCount'])}'),
          ]),
        ),
        V2SectionCard(
          title: lang == 'ar' ? 'ملاحظات الفريق' : 'Staff notes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notes.isNotEmpty)
                for (final line in notes.split('\n'))
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                    child: Text(line, style: const TextStyle(fontSize: 13, height: 1.6)),
                  )
              else
                const Text('—', style: TextStyle(fontSize: 13, color: Ops.muted)),
              if (canWrite || staffCan(_role, 'notes.write')) _NoteComposer(onSave: _appendNote, lang: lang),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Registration / onboarding progress --------------------------------
  Widget _registrationSteps(Map prov, String lang) {
    final ar = lang == 'ar';
    bool has(dynamic v) => v is List ? v.isNotEmpty : '${v ?? ''}'.trim().isNotEmpty;
    final idOk = '${prov['idDocStatus'] ?? ''}'.toLowerCase() == 'accepted' || has(prov['idPhotoUrl']);
    final fishOk = ['accepted', 'validated'].contains('${prov['fishDocStatus'] ?? ''}'.toLowerCase()) ||
        has(prov['fishPhotoUrl']) ||
        !isZeroTime(prov['fishValidatedAt']) ||
        !isZeroTime(prov['fishGraceUntil']);
    final profileOk = has(prov['bio']) && asInt(prov['years']) > 0;
    final payoutOk = has(prov['payoutMethod']) && has(prov['payoutHandle']);
    final vetted = !isZeroTime(prov['vettedAt']);
    final rejected = !isZeroTime(prov['rejectedAt']);

    final steps = <(String label, bool done, String note)>[
      (ar ? 'الموافقة والتسجيل' : 'Consent & sign-up', !isZeroTime(prov['consentedAt']), formatDayOnly(prov['consentedAt'])),
      (ar ? 'الملف الشخصي' : 'Profile details', profileOk, profileOk ? '' : (ar ? 'نبذة/خبرة ناقصة' : 'bio / experience missing')),
      (ar ? 'الرقم القومي' : 'National ID', idOk, '${prov['idDocStatus'] ?? (idOk ? 'uploaded' : 'missing')}'),
      (ar ? 'الفيش الجنائي' : 'Criminal record (FISH)', fishOk,
          !isZeroTime(prov['fishGraceUntil']) && !fishOkStrict(prov)
              ? '${ar ? 'مهلة حتى' : 'grace to'} ${formatDayOnly(prov['fishGraceUntil'])}'
              : '${prov['fishDocStatus'] ?? (fishOk ? 'uploaded' : 'missing')}'),
      (ar ? 'الخدمات' : 'Services added', has(prov['items']), '${asDynList(prov['items']).length}'),
      (ar ? 'مناطق التغطية' : 'Coverage areas', has(prov['areas']), '${asDynList(prov['areas']).length}'),
      (ar ? 'أوقات العمل' : 'Availability set', has(prov['workDays']), '${asDynList(prov['workDays']).length} ${ar ? 'يوم' : 'days'}'),
      (ar ? 'المعرض' : 'Portfolio', has(prov['portfolio']), '${asDynList(prov['portfolio']).length}'),
      (ar ? 'حساب الدفع' : 'Payout account', payoutOk, payoutOk ? '${prov['payoutMethod']}' : ''),
      (
        ar ? 'التحقق' : 'Vetting',
        vetted,
        rejected ? (ar ? 'مرفوضة' : 'rejected') : (vetted ? formatDayOnly(prov['vettedAt']) : (ar ? 'بانتظار' : 'pending'))
      ),
    ];
    final doneCount = steps.where((s) => s.$2).length;

    return V2SectionCard(
      title: ar ? 'خطوات التسجيل' : 'Registration steps',
      subtitle: '$doneCount / ${steps.length} ${ar ? 'مكتملة' : 'complete'}',
      child: Column(
        children: [
          for (var i = 0; i < steps.length; i++)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 9),
              decoration: BoxDecoration(
                border: Border(top: i == 0 ? BorderSide.none : const BorderSide(color: Ops.rowBorder)),
              ),
              child: Row(
                children: [
                  Icon(
                    steps[i].$2 ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 17,
                    color: steps[i].$2 ? Ops.green : Ops.borderStrong,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(steps[i].$1,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: steps[i].$2 ? Ops.ink : Ops.inkSoft)),
                  ),
                  if (steps[i].$3.trim().isNotEmpty)
                    Text(steps[i].$3,
                        style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft, fontFamily: Ops.mono)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool fishOkStrict(Map prov) =>
      ['accepted', 'validated'].contains('${prov['fishDocStatus'] ?? ''}'.toLowerCase()) ||
      !isZeroTime(prov['fishValidatedAt']);

  // ---- Documents ----------------------------------------------------------
  Widget _documents(Map prov, String lang, bool canVet) {
    final docs = <(String key, String label, String? url, String status)>[
      ('id', lang == 'ar' ? 'الرقم القومي' : 'National ID', _nonEmpty(prov['idPhotoUrl'] ?? prov['idPath']),
          '${prov['idDocStatus'] ?? (providerVetting(prov, 'en') == 'Vetted' ? 'accepted' : 'pending')}'),
      ('fish', lang == 'ar' ? 'الفيش الجنائي' : 'FISH (criminal record)', _nonEmpty(prov['fishPhotoUrl'] ?? prov['fishPath']),
          '${prov['fishDocStatus'] ?? (providerVetting(prov, 'en') == 'Vetted' ? 'accepted' : 'pending')}'),
      ('cert', lang == 'ar' ? 'شهادة المزاولة' : 'Trade certificate', _nonEmpty(prov['tradeCertUrl']),
          '${prov['tradeCertStatus'] ?? 'not tracked'}'),
    ];
    return V2SectionCard(
      title: lang == 'ar' ? 'المستندات' : 'Documents',
      trailing: [
        if (canVet)
          V2Btn.ghost(lang == 'ar' ? 'طلب رفع' : 'Request upload',
              onPressed: () => _appendNote(lang == 'ar' ? 'طُلب رفع مستند' : 'Document re-upload requested'),
              size: V2BtnSize.sm),
      ],
      child: LayoutBuilder(builder: (context, box) {
        final cols = box.maxWidth > 620 ? 3 : (box.maxWidth > 360 ? 2 : 1);
        return Wrap(
          spacing: 13,
          runSpacing: 13,
          children: [
            for (final d in docs)
              SizedBox(
                width: (box.maxWidth - (cols - 1) * 13) / cols,
                child: _DocCard(
                  label: d.$2,
                  status: d.$4,
                  url: d.$3,
                  canAct: canVet && d.$1 != 'cert',
                  onAccept: () => _post('/admin/providers/${widget.providerId}/docs/${d.$1}',
                      data: {'status': 'accepted'}, okMsg: '${d.$2} ${lang == 'ar' ? 'مقبول' : 'accepted'}'),
                  onReject: () => _rejectDoc(d.$1, d.$2, lang),
                ),
              ),
          ],
        );
      }),
    );
  }

  Future<void> _rejectDoc(String kind, String label, String lang) async {
    var note = '';
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'رفض المستند' : 'Reject document',
      confirmLabel: lang == 'ar' ? 'رفض' : 'Reject',
      danger: true,
      bodyBuilder: (ctx, _) => V2FormField(
        label: lang == 'ar' ? 'السبب (اختياري)' : 'Reason (optional)',
        child: TextField(onChanged: (v) => note = v, maxLines: 2),
      ),
    );
    if (ok) {
      _post('/admin/providers/${widget.providerId}/docs/$kind',
          data: {'status': 'rejected', if (note.trim().isNotEmpty) 'note': note.trim()},
          okMsg: '$label ${lang == 'ar' ? 'مرفوض' : 'rejected'}');
    }
  }

  // ---- Team (workers) ----------------------------------------------------

  Widget _team(String lang, bool canVet) {
    return V2SectionCard(
      title: lang == 'ar' ? 'الفريق' : 'Team',
      child: workers.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                lang == 'ar' ? 'لا يوجد أعضاء فريق مسجّلين' : 'No team members on record',
                style: const TextStyle(fontSize: 13, color: Ops.muted),
              ),
            )
          : Column(
              children: [
                for (final w in workers) ...[
                  _workerCard(w, lang, canVet),
                  const SizedBox(height: 16),
                ],
              ],
            ),
    );
  }

  Widget _workerCard(Map w, String lang, bool canVet) {
    final name = '${w['firstName'] ?? ''} ${w['lastName'] ?? ''}'.trim();
    final vetted = w['vetted'] == true;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE6DED6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(name.isEmpty ? '—' : name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700))),
              V2StatusPill.forLabel(vetted ? 'Vetted' : 'Pending review'),
            ],
          ),
          if ('${w['phone'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('${w['phone']}', style: const TextStyle(fontSize: 12, color: Ops.muted, fontFamily: Ops.mono)),
            ),
          if ('${w['address'] ?? ''}'.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text('${w['address']}', style: const TextStyle(fontSize: 12, color: Ops.muted)),
            ),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final cols = box.maxWidth > 480 ? 2 : 1;
            final docs = <(String key, String label, String? url, String status)>[
              ('id', lang == 'ar' ? 'الرقم القومي' : 'National ID', _nonEmpty(w['idPhotoUrl']), '${w['idDocStatus'] ?? 'unknown'}'),
              ('fish', lang == 'ar' ? 'الفيش الجنائي' : 'FISH (criminal record)', _nonEmpty(w['fishPhotoUrl']), '${w['fishDocStatus'] ?? 'unknown'}'),
            ];
            return Wrap(
              spacing: 13,
              runSpacing: 13,
              children: [
                for (final d in docs)
                  SizedBox(
                    width: (box.maxWidth - (cols - 1) * 13) / cols,
                    child: _DocCard(
                      label: d.$2,
                      status: d.$4,
                      url: d.$3,
                      canAct: canVet,
                      onAccept: () => _postWorkerDoc('${w['id']}', d.$1, 'accepted', d.$2, lang),
                      onReject: () => _rejectWorkerDoc('${w['id']}', d.$1, d.$2, lang),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _postWorkerDoc(String workerId, String kind, String status, String label, String lang, {String? note}) async {
    await _post(
      '/admin/workers/${widget.providerId}/$workerId/docs/$kind',
      data: {'status': status, if (note != null && note.isNotEmpty) 'note': note},
      okMsg: '$label ${status == 'accepted' ? (lang == 'ar' ? 'مقبول' : 'accepted') : (lang == 'ar' ? 'مرفوض' : 'rejected')}',
    );
  }

  Future<void> _rejectWorkerDoc(String workerId, String kind, String label, String lang) async {
    var note = '';
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'رفض المستند' : 'Reject document',
      confirmLabel: lang == 'ar' ? 'رفض' : 'Reject',
      danger: true,
      bodyBuilder: (ctx, _) => V2FormField(
        label: lang == 'ar' ? 'السبب' : 'Reason',
        child: TextField(onChanged: (v) => note = v, maxLines: 2),
      ),
    );
    if (ok) {
      await _postWorkerDoc(workerId, kind, 'rejected', label, lang, note: note.trim());
    }
  }

  // ---- Services ---------------------------------------------------------
  Widget _services(Map prov, String lang, bool canWrite) {
    final items = asDynList(prov['items'] ?? prov['services']).map((e) => asMap(e) ?? {}).toList();
    return V2SectionCard(
      title: lang == 'ar' ? 'الخدمات والأسعار' : 'Services & pricing',
      trailing: [
        if (canWrite)
          V2Btn.primary(lang == 'ar' ? '+ إضافة خدمة' : '+ Add service',
              onPressed: () => _editServices(items, lang, add: true), size: V2BtnSize.sm),
      ],
      child: Column(
        children: [
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(lang == 'ar' ? 'لا خدمات على هذا الملف بعد' : 'No services on this profile yet',
                  style: const TextStyle(fontSize: 13, color: Ops.muted)),
            )
          else
            for (final s in items)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(locName(s['name'], lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('${s['category'] ?? prov['category'] ?? ''}',
                              style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft)),
                        ],
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(money(asInt(s['price']), lang),
                          style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text('${asInt(s['durationMin'])} ${lang == 'ar' ? 'د' : 'min'}',
                          style: const TextStyle(fontSize: 13, color: Ops.inkSoft)),
                    ),
                    if (canWrite) ...[
                      V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit',
                          onPressed: () => _editServices(items, lang, focus: s), size: V2BtnSize.row),
                      const SizedBox(width: 6),
                      V2Btn.danger(lang == 'ar' ? 'إزالة' : 'Remove',
                          onPressed: () => _confirmThen(
                                lang == 'ar' ? 'إزالة الخدمة؟' : 'Remove service?',
                                '${locName(s['name'], lang)} ${lang == 'ar' ? 'ستُزال من الملف.' : 'is removed from the profile.'}',
                                lang == 'ar' ? 'إزالة' : 'Remove',
                                () {
                                  final next = items.where((x) => x != s).toList();
                                  _patch('/admin/providers/${widget.providerId}', {'items': next},
                                      lang == 'ar' ? 'أُزيلت الخدمة' : 'Service removed');
                                },
                                danger: true,
                              ),
                          size: V2BtnSize.row),
                    ],
                  ],
                ),
              ),
        ],
      ),
    );
  }

  Future<void> _editServices(List<Map<String, dynamic>> items, String lang, {Map? focus, bool add = false}) async {
    final list = items.map((e) => Map<String, dynamic>.from(e)).toList();
    if (add) list.add({'name': {'en': '', 'ar': ''}, 'durationMin': 60, 'price': 0, 'category': (p ?? {})['category']});

    // One controller set per row, owned by this method so text survives the
    // list's add/remove rebuilds and is disposed when the modal closes.
    final rowCtls = <Map<String, TextEditingController>>[];
    Map<String, TextEditingController> ctlsFor(Map<String, dynamic> row) => {
          'en': TextEditingController(text: '${(row['name'] as Map?)?['en'] ?? ''}'),
          'ar': TextEditingController(text: '${(row['name'] as Map?)?['ar'] ?? ''}'),
          'dur': TextEditingController(text: '${asInt(row['durationMin'])}'),
          'price': TextEditingController(text: '${asInt(row['price']) / 100}'),
        };
    for (final row in list) {
      rowCtls.add(ctlsFor(row));
    }

    try {
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'تحرير الخدمات' : 'Edit services',
        bodyBuilder: (ctx, setLocal) => StatefulBuilder(
          builder: (context, sb) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < list.length; i++)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(border: Border.all(color: Ops.border), borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    children: [
                      Row(children: [
                        Expanded(child: Text('${lang == 'ar' ? 'خدمة' : 'Service'} ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w600))),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18, color: Ops.terracottaInk),
                          onPressed: () => sb(() {
                            list.removeAt(i);
                            for (final c in rowCtls.removeAt(i).values) {
                              c.dispose();
                            }
                          }),
                        ),
                      ]),
                      TextField(
                        controller: rowCtls[i]['en'],
                        decoration: InputDecoration(labelText: lang == 'ar' ? 'الاسم (EN)' : 'Name (EN)'),
                        onChanged: (v) => (list[i]['name'] ??= <String, dynamic>{})['en'] = v,
                      ),
                      TextField(
                        controller: rowCtls[i]['ar'],
                        decoration: InputDecoration(labelText: lang == 'ar' ? 'الاسم (ع)' : 'Name (AR)'),
                        onChanged: (v) => (list[i]['name'] ??= <String, dynamic>{})['ar'] = v,
                      ),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: rowCtls[i]['dur'],
                            decoration: InputDecoration(labelText: lang == 'ar' ? 'المدة (د)' : 'Duration (min)'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => list[i]['durationMin'] = int.tryParse(v) ?? 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: rowCtls[i]['price'],
                            decoration: InputDecoration(labelText: lang == 'ar' ? 'السعر (ج.م)' : 'Price (EGP)'),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => list[i]['price'] = ((double.tryParse(v) ?? 0) * 100).round(),
                          ),
                        ),
                      ]),
                    ],
                  ),
                ),
              V2Btn.ghost(lang == 'ar' ? '+ خدمة' : '+ Service',
                  onPressed: () => sb(() {
                        final row = <String, dynamic>{'name': {'en': '', 'ar': ''}, 'durationMin': 60, 'price': 0};
                        list.add(row);
                        rowCtls.add(ctlsFor(row));
                      })),
            ],
          ),
        ),
      );
      if (ok) _patch('/admin/providers/${widget.providerId}', {'items': list}, lang == 'ar' ? 'تم تحديث الخدمات' : 'Services updated');
    } finally {
      for (final m in rowCtls) {
        for (final c in m.values) {
          c.dispose();
        }
      }
    }
  }

  // ---- Coverage --------------------------------------------------------
  Widget _coverage(Map prov, String lang, bool canVet) {
    final selected = asDynList(prov['areas']).map((e) => '$e').toSet();
    // workDays is a list of weekday indices (0 = Sun). slotHours are "HH:mm" strings.
    final workDays = asDynList(prov['workDays']).map((e) => asInt(e)).toSet();
    final slots = asDynList(prov['slotHours']).map((e) => '$e').toList()..sort();
    final hoursLabel = slots.length >= 2 ? '${slots.first} — ${slots.last}' : (slots.isNotEmpty ? slots.join(', ') : '09:00 — 21:00');
    const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return _twoCol(
      lang,
      left: [
        V2SectionCard(
          title: lang == 'ar' ? 'مناطق التغطية' : 'Coverage areas',
          subtitle: lang == 'ar' ? 'اضغطي منطقة لتفعيلها على هذا الملف' : 'Tap an area to toggle it on this profile',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (areas.isEmpty)
                Text(lang == 'ar' ? 'حمّلي المناطق…' : 'Loading areas…', style: const TextStyle(fontSize: 12, color: Ops.muted)),
              for (final a in areas)
                Builder(builder: (_) {
                  final slug = '${a['slug'] ?? a['id'] ?? ''}';
                  final on = selected.contains(slug);
                  return V2Pill(
                    label: locName(a['name'], lang),
                    on: on,
                    onTap: canVet
                        ? () {
                            final next = {...selected};
                            on ? next.remove(slug) : next.add(slug);
                            _patch('/admin/providers/${widget.providerId}', {'areas': next.toList()},
                                lang == 'ar' ? 'تم تحديث التغطية' : 'Coverage updated');
                          }
                        : () {},
                  );
                }),
            ],
          ),
        ),
      ],
      right: [
        V2SectionCard(
          title: lang == 'ar' ? 'الجدول الأسبوعي' : 'Weekly schedule',
          child: Column(
            children: [
              for (var i = 0; i < days.length; i++)
                Builder(builder: (_) {
                  final on = workDays.isEmpty ? i != 5 : workDays.contains(i);
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                    child: Row(
                      children: [
                        SizedBox(width: 48, child: Text(days[i], style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(on ? hoursLabel : (lang == 'ar' ? 'غير متاح' : 'Unavailable'),
                              style: const TextStyle(fontSize: 12.5, color: Ops.inkSoft, fontFamily: Ops.mono)),
                        ),
                        V2StatusPill.forLabel(on ? 'Active' : 'Inactive'),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ],
    );
  }

  // ---- Portfolio -----------------------------------------------------
  Widget _portfolio(Map prov, String lang, bool canVet) {
    final port = asDynList(prov['portfolio']).map((e) => '$e').toList();
    return V2SectionCard(
      title: lang == 'ar' ? 'المعرض' : 'Portfolio',
      subtitle: lang == 'ar' ? 'يظهر في ملف المهنية العام' : "Shown on the provider's public profile",
      trailing: [
        if (canVet)
          V2Btn.ghost(lang == 'ar' ? 'طلب صور' : 'Request photos',
              onPressed: () => _appendNote(lang == 'ar' ? 'طُلبت صور للمعرض' : 'Portfolio photos requested'),
              size: V2BtnSize.sm),
      ],
      child: port.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(lang == 'ar' ? 'لا صور بعد' : 'No portfolio photos yet',
                  style: const TextStyle(fontSize: 13, color: Ops.muted)),
            )
          : LayoutBuilder(builder: (context, box) {
              final cols = (box.maxWidth / 160).floor().clamp(2, 5);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  for (var i = 0; i < port.length; i++)
                    SizedBox(
                      width: (box.maxWidth - (cols - 1) * 12) / cols,
                      child: Column(
                        children: [
                          AspectRatio(
                            aspectRatio: 1,
                            child: _RemoteImage(path: port[i]),
                          ),
                          const SizedBox(height: 7),
                          if (canVet)
                            V2Btn.danger(lang == 'ar' ? 'إزالة' : 'Remove',
                                onPressed: () {
                                  final next = [...port]..removeAt(i);
                                  _patch('/admin/providers/${widget.providerId}', {'portfolio': next},
                                      lang == 'ar' ? 'أُزيلت الصورة' : 'Photo removed');
                                },
                                size: V2BtnSize.row),
                        ],
                      ),
                    ),
                ],
              );
            }),
    );
  }

  // ---- Money -------------------------------------------------------
  Widget _money(Map prov, String lang, bool canVet) {
    final method = '${prov['payoutMethod'] ?? ''}';
    final handle = '${prov['payoutHandle'] ?? prov['payoutAccount'] ?? ''}';
    // ledger + jobs are fetched separately in _load().
    return _twoCol(
      lang,
      left: [
        V2SectionCard(
          title: lang == 'ar' ? 'حساب الدفع' : 'Payout account',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _kv(lang == 'ar' ? 'الطريقة' : 'Method', method.isEmpty ? '—' : method, mono: true),
              _kv(lang == 'ar' ? 'الحساب' : 'Account', handle.isEmpty ? '—' : handle, mono: true),
              _kv(lang == 'ar' ? 'المتاح' : 'Available', money(asInt(ledger['available'] ?? ledger['pending']), lang), mono: true),
              _kv(lang == 'ar' ? 'المحجوز' : 'Held', money(asInt(ledger['held']), lang), mono: true),
              const SizedBox(height: 8),
              if (canVet)
                Row(children: [
                  V2Btn.ghost(lang == 'ar' ? 'تعديل الحساب' : 'Edit account',
                      onPressed: () => _editPayout(method, handle, lang), size: V2BtnSize.sm),
                ]),
            ],
          ),
        ),
      ],
      right: [
        V2SectionCard(
          title: lang == 'ar' ? 'سجل الوظائف' : 'Job history',
          child: jobs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(lang == 'ar' ? 'لا وظائف بعد' : 'No jobs yet',
                      style: const TextStyle(fontSize: 13, color: Ops.muted)),
                )
              : Column(
                  children: [
                    for (final j in jobs)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Ops.rowBorder))),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(serviceLabel(j, lang), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(
                                      '${formatDayOnly(j['slotStart'])} · ${clientNameOf(j, lang)} · ${bookingRef(j)}',
                                      style: const TextStyle(fontSize: 11.5, color: Ops.mutedSoft)),
                                ],
                              ),
                            ),
                            V2StatusPill(label: statusLabel('${j['status']}', lang), tone: statusTone('${j['status']}')),
                            const SizedBox(width: 10),
                            Text(money(asInt(j['total']), lang),
                                style: const TextStyle(fontSize: 13, fontFamily: Ops.mono, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _editPayout(String method, String handle, String lang) async {
    var m = method;
    final h = TextEditingController(text: handle);
    try {
      final ok = await v2Form(
        context,
        title: lang == 'ar' ? 'تعديل حساب الدفع' : 'Edit payout account',
        bodyBuilder: (ctx, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(
              label: lang == 'ar' ? 'الطريقة' : 'Method',
              child: DropdownButtonFormField<String>(
                initialValue: m.isEmpty ? null : m,
                items: const [
                  DropdownMenuItem(value: 'instapay', child: Text('InstaPay')),
                  DropdownMenuItem(value: 'wallet', child: Text('Mobile wallet')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank transfer')),
                ],
                onChanged: (v) => m = v ?? '',
              ),
            ),
            const SizedBox(height: 12),
            V2FormField(label: lang == 'ar' ? 'رقم الحساب/الهاتف' : 'Account / phone', child: TextField(controller: h)),
          ],
        ),
      );
      if (ok) {
        _patch('/admin/providers/${widget.providerId}', {'payoutMethod': m, 'payoutHandle': h.text.trim()},
            lang == 'ar' ? 'تم تحديث حساب الدفع' : 'Payout account updated');
      }
    } finally {
      h.dispose();
    }
  }

  // ---- shared bits ----------------------------------------------------
  Widget _twoCol(String lang, {required List<Widget> left, required List<Widget> right, int leftFlex = 1, int rightFlex = 1}) {
    Widget stack(List<Widget> ws) => Column(
        children: [for (final w in ws) Padding(padding: const EdgeInsets.only(bottom: Ops.gap), child: w)]);
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth < 900) return stack([...left, ...right]);
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: leftFlex, child: stack(left)),
          const SizedBox(width: Ops.gap),
          Expanded(flex: rightFlex, child: stack(right)),
        ],
      );
    });
  }

  Widget _kv(String k, String v, {bool mono = false}) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Ops.rowBorder))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(k, style: const TextStyle(fontSize: 12.5, color: Ops.muted))),
          const SizedBox(width: 12),
          Flexible(
            child: Text(v.isEmpty ? '—' : v,
                textAlign: TextAlign.end,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, fontFamily: mono ? Ops.mono : Ops.sans)),
          ),
        ],
      ),
    );
  }

  Widget _statGrid(List<(String, String)> stats) {
    return Container(
      decoration: BoxDecoration(color: Ops.borderSoft, borderRadius: BorderRadius.circular(11)),
      clipBehavior: Clip.antiAlias,
      child: Wrap(
        spacing: 1,
        runSpacing: 1,
        children: [
          for (final s in stats)
            SizedBox(
              width: 104,
              child: Container(
                color: Ops.cardAlt,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.$1, style: const TextStyle(fontSize: 11, color: Ops.muted)),
                    const SizedBox(height: 3),
                    Text(s.$2, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, fontFamily: Ops.mono)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _nonEmpty(dynamic v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }
}

class _NoteComposer extends StatefulWidget {
  const _NoteComposer({required this.onSave, required this.lang});
  final Future<void> Function(String) onSave;
  final String lang;

  @override
  State<_NoteComposer> createState() => _NoteComposerState();
}

class _NoteComposerState extends State<_NoteComposer> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.lang == 'ar';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        TextField(
          controller: _c,
          maxLines: 3,
          decoration: InputDecoration(hintText: ar ? 'ملاحظة تحقّق، ملخص مكالمة، تحذير…' : 'Vetting note, phone screen summary, warning…'),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: V2Btn.primary(ar ? 'حفظ الملاحظة' : 'Save note', onPressed: () {
            final t = _c.text.trim();
            if (t.isEmpty) return;
            widget.onSave(t);
            _c.clear();
          }),
        ),
      ],
    );
  }
}

class _DocCard extends StatelessWidget {
  const _DocCard({
    required this.label,
    required this.status,
    required this.url,
    required this.canAct,
    required this.onAccept,
    required this.onReject,
  });
  final String label;
  final String status;
  final String? url;
  final bool canAct;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final accepted = s == 'accepted' || s == 'validated';
    final chipLabel = accepted
        ? 'Accepted'
        : s == 'rejected'
            ? 'Rejected'
            : s.contains('track')
                ? 'Not tracked'
                : (url == null && (s.isEmpty || s == 'unknown' || s == 'missing'))
                    ? 'Missing'
                    : 'Pending review';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600))),
            V2StatusPill.forLabel(chipLabel),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 120,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            color: accepted ? const Color(0xFFF1F6EF) : Ops.impBg,
            border: Border.all(
              color: accepted ? const Color(0xFFCFDCCB) : const Color(0xFFD9BFB4),
              style: accepted ? BorderStyle.solid : BorderStyle.solid,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: url == null
              ? Text('— ${label.toLowerCase()} —', style: const TextStyle(fontSize: 11, color: Ops.mutedSoft, fontFamily: Ops.mono))
              : _RemoteImage(path: url!),
        ),
        const SizedBox(height: 8),
        if (canAct)
          Row(
            children: [
              V2Btn.ghost('Accept', onPressed: onAccept, size: V2BtnSize.row),
              const SizedBox(width: 6),
              V2Btn.danger('Reject', onPressed: onReject, size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}

class _RemoteImage extends StatelessWidget {
  const _RemoteImage({required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final bytes = await staffClient.uploadBytes(path);
        if (bytes == null || !context.mounted) return;
        showDialog<void>(
          context: context,
          builder: (_) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 820),
              child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
            ),
          ),
        );
      },
      child: FutureBuilder<Uint8List?>(
        future: staffClient.uploadBytes(path),
        builder: (context, snap) {
          if (snap.hasData && snap.data != null) {
            return SizedBox.expand(child: Image.memory(snap.data!, fit: BoxFit.cover));
          }
          return const Center(child: Icon(Icons.image_outlined, size: 34, color: Ops.mutedSoft));
        },
      ),
    );
  }
}
