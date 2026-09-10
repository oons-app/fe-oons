import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/buttons.dart';

/// Sticky console header from `Oons Ops Console v2.html`: page title + subtitle
/// on the left; an always-visible search box, an optional `+ New …` action and
/// a `Live N` shortcut on the right.
class V2Header extends StatefulWidget {
  const V2Header({
    super.key,
    required this.title,
    required this.subtitle,
    required this.lang,
    this.query = '',
    this.onSearch,
    this.searchHint,
    this.newLabel,
    this.onNewRecord,
    this.liveCount,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String lang;
  final String query;
  final ValueChanged<String>? onSearch;
  final String? searchHint;
  final String? newLabel;
  final VoidCallback? onNewRecord;
  final int? liveCount;
  final List<Widget>? trailing;

  @override
  State<V2Header> createState() => _V2HeaderState();
}

class _V2HeaderState extends State<V2Header> {
  late final TextEditingController _c = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(covariant V2Header old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query && widget.query != _c.text) _c.text = widget.query;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ar = widget.lang == 'ar';
    return Container(
      padding: const EdgeInsets.fromLTRB(Ops.gutter, 14, Ops.gutter, 14),
      decoration: const BoxDecoration(
        color: Color(0xF0F3EEE7),
        border: Border(bottom: BorderSide(color: Ops.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.title,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700, color: Ops.ink, letterSpacing: -0.3)),
                if (widget.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(widget.subtitle, style: const TextStyle(fontSize: 12.5, color: Ops.muted, height: 1.35)),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 260,
                child: Container(
                  decoration: BoxDecoration(
                    color: Ops.card,
                    borderRadius: BorderRadius.circular(Ops.radiusCtl),
                    border: Border.all(color: Ops.borderStrong),
                  ),
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 15, color: Ops.placeholder),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _c,
                          enabled: widget.onSearch != null,
                          onChanged: widget.onSearch,
                          style: const TextStyle(fontSize: 13, color: Ops.ink),
                          decoration: InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            hintText: widget.searchHint ??
                                (ar ? 'ابحث بالاسم أو الهاتف أو المرجع' : 'Search name, phone, or ref'),
                            hintStyle: const TextStyle(fontSize: 13, color: Ops.placeholder),
                          ),
                        ),
                      ),
                      if (_c.text.isNotEmpty)
                        InkWell(
                          onTap: () {
                            _c.clear();
                            widget.onSearch?.call('');
                          },
                          child: const Icon(Icons.close, size: 14, color: Ops.muted),
                        ),
                    ],
                  ),
                ),
              ),
              if (widget.onNewRecord != null && widget.newLabel != null)
                V2Btn.primary(ar ? '+ ${widget.newLabel}' : '+ New ${widget.newLabel}', onPressed: widget.onNewRecord),
              V2Btn(
                label: '${ar ? 'مباشر' : 'Live'} ${widget.liveCount ?? ''}'.trim(),
                onPressed: () => context.go(V2Paths.live),
                kind: V2BtnKind.ghost,
                leadingDot: Ops.green,
              ),
              ...?widget.trailing,
            ],
          ),
        ],
      ),
    );
  }
}

String headerTitleFor(String path, String lang) {
  for (final g in v2Nav) {
    for (final i in g.items) {
      if (path == i.path || path.startsWith('${i.path}/')) {
        return lang == 'ar' ? i.labelAr : i.labelEn;
      }
    }
  }
  if (path.startsWith(V2Paths.matrix)) return lang == 'ar' ? 'مصفوفة الصلاحيات' : 'Role matrix';
  if (path.startsWith(V2Paths.impersonate)) return lang == 'ar' ? 'عرض الحساب' : 'Impersonating';
  return lang == 'ar' ? 'لوحة التشغيل' : 'Ops console';
}

String headerSubFor(String path, String lang) {
  final ar = lang == 'ar';
  if (path == V2Paths.home) return ar ? 'كل ما يحتاج انتباهك، في مكان واحد.' : 'Everything that needs your attention, in one place.';
  if (path == V2Paths.live) return ar ? 'زيارات على الأرض — تحديث كل ٣٠ ثانية.' : 'On-ground visits — auto-refresh every 30s.';
  if (path == V2Paths.bookings) return ar ? 'ابحث وصفِّ وسوِّ الدفعات.' : 'Search, filter, and settle payouts.';
  if (path.startsWith('${V2Paths.bookings}/')) return ar ? 'سجل الزيارة، فرض الحالة، حل النزاع.' : 'Full visit record, force status, resolve dispute.';
  if (path == V2Paths.providers) return ar ? 'المهنيات، التحقق، الفهرسة.' : 'Professionals, vetting, and search index.';
  if (path.startsWith('${V2Paths.providers}/')) return ar ? 'المستندات، الخدمات، المناطق، الجدول، المعرض، المال.' : 'Docs, services, areas, schedule, portfolio, money.';
  if (path == V2Paths.customers) return ar ? 'العميلات المسجلات.' : 'Registered customers.';
  if (path.startsWith('${V2Paths.customers}/')) return ar ? 'الملف، العناوين، التعليمات، السجل.' : 'Profile, addresses, instructions, history.';
  if (path == V2Paths.claims) return ar ? 'المطالبات بعد النزاع.' : 'Post-dispute claims.';
  if (path == V2Paths.payouts) return ar ? 'السحوبات بانتظار الموافقة.' : 'Withdrawals awaiting approval.';
  if (path == V2Paths.ledger) return ar ? 'أرصدة المهنيات: المتاح والمحجوز.' : 'Provider balances: available and held.';
  if (path == V2Paths.batches) return ar ? 'الدفعات المسواة، الإيصالات و Excel.' : 'Settled bulk payouts, receipts and Excel.';
  if (path == V2Paths.categories) return ar ? 'إنشاء، تعديل، إعادة ترتيب، قفل الفئات.' : 'Create, edit, reorder, lock verticals.';
  if (path == V2Paths.areas) return ar ? 'المدن، رسوم الانتقال، القفل.' : 'Cities, travel fees, lock/unlock.';
  if (path == V2Paths.payments) return ar ? 'وضع البوابة، إعفاء الرسوم، المعاملات.' : 'Gateway mode, fee waiver, transactions.';
  if (path == V2Paths.audit) return ar ? 'كل إجراء، بمن ومتى.' : 'Every action, with who and when.';
  if (path == V2Paths.heatmap) return ar ? 'العرض والطلب حسب المنطقة.' : 'Supply and demand by area.';
  if (path == V2Paths.vetting) return ar ? 'طابور الانتظار ومهل التحقق.' : 'Pending queue and wait times.';
  return '';
}
