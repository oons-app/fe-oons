import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/ui_state.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/ui/buttons.dart';
import 'package:oons/admin_v2/ui/grid_table.dart';
import 'package:oons/admin_v2/ui/list_view.dart';
import 'package:oons/data/api.dart';

class CategoriesScreen extends ConsumerStatefulWidget {
  const CategoriesScreen({super.key});

  @override
  ConsumerState<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends ConsumerState<CategoriesScreen> {
  List<Map<String, dynamic>> categories = [];
  bool loading = true;
  String? error;
  String filter = 'All';
  String q = '';

  static const _verticals = [
    ('beauty', 'Beauty'),
    ('cleaning', 'Home'),
    ('chef', 'Food'),
  ];
  static const _filters = ['All', 'Active', 'Draft', 'Locked'];

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(v2HeaderConfigProvider.notifier).state =
            V2HeaderConfig(newLabel: 'Category', onNewRecord: () => _edit(null));
      }
    });
  }

  Future<void> _load() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      final data = await staffClient.get('/admin/categories', query: {'includeLocked': '1', 'children': '1'});
      setState(() {
        categories = asMapList(data['categories']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  /// The server encodes state in `status`: `active` | `locked_teaser` | `archived`.
  bool _isLocked(Map c) => '${c['status']}'.toLowerCase().contains('lock') || c['locked'] == true;

  String _status(Map c) {
    final s = '${c['status']}'.toLowerCase();
    if (_isLocked(c)) return 'Locked';
    if (s == 'archived' || s == 'draft' || c['active'] == false) return 'Draft';
    return 'Active';
  }

  int _count(String f) => f == 'All' ? categories.length : categories.where((c) => _status(c) == f).length;

  List<Map<String, dynamic>> get _rows {
    var list = categories;
    if (filter != 'All') list = list.where((c) => _status(c) == filter).toList();
    if (q.isNotEmpty) {
      final n = q.toLowerCase();
      list = list.where((c) => c.values.join(' ').toLowerCase().contains(n)).toList();
    }
    return list;
  }

  Future<void> _edit(Map? c) async {
    final lang = ref.read(localeCodeProvider);
    final en = TextEditingController(text: '${asMap(c?['name'])?['en'] ?? ''}');
    final ar = TextEditingController(text: '${asMap(c?['name'])?['ar'] ?? ''}');
    final slug = TextEditingController(text: '${c?['slug'] ?? ''}');
    var vertical = '${c?['vertical'] ?? 'beauty'}';
    try {
      final ok = await v2Form(
        context,
        title: c == null ? (lang == 'ar' ? 'فئة جديدة' : 'New category') : (lang == 'ar' ? 'تعديل الفئة' : 'Edit category'),
        bodyBuilder: (ctx, setLocal) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(label: 'Name (EN)', child: TextField(controller: en)),
            const SizedBox(height: 12),
            V2FormField(label: 'الاسم (AR)', child: TextField(controller: ar)),
            const SizedBox(height: 12),
            V2FormField(label: 'Slug', child: TextField(controller: slug)),
            const SizedBox(height: 12),
            V2FormField(
              label: 'Vertical',
              child: DropdownButtonFormField<String>(
                initialValue: vertical,
                items: [for (final v in _verticals) DropdownMenuItem(value: v.$1, child: Text(v.$2))],
                onChanged: (v) => vertical = v ?? 'beauty',
              ),
            ),
          ],
        ),
        onValidate: () {
          if (en.text.trim().isEmpty) {
            v2Toast(context, lang == 'ar' ? 'الاسم مطلوب' : 'Name is required', error: true);
            return false;
          }
          return true;
        },
      );
      if (!ok) return;
      final payload = {
        'name': {'en': en.text.trim(), 'ar': ar.text.trim()},
        'slug': slug.text.trim(),
        'vertical': vertical,
      };
      try {
        if (c == null) {
          await staffClient.post('/admin/categories', data: payload);
        } else {
          await staffClient.patch('/admin/categories/${idOf(c)}', data: payload);
        }
        if (mounted) {
          v2Toast(context, c == null ? (lang == 'ar' ? 'تم الإنشاء' : 'Category created') : (lang == 'ar' ? 'تم التحديث' : 'Category updated'));
          _load();
        }
      } on ApiException catch (e) {
        if (mounted) v2Toast(context, e.message, error: true);
      }
    } finally {
      en.dispose();
      ar.dispose();
      slug.dispose();
    }
  }

  Future<void> _toggleLock(Map c) async {
    final lang = ref.read(localeCodeProvider);
    // Server state lives in `status`: flip active <-> locked_teaser.
    final locking = !_isLocked(c);
    final next = locking ? 'locked_teaser' : 'active';
    try {
      await staffClient.patch('/admin/categories/${idOf(c)}', data: {'status': next});
      _load();
      if (mounted) {
        v2Toast(context, locking
            ? (lang == 'ar' ? 'اتقفل التصنيف' : 'Category locked')
            : (lang == 'ar' ? 'اتفتح التصنيف' : 'Category unlocked'));
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _reorder(List<Map<String, dynamic>> ordered, int i, {required bool up}) async {
    final j = up ? i - 1 : i + 1;
    if (j < 0 || j >= ordered.length) return;
    final lang = ref.read(localeCodeProvider);
    final next = [...ordered];
    final tmp = next[i];
    next[i] = next[j];
    next[j] = tmp;
    // Server contract: the full list with explicit sortOrder values.
    final order = [for (var k = 0; k < next.length; k++) {'id': idOf(next[k]), 'sortOrder': k}];
    try {
      await staffClient.post('/admin/categories/reorder', data: {'order': order});
      _load();
      if (mounted) v2Toast(context, lang == 'ar' ? 'اترتب' : 'Order updated');
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _delete(Map c) async {
    final lang = ref.read(localeCodeProvider);
    final ok = await v2Confirm(context,
        title: lang == 'ar' ? 'حذف الفئة؟' : 'Delete category?',
        body: '"${locName(c['name'], lang)}" ${lang == 'ar' ? 'ستُحذف.' : 'is removed from the console.'}',
        confirmLabel: t(V2Copy.delete, lang),
        danger: true);
    if (!ok) return;
    try {
      await staffClient.delete('/admin/categories/${idOf(c)}');
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم الحذف' : 'Category deleted');
        _load();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final role = ref.watch(staffSessionProvider).effectiveRole;
    if (!staffCan(role, 'categories.write')) return const V2Gate(allowed: false, child: SizedBox.shrink());
    ref.listen(v2QueryProvider, (_, n) => setState(() => q = n.trim()));
    final visible = _rows;
    // Reordering writes explicit sortOrder for the whole list — only safe when
    // nothing is filtered out.
    final canReorder = filter == 'All' && q.isEmpty;

    return V2ListView(
      loading: loading,
      error: error,
      onRetry: _load,
      resultLabel: '${visible.length} ${lang == 'ar' ? 'نتيجة' : 'results'}',
      emptyText: lang == 'ar' ? 'لا فئات' : 'Nothing here yet',
      actionsWidth: 210,
      trailingActions: [
        V2Btn.primary(lang == 'ar' ? '+ فئة' : '+ New Category', onPressed: () => _edit(null), size: V2BtnSize.sm),
      ],
      filters: [
        for (final f in _filters)
          V2FilterChip(label: f, count: _count(f), selected: filter == f, onTap: () => setState(() => filter = f)),
      ],
      columns: [
        V2Col(lang == 'ar' ? 'الفئة' : 'Category', flex: 1),
        V2Col('Slug', flex: 1),
        V2Col(lang == 'ar' ? 'الخدمات' : 'Services', fixed: 90),
        V2Col(lang == 'ar' ? 'الحالة' : 'Status', fixed: 110),
      ],
      rows: [
        for (var i = 0; i < visible.length; i++)
          V2GridRow(
            cells: [
              Text(locName(visible[i]['name'], lang),
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              Text('${visible[i]['slug'] ?? ''}',
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontFamily: Ops.mono, color: Ops.inkSoft)),
              Text('${asInt(visible[i]['providerCount'] ?? visible[i]['serviceCount'])}',
                  style: const TextStyle(fontSize: 13, fontFamily: Ops.mono)),
              Align(alignment: AlignmentDirectional.centerStart, child: V2StatusPill.forLabel(_status(visible[i]))),
            ],
            actions: [
              V2Btn(
                  label: _isLocked(visible[i]) ? (lang == 'ar' ? 'فتح' : 'Unlock') : (lang == 'ar' ? 'قفل' : 'Lock'),
                  onPressed: () => _toggleLock(visible[i]),
                  size: V2BtnSize.row),
              V2Btn(label: '↑', onPressed: (!canReorder || i == 0) ? null : () => _reorder(visible, i, up: true), size: V2BtnSize.row),
              V2Btn(label: '↓', onPressed: (!canReorder || i == visible.length - 1) ? null : () => _reorder(visible, i, up: false), size: V2BtnSize.row),
              V2Btn.ghost(lang == 'ar' ? 'تعديل' : 'Edit', onPressed: () => _edit(visible[i]), size: V2BtnSize.row),
              V2Btn.danger(lang == 'ar' ? 'حذف' : 'Delete', onPressed: () => _delete(visible[i]), size: V2BtnSize.row),
            ],
          ),
      ],
    );
  }
}
