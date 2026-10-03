import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/core/icons/ons_icons.dart';
import 'package:oons/core/pro_format.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/models.dart';
import 'package:oons/features/subscribe/ar_eg.dart';
import 'package:oons/features/subscribe/draft_saver.dart';
import 'package:oons/features/subscribe/prov_api.dart';
import 'package:oons/features/subscribe/visit_ops.dart';
import 'package:oons/features/subscribe/wiz_widgets.dart';
import 'package:oons/features/subscribe/wizard_logic.dart';

export 'package:oons/features/subscribe/wizard_logic.dart' show PlanService, TeamMember;

/// Opens باقاتي for the signed-in provider, using her live cleaning services.
void openProviderPlans(BuildContext context, ProviderP me) {
  final services = me.items.where((it) => it.active && (it.approvalState.isEmpty || it.approvalState == 'approved')).map((it) {
    final name = it.name.of('ar');
    return PlanService(
      id: it.id,
      catalogItemId: it.catalogItemId ?? '',
      name: name,
      regularEgp: it.price ~/ 100,
      visitType: visitTypeForName(name, id: it.id),
    );
  }).toList();
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => PlanWizard(services: services, providerId: me.id)));
}

/// Date picker seam: tests inject a fake, the app uses [pickWizDate].
typedef WizDatePicker = Future<DateTime?> Function(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? help,
});

Future<DateTime?> pickWizDate(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? help,
}) {
  return showDatePicker(
    context: context,
    initialDate: initial.isBefore(first) ? first : initial,
    firstDate: first,
    lastDate: last,
    helpText: help,
    cancelText: 'إلغاء',
    confirmText: 'تمام',
    builder: (ctx, child) => Localizations.override(
      context: ctx,
      locale: const Locale('ar'),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: Wiz.plum, onPrimary: Colors.white, surface: Wiz.surface, onSurface: Wiz.ink),
            datePickerTheme: const DatePickerThemeData(shape: RoundedRectangleBorder(), backgroundColor: Wiz.surface),
          ),
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    ),
  );
}

// ===========================================================================
// My plans (باقاتي)
// ===========================================================================

class PlanWizard extends StatefulWidget {
  const PlanWizard({
    super.key,
    required this.services,
    this.providerId = '',
    this.api = const LiveProApi(),
    this.now,
    this.pickDate = pickWizDate,
    this.onViewProfile,
  });
  final List<PlanService> services;

  /// The signed-in provider's id, used by «شوفيها في بروفايلي».
  final String providerId;
  final ProApi api;
  final DateTime Function()? now;
  final WizDatePicker pickDate;

  /// Overrides the default `/provider/:id` navigation (tests).
  final VoidCallback? onViewProfile;

  @override
  State<PlanWizard> createState() => _PlanWizardState();
}

class _PlanWizardState extends State<PlanWizard> {
  List<Map<String, dynamic>> rows = [];
  Map<String, String> workerNames = {};
  bool loading = true;
  bool enabled = true;
  String? error;
  bool showArchived = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted && !loading && rows.isEmpty) setState(() => loading = true);
    try {
      final r = await widget.api.get('/pro/plans');
      final names = <String, String>{};
      try {
        final w = await widget.api.get('/pro/workers');
        for (final m in mapList(w['workers'])) {
          final n = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
          if (n.isNotEmpty) names['${m['id']}'] = n;
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        rows = mapList(r['plans']);
        enabled = r['enabled'] != false;
        workerNames = names;
        loading = false;
        error = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = arError(e, fallback: 'ما قدرناش نجيب باقاتك. جرّبي تاني.');
        });
      }
    }
  }

  Map<String, dynamic> _plan(Map<String, dynamic> row) => row['plan'] is Map ? Map<String, dynamic>.from(row['plan'] as Map) : row;
  String _status(Map<String, dynamic> row) => '${_plan(row)['status'] ?? 'draft'}';
  bool _isArchived(Map<String, dynamic> row) => _status(row) == 'archived';

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg, style: ws(14, c: Colors.white))));
  }

  Future<void> _openFlow({Map<String, dynamic>? existing}) async {
    // The server keeps ONE draft per provider and a new autosave without an id
    // would overwrite it, so «+ اعملي باقة جديدة» resumes the draft if there is one.
    if (existing == null) {
      for (final r in rows) {
        if (_status(r) == 'draft') existing = _plan(r);
      }
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => PlanWizardFlow(
        services: widget.services,
        existing: existing,
        providerId: widget.providerId,
        api: widget.api,
        now: widget.now,
        pickDate: widget.pickDate,
        onViewProfile: widget.onViewProfile,
      ),
    ));
    if (mounted) _load();
  }

  Future<void> _pause(String id) async {
    final ok = await showWizConfirm(
      context,
      title: 'توقّفي الباقة؟',
      body: 'الباقة مش هتظهر للعميلات الجداد لحد ما ترجّعيها. المشتركات الحاليين مش بيتأثروا.',
      confirm: 'وقّفي',
    );
    if (ok == true) await _act(id, 'pause');
  }

  Future<void> _resume(String id) async {
    final ok = await showWizConfirm(
      context,
      title: 'ترجّعي الباقة؟',
      body: 'الباقة هتظهر للعميلات تاني.',
      confirm: 'ارجعيها',
    );
    if (ok == true) await _act(id, 'resume');
  }

  Future<bool> _act(String id, String action, {String? done}) async {
    try {
      await widget.api.post('/pro/plans/$id/$action');
      if (done != null) _snack(done);
      await _load();
      return true;
    } catch (e) {
      _snack(arError(e));
      return false;
    }
  }

  Future<void> _archive(Map<String, dynamic> plan) async {
    final id = '${plan['id']}';
    final draft = '${plan['status']}' == 'draft';
    final ok = await showWizConfirm(
      context,
      title: draft ? 'تمسحي المسودة؟' : 'تأرشفي الباقة؟',
      body: draft ? 'المسودة هتتشال من قايمتك.' : 'الباقة هتختفي من قايمتك ومش هتظهر للعميلات.',
      confirm: draft ? 'امسحي' : 'أرشفي',
      danger: true,
    );
    if (ok != true || !mounted) return;
    try {
      await widget.api.delete('/pro/plans/$id');
      _snack(draft ? 'اتمسحت المسودة.' : 'اتأرشفت الباقة.');
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        final canPause = '${plan['status']}' == 'published' || '${plan['status']}' == 'active';
        final pause = await showDialog<bool>(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Wiz.surface,
              shape: const RoundedRectangleBorder(),
              title: Text('مش هينفع تأرشفيها دلوقتي', style: ws(17, w: FontWeight.w700)),
              content: Text(arError(e, fallback: 'الباقة لسه فيها مشتركات. وقّفيها بدل ما تعمليها أرشيف.'), style: ws(14, c: Wiz.body, h: 1.6)),
              actions: [
                WizTextAction(label: 'تمام', color: Wiz.soft, onTap: () => Navigator.pop(ctx, false)),
                if (canPause) WizTextAction(label: 'وقّفي الباقة بدلاً من كده', onTap: () => Navigator.pop(ctx, true)),
              ],
            ),
          ),
        );
        if (pause == true) await _act(id, 'pause');
      } else {
        _snack(arError(e));
      }
    } catch (e) {
      _snack(arError(e));
    }
  }

  String _mix(Map<String, dynamic> plan) {
    final parts = <String>[];
    for (final raw in mapList(plan['lines'])) {
      final q = intOf(raw['quantity']);
      if (q < 1) continue;
      final nm = raw['name'];
      var name = nm is Map ? '${nm['ar'] ?? nm['en'] ?? ''}' : '${nm ?? ''}';
      if (name.isEmpty) {
        final own = '${raw['catalogItemId'] ?? ''}';
        for (final s in widget.services) {
          if (s.id == own || s.catalogItemId == own) name = s.name;
        }
      }
      parts.add('${arNum(q)} $name'.trim());
    }
    return parts.isEmpty ? 'لسه من غير خدمات' : '${parts.join(' + ')} في الشهر';
  }

  String _who(Map<String, dynamic> plan) {
    final mode = '${plan['assigneeMode'] ?? 'any'}';
    if (mode == 'self') return 'إنتي · صاحبة الحساب';
    if (mode == 'member') return workerNames['${plan['assigneeId'] ?? ''}'] ?? 'عضوة محددة';
    return 'أي عضوة متاحة من الفريق';
  }

  @override
  Widget build(BuildContext context) {
    final visible = rows.where((r) => !_isArchived(r)).toList();
    final archived = rows.where(_isArchived).toList();
    final shown = showArchived ? [...visible, ...archived] : visible;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Wiz.cream,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 20, 0),
                child: Row(children: [
                  Tap44(
                    key: const Key('plans-back'),
                    semanticLabel: 'رجوع',
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const OnsIcon('back', size: 20, color: Wiz.ink),
                  ),
                ]),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(20, 2, 20, 12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('باقاتي', style: ws(26, w: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${plansPhrase(visible.length)} · كل باقة مستقلة بسعرها ومواعيدها', style: ws(12, c: Wiz.muted)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: _SectionTabs(
                  onSubscribers: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ProSubscribersScreen(api: widget.api))),
                ),
              ),
              Expanded(child: _content(shown, visible, archived)),
              if (!loading && error == null && enabled && visible.isNotEmpty)
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: const BoxDecoration(border: Border(top: BorderSide(color: Wiz.divider))),
                  child: WizPrimaryButton(key: const Key('new-plan'), label: '+ اعملي باقة جديدة', onTap: () => _openFlow()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(List<Map<String, dynamic>> shown, List<Map<String, dynamic>> visible, List<Map<String, dynamic>> archived) {
    if (loading) return const Center(child: CircularProgressIndicator(color: Wiz.plum));
    if (error != null) return WizErrorState(message: error!, onRetry: _load);
    if (!enabled) {
      return const WizEmptyState(
        icon: Icon(Icons.lock_outline, size: 22, color: Wiz.muted),
        title: 'الباقات مش متاحة على حسابك دلوقتي',
        body: 'الباقات الشهرية لسه تجريبية. هنبلّغك أول ما تتفعّل لحسابك.',
      );
    }
    if (visible.isEmpty && archived.isEmpty) {
      return WizEmptyState(
        icon: const OnsIcon('plus', size: 22, color: Wiz.muted),
        title: 'لسه معندكيش باقات',
        body: 'اعملي باقة شهرية بسعر ومواعيد ثابتة، والعميلات هتشوفها في بروفايلك.',
        cta: '+ اعملي باقة جديدة',
        onCta: () => _openFlow(),
      );
    }
    return RefreshIndicator(
      color: Wiz.plum,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
        children: [
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: WizEmptyState(
                icon: const OnsIcon('plus', size: 22, color: Wiz.muted),
                title: 'مفيش باقات شغّالة',
                body: 'كل باقاتك مؤرشفة. اعملي باقة جديدة عشان العميلات تشوفها.',
                cta: '+ اعملي باقة جديدة',
                onCta: () => _openFlow(),
              ),
            ),
          for (final row in shown) Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(row)),
          if (archived.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: WizTextAction(
                key: const Key('toggle-archived'),
                label: showArchived ? 'اخفي المؤرشفة' : 'مؤرشفة (${arNum(archived.length)})',
                color: Wiz.soft,
                onTap: () => setState(() => showArchived = !showArchived),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> row) {
    final plan = _plan(row);
    final quote = row['quote'] is Map ? Map<String, dynamic>.from(row['quote'] as Map) : const <String, dynamic>{};
    final id = '${plan['id'] ?? ''}';
    final status = '${plan['status'] ?? 'draft'}';
    final live = status == 'published' || status == 'active';
    final monthly = intOf(quote['pricePiastres'] ?? plan['pricePiastres']) ~/ 100;
    final ref = intOf(quote['paygPiastres']) ~/ 100;
    final subs = intOf(row['subscriberCount']);
    final name = '${plan['name'] ?? ''}'.trim();
    final draft = status == 'draft';
    final archived = status == 'archived';
    return Container(
      key: Key('plan-$id'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Expanded(child: Text(name.isEmpty ? '[اسم الباقة]' : name, style: ws(16, w: FontWeight.w700))),
          const SizedBox(width: 8),
          WizStatusChip(status: status),
        ]),
        const SizedBox(height: 6),
        Text(_mix(plan), style: ws(13, c: Wiz.body)),
        const SizedBox(height: 10),
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
          Text(arGrouped(monthly), style: ws(19, w: FontWeight.w700, mono: true)),
          Text('ج.م / شهر', style: ws(12, c: Wiz.muted)),
          if (ref > monthly)
            Text.rich(TextSpan(style: ws(12, c: Wiz.muted), children: [
              const TextSpan(text: '· بدل '),
              TextSpan(text: arGrouped(ref), style: ws(12, c: Wiz.muted, mono: true)),
              const TextSpan(text: ' بالزيارة'),
            ])),
        ]),
        if (row['priceDrift'] == true)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('سعر الخدمة العادي اتغير أكتر من ١٠٪ من وقت ما عملتي الباقة.', style: ws(12, c: Wiz.goldNote)),
          ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.only(top: 11),
          decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEFE7E0)))),
          child: Row(children: [
            const WizAvatar(size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_who(plan), style: ws(12, w: FontWeight.w600)),
                Text(subscribersPhrase(subs), style: ws(11, c: Wiz.muted)),
              ]),
            ),
            if (!archived)
              Material(
                color: Wiz.plumTint,
                child: InkWell(
                  key: Key('edit-$id'),
                  onTap: () => _openFlow(existing: plan),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    alignment: Alignment.center,
                    child: Text(draft ? 'كمّلي' : 'تعديل', style: ws(12, w: FontWeight.w700, c: Wiz.plum)),
                  ),
                ),
              ),
          ]),
        ),
        if (!archived)
          Wrap(children: [
            if (status == 'paused') WizTextAction(key: Key('resume-$id'), label: 'ارجعيها', onTap: () => _resume(id)),
            if (live) WizTextAction(key: Key('pause-$id'), label: 'وقّفي', onTap: () => _pause(id)),
            if (!draft) WizTextAction(key: Key('dup-$id'), label: 'نسخة', color: Wiz.soft, onTap: () => _act(id, 'duplicate', done: 'اتعملت نسخة متوقّفة. راجعيها وشغّليها.')),
            WizTextAction(key: Key('archive-$id'), label: draft ? 'امسحي' : 'أرشيف', color: Wiz.danger, onTap: () => _archive(plan)),
          ]),
      ]),
    );
  }
}

/// Two labelled entries: باقاتي · المشتركات. (The week of visits lives on
/// الزيارات now, as the seven-day strip.)
class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.onSubscribers});
  final VoidCallback onSubscribers;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, {bool on = false, VoidCallback? tap, Key? key}) => Expanded(
          child: Material(
            color: on ? Wiz.surface : Colors.transparent,
            child: InkWell(
              key: key,
              onTap: tap,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: Text(label, style: ws(13, w: on ? FontWeight.w700 : FontWeight.w400, c: on ? Wiz.ink : Wiz.soft)),
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      color: Wiz.sand,
      child: Row(children: [
        tab('باقاتي', on: true, key: const Key('tab-plans')),
        tab('المشتركات', tap: onSubscribers, key: const Key('tab-subscribers')),
      ]),
    );
  }
}

// ===========================================================================
// Wizard flow (6 steps + published)
// ===========================================================================

const _stepTitles = [
  'اختاري الخدمات والزيارات',
  'سعر كل خدمة في الاشتراك',
  'حددي المواعيد',
  'ضيفي مميزات الباقة',
  'مين هتروح الزيارات؟',
  'راجعي وانشري',
];

class PlanWizardFlow extends StatefulWidget {
  const PlanWizardFlow({
    super.key,
    required this.services,
    this.existing,
    this.providerId = '',
    this.api = const LiveProApi(),
    this.now,
    this.pickDate = pickWizDate,
    this.onViewProfile,
    this.saveDelay = const Duration(milliseconds: 600),
  });
  final List<PlanService> services;
  final Map? existing;
  final String providerId;
  final ProApi api;
  final DateTime Function()? now;
  final WizDatePicker pickDate;
  final VoidCallback? onViewProfile;
  final Duration saveDelay;

  @override
  State<PlanWizardFlow> createState() => _PlanWizardFlowState();
}

class _PlanWizardFlowState extends State<PlanWizardFlow> {
  late final PlanDraft draft;
  late final DraftSaver saver;
  int step = 1;

  final nameC = TextEditingController();
  final benefitC = TextEditingController();
  final Map<String, TextEditingController> subC = {};

  List<TeamMember> team = [];
  bool teamLoading = true;
  bool teamFailed = false;

  bool published = false;
  bool busy = false;
  String? publishError;
  DraftSaveState saveState = DraftSaveState.idle;
  String doneName = '';
  String doneLine = '';

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    draft = PlanDraft(services: widget.services, now: _now);
    final ex = widget.existing;
    if (ex != null) {
      draft.restore(ex);
      final saved = intOf(ex['step']);
      final limit = !draft.ok1 ? 1 : !draft.ok2 ? 2 : !draft.ok3 ? 3 : 6;
      step = draft.editing ? 1 : (saved >= 1 && saved <= 6 ? (saved < limit ? saved : limit) : draft.firstIncompleteStep);
    }
    nameC.text = draft.name;
    saver = DraftSaver(
      send: () => _save('draft'),
      delay: widget.saveDelay,
      onState: (s) {
        if (mounted) setState(() => saveState = s);
      },
    );
    _loadTeam();
  }

  @override
  void dispose() {
    saver.dispose();
    nameC.dispose();
    benefitC.dispose();
    for (final c in subC.values) {
      c.dispose();
    }
    super.dispose();
  }

  // --- data ---------------------------------------------------------------

  Future<void> _loadTeam() async {
    setState(() {
      teamLoading = true;
      teamFailed = false;
    });
    try {
      final r = await widget.api.get('/pro/workers');
      final members = <TeamMember>[];
      for (final w in mapList(r['workers'])) {
        final m = TeamMember.fromJson(w);
        if (m != null) members.add(m);
      }
      if (!mounted) return;
      setState(() {
        team = members;
        draft.hasTeam = members.isNotEmpty;
        if (!draft.hasTeam) {
          draft.member = 'me';
        } else if (draft.member == 'me' || (draft.member != 'any' && !members.any((m) => m.id == draft.member))) {
          draft.member = 'any';
        }
        teamLoading = false;
      });
    } catch (_) {
      // Keep her previous choice; she can retry from step 5.
      if (mounted) {
        setState(() {
          teamLoading = false;
          teamFailed = true;
        });
      }
    }
  }

  Future<void> _save(String status, {String nameFallback = ''}) async {
    final r = await widget.api.post('/pro/plans', data: draft.body(status: status, step: step, nameFallback: nameFallback));
    final plan = r['plan'];
    if (plan is Map && plan['id'] != null) draft.planId = '${plan['id']}';
  }

  /// Every edit goes through here. Live plans are NOT autosaved (a new version
  /// would be created on every keystroke): they save when she presses
  /// «احفظي ونشري التعديل». Drafts autosave, including a name-only draft.
  void _touch() {
    setState(() {});
    if (draft.editing) return;
    if (draft.planId != null || draft.name.trim().isNotEmpty || draft.totalQty > 0) saver.schedule();
  }

  void _goto(int s) {
    setState(() {
      step = s;
    });
    if (!draft.editing && draft.planId != null) saver.schedule();
  }

  Future<void> _close() async {
    if (!draft.editing) await saver.flush();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _publish() async {
    if (!draft.ready || busy) return;
    setState(() {
      busy = true;
      publishError = null;
    });
    try {
      if (draft.isLive) {
        // Live plan: the publish endpoint merges this body first, validates
        // everything and bumps the version; subscribers keep their snapshot.
        final r = await widget.api.post('/pro/plans/${draft.planId}/publish', data: draft.body(status: 'published', step: step, nameFallback: 'باقة'));
        final plan = r['plan'];
        if (plan is Map && plan['id'] != null) draft.planId = '${plan['id']}';
      } else if (draft.isPaused) {
        await _save('paused', nameFallback: 'باقة');
      } else {
        await saver.flush();
        await _save('draft', nameFallback: 'باقة');
        await widget.api.post('/pro/plans/${draft.planId}/publish');
      }
      if (!mounted) return;
      final mix = draft.picked.map((s) => '${arNum(draft.qtyOf(s))} ${s.name}').join(' + ');
      setState(() {
        published = true;
        doneName = draft.name.trim().isEmpty ? 'باقة' : draft.name.trim();
        doneLine = '$mix · ${arGrouped(draft.price)} ج.م / شهر · ${daysLine(draft.days)}';
      });
    } catch (e) {
      if (mounted) setState(() => publishError = arError(e, fallback: 'ما قدرناش ننشر الباقة. جرّبي تاني.'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _openProfile() {
    if (widget.onViewProfile != null) {
      widget.onViewProfile!();
      return;
    }
    if (widget.providerId.isNotEmpty && GoRouter.maybeOf(context) != null) {
      GoRouter.of(context).push('/provider/${widget.providerId}');
    }
  }

  // --- helpers ----------------------------------------------------------------

  String _money(int n) => arGrouped(n);

  TextEditingController _subCtl(PlanService s) =>
      subC.putIfAbsent(s.id, () => TextEditingController(text: _subDisplay(s)));

  String _subDisplay(PlanService s) {
    final raw = draft.subRaw[s.id];
    return raw != null ? toArabicDigits(raw) : toArabicDigits(defaultSubEgp(s.regularEgp));
  }

  /// Push externally-changed values (the discount chips) into the persistent
  /// controllers. Typing never goes through here, so the caret is never reset.
  void _syncSubControllers() {
    for (final s in widget.services) {
      final c = subC[s.id];
      if (c == null) continue;
      final want = _subDisplay(s);
      if (c.text != want) c.value = TextEditingValue(text: want, selection: TextSelection.collapsed(offset: want.length));
    }
  }

  String _memberLabel() {
    final m = draft.effectiveMember;
    if (m == 'any') return 'أي عضوة متاحة من الفريق';
    if (m == 'me') return 'إنتي · صاحبة الحساب';
    for (final t in team) {
      if (t.id == m) return t.name;
    }
    return 'عضوة محددة';
  }

  Future<void> _pickStart() async {
    final today = dateOnly(_now);
    final cur = parseIso(draft.start) ?? today;
    final d = await widget.pickDate(context, initial: cur, first: today, last: today.add(const Duration(days: 365 * 2)), help: 'تاريخ البداية');
    if (d == null || !mounted) return;
    draft.start = isoDate(d);
    _touch();
  }

  Future<void> _pickEnd() async {
    final start = parseIso(draft.start) ?? dateOnly(_now);
    final first = start.add(const Duration(days: 1));
    final cur = parseIso(draft.end) ?? first.add(const Duration(days: 30));
    final d = await widget.pickDate(context, initial: cur.isBefore(first) ? first : cur, first: first, last: first.add(const Duration(days: 365 * 2)), help: 'تاريخ النهاية');
    if (d == null || !mounted) return;
    draft.end = isoDate(d);
    _touch();
  }

  void _addBenefit() {
    if (draft.addBenefit(benefitC.text)) {
      benefitC.clear();
      _touch();
    }
  }

  // --- build --------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: published ? _published() : _wizard(),
    );
  }

  Widget _published() {
    return Scaffold(
      backgroundColor: Wiz.cream,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.85, end: 1),
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOut,
                  builder: (_, v, child) => Opacity(opacity: ((v - 0.85) / 0.15).clamp(0.0, 1.0), child: Transform.scale(scale: v, child: child)),
                  child: Container(
                    decoration: BoxDecoration(border: Border.all(color: Wiz.plumTint, width: 10)),
                    child: Container(
                      width: 88,
                      height: 88,
                      alignment: Alignment.center,
                      color: Wiz.plum,
                      child: const OnsIcon('check', size: 40, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(draft.isPaused ? 'اتحفظ التعديل' : 'باقتك بقت متاحة', style: ws(26, w: FontWeight.w700)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  color: Wiz.goldTint,
                  child: Text(doneName, key: const Key('done-name'), style: ws(14, w: FontWeight.w700, c: Wiz.goldNote)),
                ),
                const SizedBox(height: 14),
                Text(doneLine, key: const Key('done-line'), textAlign: TextAlign.center, style: ws(13, c: Wiz.soft, h: 1.7)),
                if (draft.editing) ...[
                  const SizedBox(height: 10),
                  Text(
                    draft.isPaused
                        ? 'الباقة لسه متوقّفة. ارجعيها من باقاتي لما تحبي.'
                        : 'اتعمل إصدار جديد من الباقة. المشتركات الحاليين بيفضلوا على سعرهم لحد التجديد.',
                    textAlign: TextAlign.center,
                    style: ws(12, c: Wiz.muted, h: 1.6),
                  ),
                ],
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              WizGoldOutlineButton(key: const Key('view-profile'), label: 'شوفيها في بروفايلي', onTap: _openProfile),
              const SizedBox(height: 10),
              WizPrimaryButton(label: 'ارجعي لباقاتي', onTap: () => Navigator.of(context).pop()),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _wizard() {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (step > 1) {
          _goto(step - 1);
        } else {
          _close();
        }
      },
      child: Scaffold(
        backgroundColor: Wiz.cream,
        body: SafeArea(
          child: Column(children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                key: const Key('wizard-scroll'),
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
                child: _body(),
              ),
            ),
            _footer(),
          ]),
        ),
      ),
    );
  }

  Widget _header() {
    String? note;
    Color noteColor = Wiz.muted;
    if (draft.editing) {
      note = 'بتتحفظ لما تنشري';
    } else if (saveState == DraftSaveState.failed) {
      note = 'المسودة ما اتحفظتش · هنحاول تاني';
      noteColor = Wiz.danger;
    } else if (saveState == DraftSaveState.saving) {
      note = 'بنحفظ المسودة…';
    } else if (saveState == DraftSaveState.saved) {
      note = 'اتحفظت كمسودة';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 14),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Wiz.divider))),
      child: Column(children: [
        Row(children: [
          Tap44(
            key: const Key('wizard-back'),
            semanticLabel: 'رجوع',
            onTap: () => step == 1 ? _close() : _goto(step - 1),
            child: Container(width: 36, height: 36, alignment: Alignment.center, color: Wiz.sand, child: const OnsIcon('back', size: 16, color: Wiz.ink)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text.rich(TextSpan(children: [
                TextSpan(text: 'الخطوة ${arNum(step)} من ٦', style: ws(12, w: FontWeight.w700, c: Wiz.goldNote)),
                if (note != null) TextSpan(text: ' · $note', style: ws(11, c: noteColor), semanticsLabel: note),
              ])),
              Text(_stepTitles[step - 1], style: ws(18, w: FontWeight.w700)),
            ]),
          ),
          WizTextAction(key: const Key('wizard-cancel'), label: 'إلغاء', color: Wiz.muted, size: 12, weight: FontWeight.w400, onTap: _close),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          for (var i = 1; i <= 6; i++) ...[
            if (i > 1) const SizedBox(width: 4),
            Expanded(child: Container(height: 5, color: i <= step ? Wiz.plum : Wiz.border)),
          ],
        ]),
      ]),
    );
  }

  Widget _footer() {
    Widget? summary;
    if (step == 1) {
      final on = draft.totalQty > 0;
      summary = Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        color: on ? Wiz.plumTint : Wiz.chip,
        child: Text(
          key: const Key('mix-line'),
          on ? '${_mix(draft)} = ${visitsPhrase(draft.totalQty)} في الشهر' : 'اختاري خدمة واحدة على الأقل',
          style: ws(13, w: FontWeight.w600, c: on ? Wiz.plum : Wiz.muted, h: 1.6),
        ),
      );
    }
    final ok = draft.okFor(step);
    String label;
    switch (step) {
      case 2:
        label = ok ? 'التالي' : 'اكتبي سعر الاشتراك';
        break;
      case 3:
        label = ok ? 'التالي' : step3DisabledLabel(hasDays: draft.days.isNotEmpty);
        break;
      case 4:
        label = draft.benefits.isEmpty ? 'التالي من غير مميزات' : 'التالي';
        break;
      case 6:
        label = !ok ? 'كمّلي الخطوات الناقصة' : draft.isPaused ? 'احفظي التعديل' : publishLabel(editing: draft.editing);
        break;
      default:
        label = 'التالي';
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      decoration: const BoxDecoration(border: Border(top: BorderSide(color: Wiz.divider))),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (summary != null) ...[summary, const SizedBox(height: 10)],
        if (step == 6 && publishError != null) ...[
          Text(publishError!, key: const Key('publish-error'), textAlign: TextAlign.center, style: ws(13, c: Wiz.danger, h: 1.5)),
          const SizedBox(height: 8),
        ],
        WizPrimaryButton(
          key: const Key('wizard-cta'),
          label: label,
          enabled: ok,
          busy: busy,
          onTap: () => step == 6 ? _publish() : _goto(step + 1),
        ),
        if (step == 6) ...[
          const SizedBox(height: 8),
          Text('الباقة هتظهر للعميلات أول ما تنشريها.', textAlign: TextAlign.center, style: ws(11, c: Wiz.muted)),
        ],
      ]),
    );
  }

  String _mix(PlanDraft d) => d.picked.map((s) => '${arNum(d.qtyOf(s))} ${s.name}').join(' + ');

  Widget _body() {
    switch (step) {
      case 1:
        return _step1();
      case 2:
        return _step2();
      case 3:
        return _step3();
      case 4:
        return _step4();
      case 5:
        return _step5();
      default:
        return _step6();
    }
  }

  // ---- step 1 ---------------------------------------------------------------------

  Widget _step1() {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.inputBorder)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('اسم الباقة', style: ws(10, c: Wiz.muted)),
          TextField(
            key: const Key('name-field'),
            controller: nameC,
            maxLength: 60,
            inputFormatters: [LengthLimitingTextInputFormatter(60)],
            style: ws(15, w: FontWeight.w600),
            cursorColor: Wiz.plum,
            decoration: InputDecoration(
              isDense: true,
              counterText: '',
              border: InputBorder.none,
              contentPadding: const EdgeInsets.only(top: 6, bottom: 4),
              hintText: 'مثلاً: الأساسيات الأسبوعية',
              hintStyle: ws(15, w: FontWeight.w600, c: Wiz.faint),
            ),
            onChanged: (v) {
              draft.name = v;
              _touch();
            },
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Text('من خدماتك المعروضة · عدد كل خدمة في الشهر', style: ws(12, w: FontWeight.w600, c: Wiz.muted)),
      const SizedBox(height: 12),
      if (widget.services.isEmpty)
        WizDashed(
          padding: const EdgeInsets.all(16),
          child: Text('مفيش خدمات تنضيف مفعّلة على حسابك. فعّلي خدمة من «خدماتي» الأول.', textAlign: TextAlign.center, style: ws(13, c: Wiz.soft, h: 1.6)),
        )
      else
        Container(
          decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.border)),
          child: Column(children: [for (final s in widget.services) _serviceRow(s)]),
        ),
      if (draft.totalQty >= kMaxPlanVisits)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text('أقصى عدد في الباقة ${visitsPhrase(kMaxPlanVisits)} في الشهر.', key: const Key('max-visits'), style: ws(12, c: Wiz.goldNote)),
        ),
    ]);
  }

  Widget _serviceRow(PlanService s) {
    final n = draft.qtyOf(s);
    final canInc = draft.canInc(s);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(color: n > 0 ? Wiz.tile : Wiz.surface, border: const Border(bottom: BorderSide(color: Wiz.hair))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: ws(14, w: FontWeight.w700)),
            const SizedBox(height: 3),
            Text.rich(TextSpan(style: ws(12, c: Wiz.muted), children: [
              TextSpan(text: _money(s.regularEgp), style: ws(12, w: FontWeight.w600, c: Wiz.body, mono: true)),
              const TextSpan(text: ' ج.م للزيارة'),
            ])),
          ]),
        ),
        _stepBtn(
          key: Key('qty-dec-${s.id}'),
          label: 'نقّصي ${s.name}',
          icon: 'minus',
          bg: n > 0 ? const Color(0xFFF2ECE6) : Wiz.cream,
          fg: n > 0 ? Wiz.ink : Wiz.faint,
          onTap: n > 0
              ? () {
                  draft.setQty(s, n - 1);
                  _touch();
                }
              : null,
        ),
        SizedBox(width: 30, child: Text(arNum(n), key: Key('qty-${s.id}'), textAlign: TextAlign.center, style: ws(17, w: FontWeight.w700, c: n > 0 ? Wiz.ink : Wiz.faint, mono: true))),
        _stepBtn(
          key: Key('qty-inc-${s.id}'),
          label: 'زوّدي ${s.name}',
          icon: 'plus',
          bg: canInc ? Wiz.plum : Wiz.disabled,
          fg: canInc ? Colors.white : Wiz.muted,
          onTap: canInc
              ? () {
                  draft.setQty(s, n + 1);
                  _touch();
                }
              : null,
        ),
      ]),
    );
  }

  Widget _stepBtn({required Key key, required String label, required String icon, required Color bg, required Color fg, required VoidCallback? onTap}) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      child: InkWell(
        key: key,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: Container(width: 40, height: 40, alignment: Alignment.center, color: bg, child: ExcludeSemantics(child: OnsIcon(icon, size: 18, color: fg)))),
        ),
      ),
    );
  }

  // ---- step 2 -------------------------------------------------------------------------

  Widget _step2() {
    final picked = draft.picked;
    final mixShort = picked.isEmpty ? 'مفيش خدمات' : _mix(draft);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      WizCard(
        color: const Color(0xFFF2ECE6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text('إجمالي الحجز بالزيارة', style: ws(12, c: Wiz.soft))),
            const SizedBox(width: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2), color: Wiz.divider, child: Text('مرجع ثابت', style: ws(10, c: Wiz.muted))),
          ]),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: _money(draft.ref), style: ws(20, w: FontWeight.w700, c: Wiz.body, mono: true)),
            TextSpan(text: ' ج.م / شهر', style: ws(12, c: Wiz.muted)),
          ])),
          const SizedBox(height: 4),
          Text('$mixShort بأسعارك العادية', style: ws(11, c: Wiz.muted)),
        ]),
      ),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.plum, width: 2)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(color: Wiz.tile, border: Border(bottom: BorderSide(color: Color(0xFFEFE7E0)))),
            child: Row(children: [
              Expanded(child: Text('الخدمة', style: ws(10, w: FontWeight.w600, c: Wiz.muted))),
              const SizedBox(width: 8),
              SizedBox(width: 64, child: Text('بره الاشتراك', textAlign: TextAlign.center, style: ws(10, w: FontWeight.w600, c: Wiz.muted))),
              const SizedBox(width: 8),
              SizedBox(width: 92, child: Text('في الاشتراك', textAlign: TextAlign.center, style: ws(10, w: FontWeight.w600, c: Wiz.plum))),
            ]),
          ),
          for (final s in picked) _priceRow(s),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('سعر الاشتراك الشهري', style: ws(12, w: FontWeight.w700, c: Wiz.plum))),
              Text.rich(TextSpan(children: [
                TextSpan(text: _money(draft.price), style: ws(24, w: FontWeight.w700, mono: true)),
                TextSpan(text: ' ج.م', style: ws(12, c: Wiz.muted)),
              ]), key: const Key('wizard-monthly')),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Wrap(spacing: 6, children: [for (final p in const [5, 10, 15]) _quickChip(p)]),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      if (draft.saves)
        WizCard(
          color: Wiz.goldTint,
          borderColor: Wiz.goldBorder,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text.rich(
            key: const Key('wizard-save'),
            TextSpan(style: ws(14, w: FontWeight.w600, c: Wiz.goldInk, h: 1.6), children: [
              const TextSpan(text: 'العميلة بتوفّر '),
              TextSpan(text: _money(draft.save), style: ws(14, w: FontWeight.w700, c: Wiz.goldInk, mono: true)),
              TextSpan(text: ' ج.م (${arNum(draft.pct)}٪) عن الحجز بالزيارة'),
            ]),
          ),
        )
      else
        WizDashed(
          color: Wiz.disabled,
          background: Wiz.tile,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(noSaveText(allPriced: draft.allPriced, price: draft.price, save: draft.save), key: const Key('wizard-nosave'), style: ws(13, c: Wiz.soft, h: 1.6)),
        ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: _statTile('يعني للزيارة', perVisitEgp(draft.price, draft.totalQty), key: const Key('per-visit'))),
        const SizedBox(width: 8),
        Expanded(child: _statTile('العميلة بتدفع', clientPaysEgp(draft.price), key: const Key('net'))),
      ]),
      const SizedBox(height: 12),
      WizDashed(
        color: Wiz.gold,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Text('العميلة هتشوفها كده', style: ws(12, w: FontWeight.w700, c: Wiz.goldInk))),
            Text('معاينة', style: ws(10, c: Wiz.muted)),
          ]),
          const SizedBox(height: 9),
          for (final s in picked)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 4, children: [
                Text(s.name, style: ws(13)),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text('من غير اشتراك ${_money(s.regularEgp)}', style: ws(11, c: Wiz.muted)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    color: Wiz.plum,
                    child: Text('مشتركة ${draft.unitOf(s) > 0 ? _money(draft.unitOf(s)) : '—'}', style: ws(12, w: FontWeight.w700, c: Colors.white)),
                  ),
                ]),
              ]),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      Text('السعر هنا للباقة دي بس — أسعار خدماتك العادية مش هتتغيّر. خصم بسيط وثابت غالبًا بيشتغل أحسن من خصم كبير أوي.', style: ws(12, c: Wiz.muted, h: 1.7)),
    ]);
  }

  Widget _priceRow(PlanService s) {
    final u = draft.unitOf(s);
    final diff = s.regularEgp - u;
    final noteFg = u <= 0 || diff < 0 ? Wiz.danger : diff > 0 ? Wiz.goldNote : Wiz.muted;
    final border = u <= 0 ? Border.all(color: Wiz.danger, width: 1.5) : diff != 0 ? Border.all(color: Wiz.gold, width: 1.5) : Border.all(color: Wiz.inputBorder);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF4EEE8)))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: ws(13, w: FontWeight.w700)),
            const SizedBox(height: 3),
            Text('${arNum(draft.qtyOf(s))} في الشهر · ${priceNote(s.regularEgp, u)}', key: Key('note-${s.id}'), style: ws(11, c: noteFg)),
          ]),
        ),
        const SizedBox(width: 8),
        SizedBox(width: 64, child: Text(_money(s.regularEgp), textAlign: TextAlign.center, style: ws(13, c: Wiz.muted, mono: true))),
        const SizedBox(width: 8),
        Container(
          width: 92,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(color: Wiz.surface, border: border),
          alignment: Alignment.center,
          child: TextField(
            key: Key('sub-${s.id}'),
            controller: _subCtl(s),
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: const [ArDigitsFormatter()],
            style: ws(15, w: FontWeight.w700, mono: true),
            cursorColor: Wiz.plum,
            decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10)),
            onChanged: (v) {
              draft.subRaw[s.id] = normalizeDigits(v);
              _touch();
            },
          ),
        ),
      ]),
    );
  }

  Widget _quickChip(int p) {
    final sel = draft.chipSelected(p);
    final label = 'خصم ${arNum(p)}٪ على الكل';
    return Semantics(
      button: true,
      selected: sel,
      label: label,
      child: InkWell(
        key: Key('chip-$p'),
        onTap: sel
            ? null
            : () {
                draft.applyDiscount(p);
                _syncSubControllers();
                _touch();
              },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
              color: sel ? Wiz.plum : Wiz.chip,
              child: ExcludeSemantics(child: Text(label, style: ws(12, w: sel ? FontWeight.w600 : FontWeight.w400, c: sel ? Colors.white : Wiz.body))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statTile(String label, int? value, {Key? key}) {
    return WizCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: ws(10, c: Wiz.muted)),
        const SizedBox(height: 3),
        Text.rich(TextSpan(children: [
          TextSpan(text: value == null ? '—' : _money(value), style: ws(15, w: FontWeight.w700, mono: true)),
          TextSpan(text: ' ج.م', style: ws(10, c: Wiz.muted)),
        ]), key: key),
      ]),
    );
  }

  // ---- step 3 -------------------------------------------------------------------------

  Widget _step3() {
    final n = draft.days.length;
    final enough = daysEnough(n, draft.totalQty);
    final fitBg = enough ? Wiz.successBg : Wiz.dangerBg;
    final fitFg = enough ? Wiz.successFg : Wiz.danger;
    final endErr = !draft.ongoing && endBeforeStart(draft.start, draft.end);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('الأيام اللي العميلة تختار منها · اختاري يوم أو أكتر', style: ws(12, w: FontWeight.w600, c: Wiz.muted)),
      const SizedBox(height: 4),
      Text('كل يوم فيه فترتين: الصبح من ٩ وبعد الضهر من ٢. لو فترة اتحجزت، الفترة التانية بس هي اللي بتفضل متاحة.',
          key: const Key('periods-note'), style: ws(11, c: Wiz.soft, h: 1.5)),
      const SizedBox(height: 9),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 7 * 3) / 4;
        return Wrap(spacing: 7, runSpacing: 7, children: [
          for (var i = 0; i < 7; i++) _dayChip(i, w),
        ]);
      }),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        color: fitBg,
        child: Text(fitLine(n, draft.totalQty), key: const Key('fit-text'), style: ws(12, c: fitFg, h: 1.6)),
      ),
      const SizedBox(height: 14),
      WizCard(
        color: Wiz.surface,
        borderColor: Wiz.inputBorder,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('تاريخ البداية', style: ws(12, w: FontWeight.w600, c: Wiz.muted)),
          const SizedBox(height: 6),
          _dateField(key: const Key('start-field'), value: draft.start, placeholder: 'اختاري التاريخ', onTap: _pickStart),
          const SizedBox(height: 6),
          Text(niceDate(draft.start), key: const Key('start-nice'), style: ws(11, c: Wiz.muted)),
        ]),
      ),
      const SizedBox(height: 14),
      Text('مدة الباقة', style: ws(12, w: FontWeight.w600, c: Wiz.muted)),
      const SizedBox(height: 9),
      Container(
        padding: const EdgeInsets.all(4),
        color: Wiz.sand,
        child: Row(children: [
          _durationTab('مستمرة · من غير نهاية', draft.ongoing, () {
            draft.ongoing = true;
            _touch();
          }, key: const Key('mode-ongoing')),
          const SizedBox(width: 4),
          _durationTab('حددي تاريخ نهاية', !draft.ongoing, () {
            draft.ongoing = false;
            _touch();
          }, key: const Key('mode-end')),
        ]),
      ),
      if (!draft.ongoing)
        TweenAnimationBuilder<double>(
          key: const Key('end-reveal'),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          builder: (_, v, child) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, -6 * (1 - v)), child: child)),
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: WizCard(
              color: Wiz.surface,
              borderColor: Wiz.inputBorder,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('تاريخ النهاية', style: ws(12, w: FontWeight.w600, c: Wiz.muted)),
                const SizedBox(height: 6),
                _dateField(key: const Key('end-field'), value: draft.end, placeholder: kPickEnd, onTap: _pickEnd, error: endErr),
                const SizedBox(height: 6),
                Text(endNiceLine(draft.start, draft.end), key: const Key('end-nice'), style: ws(11, c: endErr ? Wiz.danger : Wiz.muted)),
              ]),
            ),
          ),
        ),
    ]);
  }

  Widget _dayChip(int i, double w) {
    final on = draft.days.contains(i);
    return SizedBox(
      width: w,
      height: 44,
      child: Semantics(
        button: true,
        selected: on,
        label: dayFull[i],
        child: Material(
          color: on ? Wiz.plum : Wiz.surface,
          child: InkWell(
            key: Key('day-$i'),
            onTap: () {
              on ? draft.days.remove(i) : draft.days.add(i);
              _touch();
            },
            child: Container(
              alignment: Alignment.center,
              decoration: on ? null : BoxDecoration(border: Border.all(color: Wiz.border)),
              child: ExcludeSemantics(child: Text(on ? '✓ ${dayShort[i]}' : dayShort[i], style: ws(13, w: on ? FontWeight.w700 : FontWeight.w400, c: on ? Colors.white : Wiz.body))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _durationTab(String label, bool on, VoidCallback onTap, {Key? key}) {
    return Expanded(
      child: Material(
        color: on ? Wiz.surface : Colors.transparent,
        child: InkWell(
          key: key,
          onTap: onTap,
          child: Container(height: 44, alignment: Alignment.center, child: Text(label, style: ws(13, w: on ? FontWeight.w700 : FontWeight.w400, c: on ? Wiz.ink : Wiz.soft))),
        ),
      ),
    );
  }

  Widget _dateField({required Key key, required String value, required String placeholder, required VoidCallback onTap, bool error = false}) {
    final has = parseIso(value) != null;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: Wiz.tile, border: error ? Border.all(color: Wiz.danger, width: 1.5) : Border.all(color: Wiz.border)),
        child: Row(children: [
          Expanded(child: Text(has ? shortDate(value) : placeholder, style: ws(15, w: FontWeight.w600, c: has ? Wiz.ink : Wiz.faint, mono: has))),
          const OnsIcon('calendar', size: 18, color: Wiz.muted),
        ]),
      ),
    );
  }

  // ---- step 4 -------------------------------------------------------------------------

  Widget _step4() {
    final canAdd = benefitC.text.trim().isNotEmpty && !draft.benefitsFull;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('المميزات بتساعد العميلة تقارن بين باقاتك — مش بالسعر بس.', style: ws(13, c: Wiz.soft, h: 1.7)),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.inputBorder)),
            child: TextField(
              key: const Key('benefit-input'),
              controller: benefitC,
              enabled: !draft.benefitsFull,
              maxLength: kBenefitMaxLen,
              inputFormatters: [LengthLimitingTextInputFormatter(kBenefitMaxLen)],
              style: ws(14),
              cursorColor: Wiz.plum,
              decoration: InputDecoration(
                isDense: true,
                counterText: '',
                border: InputBorder.none,
                hintText: draft.benefits.length.isOdd ? 'مثلاً: تغيير الميعاد مجانًا مرة في الشهر' : 'مثلاً: نفس المنظّفة كل زيارة',
                hintStyle: ws(14, c: Wiz.faint),
              ),
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _addBenefit(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: canAdd ? Wiz.plum : Wiz.disabled,
          child: InkWell(
            key: const Key('benefit-add'),
            onTap: canAdd ? _addBenefit : null,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48, minWidth: 44),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              child: Text('+ ضيفي', style: ws(13, w: FontWeight.w700, c: canAdd ? Colors.white : Wiz.muted)),
            ),
          ),
        ),
      ]),
      if (draft.benefitsFull)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text('وصلتي للحد الأقصى: ${featuresPhrase(kMaxBenefits)}. امسحي ميزة لو عايزة تضيفي غيرها.', key: const Key('benefits-full'), style: ws(12, c: Wiz.goldNote, h: 1.5)),
        ),
      const SizedBox(height: 12),
      if (draft.benefits.isNotEmpty)
        Container(
          decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < draft.benefits.length; i++)
              Container(
                key: Key('benefit-$i'),
                padding: const EdgeInsetsDirectional.fromSTEB(14, 4, 4, 4),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFFF4EEE8)))),
                child: Row(children: [
                  Container(width: 22, height: 22, alignment: Alignment.center, color: Wiz.goldTint, child: Text('✓', style: ws(12, w: FontWeight.w700, c: Wiz.goldNote))),
                  const SizedBox(width: 10),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(draft.benefits[i], style: ws(14, h: 1.5)))),
                  Tap44(
                    key: Key('benefit-del-$i'),
                    semanticLabel: 'امسحي الميزة',
                    onTap: () {
                      draft.benefits.removeAt(i);
                      _touch();
                    },
                    child: Container(width: 32, height: 32, alignment: Alignment.center, color: Wiz.chip, child: const OnsIcon('close', size: 14, color: Wiz.danger)),
                  ),
                ]),
              ),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9), child: Text(featuresPhrase(draft.benefits.length), key: const Key('benefits-count'), style: ws(11, c: Wiz.muted))),
          ]),
        )
      else
        WizDashed(
          color: const Color(0xFFD6C9D1),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(children: [
            Text('لسه مفيش مميزات', style: ws(13, w: FontWeight.w600, c: Wiz.body)),
            const SizedBox(height: 5),
            Text('مش إجباري، بس ميزة واحدة على الأقل بتفرق في المقارنة.', textAlign: TextAlign.center, style: ws(12, c: Wiz.muted, h: 1.6)),
          ]),
        ),
    ]);
  }

  // ---- step 5 -------------------------------------------------------------------------

  Widget _step5() {
    if (teamLoading) {
      return const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator(color: Wiz.plum)));
    }
    if (!draft.hasTeam) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (teamFailed) _teamRetry(),
        Text('مفيش فريق على حسابك دلوقتي، فالباقة دي هتبقى عليكي.', style: ws(13, c: Wiz.soft, h: 1.7)),
        const SizedBox(height: 12),
        Container(
          key: const Key('solo-card'),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.plum, width: 2)),
          child: Row(children: [
            const WizAvatar(size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إنتي · صاحبة الحساب', style: ws(15, w: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('كل زيارات الباقة هتروحيها بنفسك', style: ws(12, c: Wiz.muted)),
              ]),
            ),
            const WizRadio(selected: true),
          ]),
        ),
        const SizedBox(height: 12),
        WizDashed(
          color: Wiz.disabled,
          background: Wiz.tile,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Text('عندك فريق؟ ضيفيهم من حسابي ← الفريق، وتقدري تعدّلي الباقة بعدين.', style: ws(12, c: Wiz.soft, h: 1.6)),
        ),
      ]);
    }
    final rows = <({String id, String name, String sub, TeamMember? m})>[
      (id: 'any', name: 'أي عضوة متاحة', sub: 'أُنس بتوزّع حسب مواعيد الفريق', m: null),
      for (final t in team) (id: t.id, name: t.name, sub: t.rating != null ? 'تقييم ${toArabicDigits(t.rating!.toStringAsFixed(1).replaceAll('.', '٫'))}' : 'عضوة الفريق', m: t),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (teamFailed) _teamRetry(),
      Text('اختاري عضوة معيّنة للباقة دي، أو سيبيها لأي حد متاح من فريقك.', style: ws(13, c: Wiz.soft, h: 1.7)),
      const SizedBox(height: 12),
      Container(
        decoration: BoxDecoration(color: Wiz.surface, border: Border.all(color: Wiz.border)),
        child: Column(children: [
          for (final r in rows)
            InkWell(
              key: Key('member-${r.id}'),
              onTap: () {
                draft.member = r.id;
                _touch();
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 66),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: draft.member == r.id ? Wiz.tile : Wiz.surface, border: const Border(bottom: BorderSide(color: Wiz.hair))),
                child: Row(children: [
                  r.m == null ? const WizAvatar(size: 40, gold: true) : WizAvatar(size: 40, label: r.name, imageUrl: r.m!.photoUrl),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.name, style: ws(14, w: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(r.sub, style: ws(11, c: Wiz.muted)),
                    ]),
                  ),
                  WizRadio(selected: draft.member == r.id),
                ]),
              ),
            ),
        ]),
      ),
    ]);
  }

  Widget _teamRetry() => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: WizCard(
          color: Wiz.dangerBg,
          borderColor: Wiz.danger,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(children: [
            Expanded(child: Text('ما قدرناش نجيب فريقك.', style: ws(12, c: Wiz.danger))),
            WizTextAction(key: const Key('team-retry'), label: 'جرّبي تاني', onTap: _loadTeam),
          ]),
        ),
      );

  // ---- step 6 -------------------------------------------------------------------------

  Widget _step6() {
    final nameShown = draft.name.trim().isEmpty ? '[اسم الباقة]' : draft.name.trim();
    Widget section(String title, int jump, List<Widget> children) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: WizCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text(title, style: ws(11, w: FontWeight.w600, c: Wiz.muted)),
                WizTextAction(key: Key('edit-step-$jump'), label: 'تعديل', size: 12, onTap: () => _goto(jump)),
              ]),
              ...children,
            ]),
          ),
        );
    final tot = draft.totalQty;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(nameShown, key: const Key('review-name'), style: ws(20, w: FontWeight.w700)),
      const SizedBox(height: 10),
      section('الخدمات والزيارات', 1, [
        for (final s in draft.picked)
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('${arNum(draft.qtyOf(s))} × ${s.name}', style: ws(13)),
                Text(_money(draft.qtyOf(s) * draft.unitOf(s)), style: ws(13, c: Wiz.soft, mono: true)),
              ]),
              const SizedBox(height: 2),
              Text('في الاشتراك ${_money(draft.unitOf(s))} · بره الاشتراك ${_money(s.regularEgp)}', style: ws(11, c: Wiz.muted)),
            ]),
          ),
        const SizedBox(height: 2),
        Text('${visitsPhrase(tot)} في الشهر', style: ws(12, c: Wiz.muted)),
      ]),
      section('السعر', 2, [
        Wrap(crossAxisAlignment: WrapCrossAlignment.end, spacing: 6, children: [
          Text(_money(draft.price), key: const Key('review-price'), style: ws(20, w: FontWeight.w700, mono: true)),
          Text('ج.م / شهر', style: ws(12, c: Wiz.muted)),
          Text.rich(TextSpan(style: ws(12, c: Wiz.muted), children: [
            const TextSpan(text: '· بدل '),
            TextSpan(text: _money(draft.ref), style: ws(12, c: Wiz.muted, mono: true)),
            const TextSpan(text: ' بالزيارة'),
          ])),
        ]),
        const SizedBox(height: 4),
        Text(draft.save > 0 ? 'العميلة بتوفّر ${_money(draft.save)} ج.م (${arNum(draft.pct)}٪)' : 'مفيش توفير عن الحجز بالزيارة', style: ws(12, c: Wiz.goldNote)),
      ]),
      section('الأيام المتاحة للعميلة', 3, [
        Text(daysLine(draft.days), key: const Key('review-days'), style: ws(14, w: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('من ${niceDate(draft.start)} · ${endLine(ongoing: draft.ongoing, end: draft.end)}', key: const Key('review-dates'), style: ws(12, c: Wiz.soft, h: 1.5)),
      ]),
      section('المميزات', 4, [
        if (draft.benefits.isNotEmpty)
          for (final b in draft.benefits)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('✓', style: ws(13, w: FontWeight.w700, c: Wiz.gold)),
                const SizedBox(width: 8),
                Expanded(child: Text(b, style: ws(13, h: 1.5))),
              ]),
            )
        else
          Text('مفيش مميزات مضافة', style: ws(13, c: Wiz.ghost)),
      ]),
      section('مين هتروح', 5, [Text(_memberLabel(), key: const Key('review-member'), style: ws(14, w: FontWeight.w600))]),
      if (draft.editing)
        WizDashed(
          color: Wiz.gold,
          background: Wiz.goldTint,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Text(
            'لما تحفظي هيتعمل إصدار جديد من الباقة. المشتركات الحاليين بيفضلوا على سعرهم لحد التجديد، وهنبلّغهم قبلها.',
            key: const Key('edit-note'),
            style: ws(12, c: Wiz.goldInk, h: 1.6),
          ),
        ),
    ]);
  }
}

// ===========================================================================
// Reusable price table (kept for callers that render it standalone)
// ===========================================================================

/// Compact in-vs-out preview line used outside the wizard.
class InOutLine extends StatelessWidget {
  const InOutLine({super.key, required this.name, required this.regularEgp, required this.subEgp});
  final String name;
  final int regularEgp;
  final int subEgp;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Expanded(child: Text(name, style: ws(13))),
        const SizedBox(width: 8),
        Text('من غير اشتراك ${arGrouped(regularEgp)}', style: ws(11, c: Wiz.muted)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          color: Wiz.plum,
          child: Text('مشتركة ${arGrouped(subEgp)}', style: ws(12, w: FontWeight.w700, c: Colors.white)),
        ),
      ]),
    );
  }
}
