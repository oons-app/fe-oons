import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      setState(() { loading = true; error = null; });
      final data = await staffClient.get('/admin/categories', query: {'includeLocked': '1', 'children': '1'});
      setState(() { categories = asMapList(data['categories']); loading = false; });
    } on ApiException catch (e) {
      setState(() { error = e.message; loading = false; });
    }
  }

  Future<void> _toggleLock(String id, bool isLocked) async {
    final lang = ref.read(localeCodeProvider);
    try {
      await staffClient.patch('/admin/categories/$id', data: {'locked': !isLocked});
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _reorderCategory(String id, bool moveUp) async {
    final lang = ref.read(localeCodeProvider);
    try {
      final direction = moveUp ? 'up' : 'down';
      await staffClient.post('/admin/categories/reorder', data: {'categoryId': id, 'direction': direction});
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم إعادة الترتيب' : 'Reordered'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _editCategory(Map<String, dynamic> category) async {
    final lang = ref.read(localeCodeProvider);
    final originalName = asMap(category['name']);
    String? nameEn = originalName?['en'], nameAr = originalName?['ar'], slug = category['slug'], vertical = category['vertical'];
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'تعديل الفئة' : 'Edit category',
      confirmLabel: lang == 'ar' ? 'حفظ' : 'Save',
      bodyBuilder: (ctx, setLocal) => Column(children: [
        V2FormField(label: 'Name (EN)', child: TextField(controller: TextEditingController(text: nameEn), onChanged: (v) => nameEn = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: 'الاسم (AR)', child: TextField(controller: TextEditingController(text: nameAr), onChanged: (v) => nameAr = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: 'Slug', child: TextField(controller: TextEditingController(text: slug), onChanged: (v) => slug = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(
          label: 'Vertical',
          child: DropdownButtonFormField<String>(
            value: vertical,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'beauty', child: Text('Beauty')),
              DropdownMenuItem(value: 'cleaning', child: Text('Home')),
              DropdownMenuItem(value: 'chef', child: Text('Food')),
            ],
            onChanged: (v) => setLocal(() => vertical = v),
          ),
        ),
      ]),
    );
    if (!confirmed) return;
    try {
      await staffClient.patch('/admin/categories/${idOf(category)}', data: {
        'name': {'en': nameEn, 'ar': nameAr},
        'slug': slug,
        'vertical': vertical,
      });
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم التحديث' : 'Updated'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _createCategory() async {
    final lang = ref.read(localeCodeProvider);
    String? nameEn, nameAr, slug, vertical = 'beauty';
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'إنشاء فئة' : 'Create category',
      confirmLabel: lang == 'ar' ? 'إنشاء' : 'Create',
      bodyBuilder: (ctx, setLocal) => Column(children: [
        V2FormField(label: 'Name (EN)', child: TextField(onChanged: (v) => nameEn = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: 'الاسم (AR)', child: TextField(onChanged: (v) => nameAr = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(label: 'Slug', child: TextField(onChanged: (v) => slug = v, decoration: const InputDecoration(border: OutlineInputBorder()))),
        const SizedBox(height: 12),
        V2FormField(
          label: 'Vertical',
          child: DropdownButtonFormField<String>(
            value: vertical,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'beauty', child: Text('Beauty')),
              DropdownMenuItem(value: 'cleaning', child: Text('Home')),
              DropdownMenuItem(value: 'chef', child: Text('Food')),
            ],
            onChanged: (v) => setLocal(() => vertical = v),
          ),
        ),
      ]),
    );
    if (!confirmed) return;
    try {
      await staffClient.post('/admin/categories', data: {
        'name': {'en': nameEn, 'ar': nameAr},
        'slug': slug,
        'vertical': vertical,
      });
      if (mounted) { v2Toast(context, lang == 'ar' ? 'تم الإنشاء' : 'Created'); _load(); }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);
    if (!staffCan(staffState.effectiveRole, 'categories.write')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }
    return ColoredBox(
      color: Ops.page,
      child: Column(children: [
        V2PageHeader(
          title: lang == 'ar' ? 'الفئات' : 'Categories',
          lang: lang,
          resultCount: loading ? null : categories.length,
          actions: [ElevatedButton.icon(onPressed: _createCategory, icon: const Icon(Icons.add, size: 16), label: Text(lang == 'ar' ? 'إنشاء' : 'Create'))],
        ),
        Expanded(child: loading
          ? const V2Loading()
          : error != null
            ? Center(child: V2ErrorBanner(message: error!, onRetry: _load))
            : categories.isEmpty
              ? const V2Empty()
              : ListView(padding: const EdgeInsets.symmetric(horizontal: 20), children: [
                  V2Card(padding: EdgeInsets.zero, child: V2DataTable(
                    headers: [
                      lang == 'ar' ? 'الفئة' : 'Category',
                      lang == 'ar' ? 'المحور' : 'Vertical',
                      lang == 'ar' ? 'الترتيب' : 'Order',
                      lang == 'ar' ? 'المهنيات' : 'Providers',
                      lang == 'ar' ? 'الحالة' : 'Status',
                      lang == 'ar' ? 'إجراءات' : 'Actions',
                    ],
                    rows: [
                      for (int i = 0; i < categories.length; i++)
                        [
                          Text(locName(categories[i]['name'], lang), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text('${categories[i]['vertical'] ?? ''}'),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('${asInt(categories[i]['sortOrder'])}', style: const TextStyle(fontFamily: Ops.mono)),
                              const SizedBox(width: 8),
                              if (i > 0) 
                                IconButton(
                                  onPressed: () => _reorderCategory(idOf(categories[i]), true),
                                  icon: const Icon(Icons.keyboard_arrow_up, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: lang == 'ar' ? 'رفع' : 'Move up',
                                ),
                              if (i < categories.length - 1)
                                IconButton(
                                  onPressed: () => _reorderCategory(idOf(categories[i]), false),
                                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: lang == 'ar' ? 'خفض' : 'Move down',
                                ),
                            ],
                          ),
                          Text('${asInt(categories[i]['providerCount'] ?? categories[i]['serviceCount'])}', style: const TextStyle(fontFamily: Ops.mono)),
                          InkWell(
                            onTap: () => _toggleLock(idOf(categories[i]), categories[i]['locked'] == true),
                            child: V2StatusPill(
                              label: statusLabel('${categories[i]['status'] ?? (categories[i]['locked'] == true ? 'locked' : 'active')}', lang),
                              tone: statusTone('${categories[i]['status'] ?? (categories[i]['locked'] == true ? 'locked' : 'active')}'),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _editCategory(categories[i]),
                            child: Text(lang == 'ar' ? 'تعديل' : 'Edit'),
                          ),
                        ],
                    ],
                  )),
                  const SizedBox(height: 24),
                ]),
        ),
      ]),
    );
  }
}
