import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:oons/admin_v2/data/maps.dart';
import 'package:oons/admin_v2/data/staff_client.dart';
import 'package:oons/admin_v2/data/session.dart';
import 'package:oons/admin_v2/data/permissions.dart';
import 'package:oons/admin_v2/data/paths.dart';
import 'package:oons/admin_v2/l10n/copy.dart';
import 'package:oons/admin_v2/ui/atoms.dart';
import 'package:oons/admin_v2/chrome/modal.dart';
import 'package:oons/admin_v2/chrome/toast.dart';
import 'package:oons/admin_v2/theme/tokens.dart';
import 'package:oons/data/api.dart';
import 'package:oons/core/format.dart';

class ProviderDetailScreen extends ConsumerStatefulWidget {
  final String providerId;

  const ProviderDetailScreen({super.key, required this.providerId});

  @override
  ConsumerState<ProviderDetailScreen> createState() => _ProviderDetailScreenState();
}

class _ProviderDetailScreenState extends ConsumerState<ProviderDetailScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? provider;
  bool loading = true;
  String? error;
  late TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 6, vsync: this);
    _loadProvider();
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  Future<void> _loadProvider() async {
    try {
      setState(() {
        loading = true;
        error = null;
      });
      
      final data = await staffClient.get('/admin/providers/${widget.providerId}');
      setState(() {
        provider = unwrapEntity(data, const ['provider']);
        loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  Future<void> _vetProvider(String action) async {
    final lang = ref.read(localeCodeProvider);
    final confirmed = await v2Confirm(
      context,
      title: lang == 'ar' ? 'تأكيد الإجراء' : 'Confirm action',
      body: lang == 'ar' ? 'هل تريد $action هذه المهنية؟' : '$action this provider?',
      confirmLabel: action,
    );
    
    if (!confirmed) return;

    try {
      if (action.toLowerCase() == 'reject') {
        await staffClient.post('/admin/providers/${widget.providerId}/reject');
      } else {
        // Vet: POST body {sexMarkerConfirmed: true}
        await staffClient.post('/admin/providers/${widget.providerId}/vet', data: {
          'sexMarkerConfirmed': true,
        });
      }
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم تنفيذ الإجراء' : 'Action completed');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _impersonateProvider() async {
    final lang = ref.read(localeCodeProvider);
    try {
      final response = await staffClient.post('/admin/providers/${widget.providerId}/impersonate');
      final token = '${response['accessToken'] ?? response['impersonateToken'] ?? ''}';
      final name = personName(provider, lang, fallbackId: widget.providerId);
      
      if (token.isNotEmpty) {
        ref.read(staffSessionProvider.notifier).startImpersonation(
          id: widget.providerId,
          name: name,
          token: token,
          kind: 'provider',
        );
        if (mounted) {
          context.go(V2Paths.impersonateSubject(widget.providerId, kind: 'provider'));
        }
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeCodeProvider);
    final staffState = ref.watch(staffSessionProvider);

    if (!staffCan(staffState.effectiveRole, 'providers.read')) {
      return const V2Gate(allowed: false, child: SizedBox.shrink());
    }

    return ColoredBox(
      color: Ops.page,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 12, 0),
            child: Row(
              children: [
                IconButton(onPressed: () => context.go(V2Paths.providers), icon: const Icon(Icons.arrow_back)),
                Expanded(child: Text(lang == 'ar' ? 'تفاصيل المهنية' : 'Provider details', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                if (staffCan(staffState.effectiveRole, 'providers.impersonate'))
                  TextButton.icon(
                    onPressed: _impersonateProvider,
                    icon: const Icon(Icons.login, size: 16),
                    label: Text(lang == 'ar' ? 'تسجيل دخول كـ' : 'Impersonate'),
                  ),
              ],
            ),
          ),
          TabBar(
            controller: tabController,
            isScrollable: true,
            tabs: [
              Tab(text: lang == 'ar' ? 'نظرة عامة' : 'Overview'),
              Tab(text: lang == 'ar' ? 'الوثائق' : 'Documents'),
              Tab(text: lang == 'ar' ? 'الخدمات' : 'Services'),
              Tab(text: lang == 'ar' ? 'التغطية' : 'Coverage'),
              Tab(text: lang == 'ar' ? 'المعرض' : 'Portfolio'),
              Tab(text: lang == 'ar' ? 'المال' : 'Money'),
            ],
          ),
          Expanded(child: loading
          ? const V2Loading()
          : error != null
              ? Center(
                  child: V2ErrorBanner(
                    message: error!,
                    onRetry: _loadProvider,
                  ),
                )
              : provider == null
                  ? const V2Empty()
                  : TabBarView(
                      controller: tabController,
                      children: [
                        _buildOverviewTab(provider!, lang, staffState),
                        _buildDocumentsTab(provider!, lang, staffState),
                        _buildServicesTab(provider!, lang, staffState),
                        _buildCoverageTab(provider!, lang, staffState),
                        _buildPortfolioTab(provider!, lang, staffState),
                        _buildMoneyTab(provider!, lang, staffState),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _suspendProvider(String reason) async {
    try {
      await staffClient.post('/admin/providers/${widget.providerId}/suspend', data: {
        'reason': reason,
      });
      if (mounted) {
        v2Toast(context, 'Provider suspended');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _reinstateProvider() async {
    try {
      await staffClient.post('/admin/providers/${widget.providerId}/reinstate');
      if (mounted) {
        v2Toast(context, 'Provider reinstated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _reverifyProvider() async {
    try {
      await staffClient.post('/admin/providers/${widget.providerId}/reverify');
      if (mounted) {
        v2Toast(context, 'Provider sent for reverification');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _updateNotes(String notes) async {
    try {
      await staffClient.patch('/admin/providers/${widget.providerId}/notes', data: {
        'notes': notes,
      });
      if (mounted) {
        v2Toast(context, 'Notes updated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _buildOverviewTab(Map<String, dynamic> provider, String lang, StaffState staffState) {
    final status = providerState(provider, 'en').toLowerCase();
    final notes = '${provider['staffNotes'] ?? provider['notes'] ?? ''}';
    final stats = asMap(provider['stats']) ?? {};
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            personName(provider, lang, fallbackId: idOf(provider)),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Ops.ink),
                          ),
                          Text(
                            '#${provider['id']}',
                            style: const TextStyle(color: Ops.muted, fontFamily: Ops.mono),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        V2StatusPill(
                          label: status,
                          tone: status == 'suspended' ? V2Tone.bad : 
                                status == 'active' ? V2Tone.ok : V2Tone.warn,
                        ),
                        if (status == 'suspended') ...[
                          const SizedBox(height: 4),
                          V2StatusPill(
                            label: lang == 'ar' ? 'معلق' : 'Suspended',
                            tone: V2Tone.bad,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('${provider['phone'] ?? ''}', style: const TextStyle(fontFamily: Ops.mono)),
                
                // Stats
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (stats['totalBookings'] != null)
                        Text('${lang == 'ar' ? 'إجمالي الحجوزات:' : 'Total bookings:'} ${stats['totalBookings']}',
                          style: const TextStyle(fontSize: 13, color: Ops.muted)),
                      if (stats['completedBookings'] != null)
                        Text('${lang == 'ar' ? 'الحجوزات المكتملة:' : 'Completed:'} ${stats['completedBookings']}',
                          style: const TextStyle(fontSize: 13, color: Ops.muted)),
                      if (stats['rating'] != null)
                        Text('${lang == 'ar' ? 'التقييم:' : 'Rating:'} ${stats['rating']}',
                          style: const TextStyle(fontSize: 13, color: Ops.muted)),
                    ],
                  ),
                ],
                
                const SizedBox(height: 16),
                
                // Action buttons
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Vetting actions
                    if (staffCan(staffState.effectiveRole, 'providers.vet') && status == 'pending') ...[
                      ElevatedButton(
                        onPressed: () => _vetProvider('approve'),
                        style: ElevatedButton.styleFrom(backgroundColor: Ops.green),
                        child: Text(lang == 'ar' ? 'موافقة' : 'Approve'),
                      ),
                      ElevatedButton(
                        onPressed: () => _vetProvider('reject'),
                        style: ElevatedButton.styleFrom(backgroundColor: Ops.terracottaInk),
                        child: Text(lang == 'ar' ? 'رفض' : 'Reject'),
                      ),
                    ],
                    
                    // Suspend/reinstate actions
                    if (staffCan(staffState.effectiveRole, 'providers.vet')) ...[
                      if (status == 'active')
                        ElevatedButton(
                          onPressed: () async {
                            String suspendReason = '';
                            final confirmed = await v2Form(
                              context,
                              title: lang == 'ar' ? 'تعليق المهنية' : 'Suspend provider',
                              confirmLabel: lang == 'ar' ? 'تعليق' : 'Suspend',
                              bodyBuilder: (ctx, setState) {
                                return V2FormField(
                                  label: lang == 'ar' ? 'سبب التعليق' : 'Suspension reason',
                                  child: TextField(
                                    onChanged: (value) => suspendReason = value,
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                    maxLines: 3,
                                  ),
                                );
                              },
                            );
                            // Only call API when confirm is true and reason is not empty
                            if (confirmed == true && suspendReason.isNotEmpty) {
                              _suspendProvider(suspendReason);
                            }
                          },
                          style: ElevatedButton.styleFrom(backgroundColor: Ops.terracottaInk),
                          child: Text(lang == 'ar' ? 'تعليق' : 'Suspend'),
                        )
                      else if (status == 'suspended')
                        ElevatedButton(
                          onPressed: _reinstateProvider,
                          style: ElevatedButton.styleFrom(backgroundColor: Ops.green),
                          child: Text(lang == 'ar' ? 'إلغاء التعليق' : 'Reinstate'),
                        ),
                    ],
                    
                    // Reverify
                    if (staffCan(staffState.effectiveRole, 'providers.vet') && status != 'pending')
                      ElevatedButton(
                        onPressed: _reverifyProvider,
                        style: ElevatedButton.styleFrom(backgroundColor: Ops.plum),
                        child: Text(lang == 'ar' ? 'إعادة تحقق' : 'Reverify'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Notes section
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lang == 'ar' ? 'ملاحظات' : 'Notes',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (staffCan(staffState.effectiveRole, 'notes.write'))
                  GestureDetector(
                    onTap: () async {
                      String updatedNotes = notes;
                      final confirmed = await v2Form(
                        context,
                        title: lang == 'ar' ? 'تحرير الملاحظات' : 'Edit notes',
                        confirmLabel: lang == 'ar' ? 'حفظ' : 'Save',
                        bodyBuilder: (ctx, setState) {
                          return V2FormField(
                            label: lang == 'ar' ? 'ملاحظات' : 'Notes',
                            child: TextField(
                              controller: TextEditingController(text: notes),
                              onChanged: (value) => updatedNotes = value,
                              decoration: const InputDecoration(border: OutlineInputBorder()),
                              maxLines: 4,
                            ),
                          );
                        },
                      );
                      if (confirmed) _updateNotes(updatedNotes);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Ops.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        notes.isEmpty 
                          ? (lang == 'ar' ? 'اضغط لإضافة ملاحظات...' : 'Tap to add notes...')
                          : notes,
                        style: TextStyle(
                          color: notes.isEmpty ? Ops.muted : Ops.ink,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Ops.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      notes.isEmpty 
                        ? (lang == 'ar' ? 'لا توجد ملاحظات' : 'No notes')
                        : notes,
                      style: TextStyle(
                        color: notes.isEmpty ? Ops.muted : Ops.ink,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _updateDocStatus(String docType, String status, {String? note}) async {
    try {
      await staffClient.post('/admin/providers/${widget.providerId}/docs/$docType', data: {
        'status': status,
        if (note != null && note.isNotEmpty) 'note': note,
      });
      if (mounted) {
        v2Toast(context, 'Document status updated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _buildDocumentsTab(Map<String, dynamic> provider, String lang, StaffState staffState) {
    final idPath = '${provider['idPhotoUrl'] ?? provider['idPath'] ?? ''}'.isEmpty ? null : '${provider['idPhotoUrl'] ?? provider['idPath']}';
    final fishPath = '${provider['fishPhotoUrl'] ?? provider['fishPath'] ?? ''}'.isEmpty ? null : '${provider['fishPhotoUrl'] ?? provider['fishPath']}';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (idPath != null) ...[
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang == 'ar' ? 'بطاقة الهوية' : 'ID Document',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (staffCan(staffState.effectiveRole, 'providers.vet')) ...[
                        TextButton.icon(
                          onPressed: () => _updateDocStatus('id', 'accepted'),
                          icon: const Icon(Icons.check, color: Ops.green, size: 16),
                          label: Text(lang == 'ar' ? 'قبول' : 'Accept',
                            style: const TextStyle(color: Ops.green)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            String note = '';
                            final confirmed = await v2Form(
                              context,
                              title: lang == 'ar' ? 'رفض الوثيقة' : 'Reject document',
                              confirmLabel: lang == 'ar' ? 'رفض' : 'Reject',
                              bodyBuilder: (ctx, setState) {
                                return V2FormField(
                                  label: lang == 'ar' ? 'سبب الرفض (اختياري)' : 'Rejection reason (optional)',
                                  child: TextField(
                                    onChanged: (value) => note = value,
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                    maxLines: 2,
                                  ),
                                );
                              },
                            );
                            if (confirmed) _updateDocStatus('id', 'rejected', note: note);
                          },
                          icon: const Icon(Icons.close, color: Ops.terracottaInk, size: 16),
                          label: Text(lang == 'ar' ? 'رفض' : 'Reject',
                            style: const TextStyle(color: Ops.terracottaInk)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final bytes = await staffClient.uploadBytes(idPath);
                      if (bytes != null && mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppBar(
                                    title: Text(lang == 'ar' ? 'بطاقة الهوية' : 'ID Document'),
                                    automaticallyImplyLeading: true,
                                  ),
                                  Expanded(
                                    child: Image.memory(bytes, fit: BoxFit.contain),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Ops.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FutureBuilder<Uint8List?>(
                        future: staffClient.uploadBytes(idPath),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                            );
                          }
                          return const Center(
                            child: Icon(Icons.image, size: 48, color: Ops.muted),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          if (fishPath != null) ...[
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lang == 'ar' ? 'فيش جنائي' : 'Criminal Record',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (staffCan(staffState.effectiveRole, 'providers.vet')) ...[
                        TextButton.icon(
                          onPressed: () => _updateDocStatus('fish', 'accepted'),
                          icon: const Icon(Icons.check, color: Ops.green, size: 16),
                          label: Text(lang == 'ar' ? 'قبول' : 'Accept',
                            style: const TextStyle(color: Ops.green)),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            String note = '';
                            final confirmed = await v2Form(
                              context,
                              title: lang == 'ar' ? 'رفض الوثيقة' : 'Reject document',
                              confirmLabel: lang == 'ar' ? 'رفض' : 'Reject',
                              bodyBuilder: (ctx, setState) {
                                return V2FormField(
                                  label: lang == 'ar' ? 'سبب الرفض (اختياري)' : 'Rejection reason (optional)',
                                  child: TextField(
                                    onChanged: (value) => note = value,
                                    decoration: const InputDecoration(border: OutlineInputBorder()),
                                    maxLines: 2,
                                  ),
                                );
                              },
                            );
                            if (confirmed) _updateDocStatus('fish', 'rejected', note: note);
                          },
                          icon: const Icon(Icons.close, color: Ops.terracottaInk, size: 16),
                          label: Text(lang == 'ar' ? 'رفض' : 'Reject',
                            style: const TextStyle(color: Ops.terracottaInk)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () async {
                      final bytes = await staffClient.uploadBytes(fishPath);
                      if (bytes != null && mounted) {
                        showDialog(
                          context: context,
                          builder: (ctx) => Dialog(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppBar(
                                    title: Text(lang == 'ar' ? 'فيش جنائي' : 'Criminal Record'),
                                    automaticallyImplyLeading: true,
                                  ),
                                  Expanded(
                                    child: Image.memory(bytes, fit: BoxFit.contain),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }
                    },
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Ops.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: FutureBuilder<Uint8List?>(
                        future: staffClient.uploadBytes(fishPath),
                        builder: (context, snapshot) {
                          if (snapshot.hasData && snapshot.data != null) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.memory(snapshot.data!, fit: BoxFit.cover),
                            );
                          }
                          return const Center(
                            child: Icon(Icons.image, size: 48, color: Ops.muted),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          
          if (idPath == null && fishPath == null)
            const V2Empty(message: 'No documents uploaded'),
        ],
      ),
    );
  }

  Future<void> _updateServices(List<Map<String, dynamic>> services) async {
    try {
      await staffClient.patch('/admin/providers/${widget.providerId}', data: {
        'items': services,
      });
      if (mounted) {
        v2Toast(context, 'Services updated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _buildServicesTab(Map<String, dynamic> provider, String lang, StaffState staffState) {
    final items = asDynList(provider['items'] ?? provider['services']);
    final services = items.cast<Map<String, dynamic>>();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                lang == 'ar' ? 'الخدمات' : 'Services',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (staffCan(staffState.effectiveRole, 'providers.write'))
                ElevatedButton.icon(
                  onPressed: () => _editServices(services, lang),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(lang == 'ar' ? 'تحرير' : 'Edit'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (services.isEmpty)
            const V2Empty(message: 'No services configured')
          else
            V2DataTable(
              headers: [
                lang == 'ar' ? 'الخدمة' : 'Service',
                lang == 'ar' ? 'المدة (د)' : 'Duration (min)',
                lang == 'ar' ? 'السعر' : 'Price',
              ],
              rows: services.map((service) {
                final svc = asMap(service) ?? {};
                final nameEn = locName(svc['name'], 'en');
                final nameAr = locName(svc['name'], 'ar');
                final duration = asInt(svc['durationMin']);
                final price = asInt(svc['price']);
                
                return [
                  Text(lang == 'ar' ? nameAr : nameEn),
                  Text('$duration', style: const TextStyle(fontFamily: Ops.mono)),
                  Text(money(price, lang), style: const TextStyle(fontFamily: Ops.mono)),
                ];
              }).toList(),
            ),
        ],
      ),
    );
  }

  Future<void> _editServices(List<Map<String, dynamic>> currentServices, String lang) async {
    List<Map<String, dynamic>> editableServices = List.from(currentServices);
    
    await v2Form(
      context,
      title: lang == 'ar' ? 'تحرير الخدمات' : 'Edit Services',
      confirmLabel: lang == 'ar' ? 'حفظ' : 'Save',
      bodyBuilder: (ctx, setState) {
        return StatefulBuilder(
          builder: (context, setFormState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...editableServices.asMap().entries.map((entry) {
                  final index = entry.key;
                  final service = entry.value;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Ops.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('${lang == 'ar' ? 'خدمة' : 'Service'} ${index + 1}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            ),
                            IconButton(
                              onPressed: () {
                                setFormState(() {
                                  editableServices.removeAt(index);
                                });
                              },
                              icon: const Icon(Icons.delete, color: Ops.terracottaInk),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(text: service['name']?['en'] ?? ''),
                          decoration: InputDecoration(
                            labelText: lang == 'ar' ? 'الاسم بالإنجليزية' : 'Name (English)',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            service['name'] ??= {};
                            service['name']['en'] = value;
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: TextEditingController(text: service['name']?['ar'] ?? ''),
                          decoration: InputDecoration(
                            labelText: lang == 'ar' ? 'الاسم بالعربية' : 'Name (Arabic)',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            service['name'] ??= {};
                            service['name']['ar'] = value;
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: '${service['durationMin'] ?? ''}'),
                                decoration: InputDecoration(
                                  labelText: lang == 'ar' ? 'المدة (دقائق)' : 'Duration (minutes)',
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  service['durationMin'] = int.tryParse(value) ?? 0;
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: TextEditingController(text: '${(service['price'] ?? 0) / 100}'),
                                decoration: InputDecoration(
                                  labelText: lang == 'ar' ? 'السعر (ج.م)' : 'Price (EGP)',
                                  border: const OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                onChanged: (value) {
                                  service['price'] = ((double.tryParse(value) ?? 0) * 100).round();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
                
                ElevatedButton.icon(
                  onPressed: () {
                    setFormState(() {
                      editableServices.add({
                        'name': {'en': '', 'ar': ''},
                        'durationMin': 60,
                        'price': 0,
                      });
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: Text(lang == 'ar' ? 'إضافة خدمة' : 'Add Service'),
                ),
              ],
            );
          },
        );
      },
    ).then((confirmed) {
      if (confirmed) _updateServices(editableServices);
    });
  }

  List<Map<String, dynamic>> _availableAreas = [];
  bool _loadingAreas = false;

  Future<void> _loadAreas() async {
    if (_availableAreas.isNotEmpty) return;
    
    setState(() => _loadingAreas = true);
    try {
      final data = await staffClient.get('/admin/areas');
      setState(() {
        _availableAreas = asMapList(data['areas']);
        _loadingAreas = false;
      });
    } on ApiException catch (e) {
      setState(() => _loadingAreas = false);
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _updateAreas(List<String> selectedSlugs) async {
    try {
      await staffClient.patch('/admin/providers/${widget.providerId}', data: {
        'areas': selectedSlugs,
      });
      if (mounted) {
        v2Toast(context, 'Coverage areas updated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _buildCoverageTab(Map<String, dynamic> provider, String lang, StaffState staffState) {
    final providerAreas = asDynList(provider['areas']).map((e) => '$e').toList();
    final workDays = provider['workDays'] as List?;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      lang == 'ar' ? 'مناطق التغطية' : 'Coverage Areas',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (staffCan(staffState.effectiveRole, 'providers.vet'))
                      ElevatedButton.icon(
                        onPressed: () async {
                          await _loadAreas();
                          if (mounted) _editAreas(providerAreas, lang);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(lang == 'ar' ? 'تحرير' : 'Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (_loadingAreas)
                  const V2Loading()
                else if (providerAreas.isEmpty)
                  Text(
                    lang == 'ar' ? 'لم يتم تحديد مناطق' : 'No areas selected',
                    style: const TextStyle(color: Ops.muted),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: providerAreas.map((areaSlug) {
                      final area = _availableAreas.firstWhere(
                        (a) => a['slug'] == areaSlug,
                        orElse: () => {'name': {'en': areaSlug, 'ar': areaSlug}},
                      );
                      return Chip(
                        label: Text(locName(area['name'], lang)),
                        backgroundColor: Ops.plum.withOpacity(0.1),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          
          if (workDays != null) ...[
            const SizedBox(height: 16),
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'ar' ? 'أيام العمل' : 'Work Days',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  
                  if (workDays.isEmpty)
                    Text(
                      lang == 'ar' ? 'لم يتم تحديد أيام' : 'No days specified',
                      style: const TextStyle(color: Ops.muted),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: workDays.cast<String>().map((day) {
                        return Chip(
                          label: Text(_getDayName(day, lang)),
                          backgroundColor: Ops.green.withOpacity(0.1),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getDayName(String day, String lang) {
    final days = {
      'monday': lang == 'ar' ? 'الاثنين' : 'Monday',
      'tuesday': lang == 'ar' ? 'الثلاثاء' : 'Tuesday', 
      'wednesday': lang == 'ar' ? 'الأربعاء' : 'Wednesday',
      'thursday': lang == 'ar' ? 'الخميس' : 'Thursday',
      'friday': lang == 'ar' ? 'الجمعة' : 'Friday',
      'saturday': lang == 'ar' ? 'السبت' : 'Saturday',
      'sunday': lang == 'ar' ? 'الأحد' : 'Sunday',
    };
    return days[day.toLowerCase()] ?? day;
  }

  Future<void> _editAreas(List<String> currentAreas, String lang) async {
    Set<String> selectedAreas = Set.from(currentAreas);
    
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'تحرير مناطق التغطية' : 'Edit Coverage Areas',
      confirmLabel: lang == 'ar' ? 'حفظ' : 'Save',
      bodyBuilder: (ctx, setState) {
        return StatefulBuilder(
          builder: (context, setFormState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  lang == 'ar' ? 'اختر المناطق:' : 'Select areas:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _availableAreas.map((area) {
                    final slug = '${area['slug'] ?? area['id'] ?? ''}';
                    final isSelected = selectedAreas.contains(slug);
                    
                    return FilterChip(
                      label: Text(locName(area['name'], lang)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setFormState(() {
                          if (selected) {
                            selectedAreas.add(slug);
                          } else {
                            selectedAreas.remove(slug);
                          }
                        });
                      },
                      selectedColor: Ops.plum.withOpacity(0.2),
                      checkmarkColor: Ops.plum,
                    );
                  }).toList(),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (confirmed) _updateAreas(selectedAreas.toList());
  }

  Future<void> _updatePortfolio(List<String> portfolioUrls) async {
    try {
      await staffClient.patch('/admin/providers/${widget.providerId}', data: {
        'portfolio': portfolioUrls,
      });
      if (mounted) {
        v2Toast(context, 'Portfolio updated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _buildPortfolioTab(Map<String, dynamic> provider, String lang, StaffState staffState) {
    final portfolio = asDynList(provider['portfolio']).map((e) => '$e').toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                lang == 'ar' ? 'معرض الأعمال' : 'Portfolio',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              if (staffCan(staffState.effectiveRole, 'providers.vet'))
                ElevatedButton.icon(
                  onPressed: () => _editPortfolio(portfolio, lang),
                  icon: const Icon(Icons.edit, size: 16),
                  label: Text(lang == 'ar' ? 'تحرير' : 'Edit'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (portfolio.isEmpty)
            const V2Empty(message: 'No portfolio images')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1,
              ),
              itemCount: portfolio.length,
              itemBuilder: (context, index) {
                final imageUrl = portfolio[index];
                
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => Dialog(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppBar(
                                title: Text('${lang == 'ar' ? 'صورة' : 'Image'} ${index + 1}'),
                                automaticallyImplyLeading: true,
                              ),
                              Expanded(
                                child: FutureBuilder<Uint8List?>(
                                  future: staffClient.uploadBytes(imageUrl),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData && snapshot.data != null) {
                                      return Image.memory(snapshot.data!, fit: BoxFit.contain);
                                    }
                                    return const Center(child: V2Loading());
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Ops.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: FutureBuilder<Uint8List?>(
                            future: staffClient.uploadBytes(imageUrl),
                            builder: (context, snapshot) {
                              if (snapshot.hasData && snapshot.data != null) {
                                return Image.memory(
                                  snapshot.data!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                );
                              }
                              return const Center(
                                child: Icon(Icons.image, size: 32, color: Ops.muted),
                              );
                            },
                          ),
                        ),
                        if (staffCan(staffState.effectiveRole, 'providers.vet'))
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () {
                                final updatedPortfolio = List<String>.from(portfolio);
                                updatedPortfolio.removeAt(index);
                                _updatePortfolio(updatedPortfolio);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Ops.terracottaInk,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _editPortfolio(List<String> currentPortfolio, String lang) async {
    String url = '';
    String requestNote = '';
    final ok = await v2Form(
      context,
      title: lang == 'ar' ? 'تحرير المعرض' : 'Edit portfolio',
      confirmLabel: lang == 'ar' ? 'حفظ' : 'Save',
      bodyBuilder: (ctx, setLocal) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            lang == 'ar'
                ? 'أضيفي رابط صورة أو اطلبي صوراً جديدة من المهنية.'
                : 'Add an image URL or request new photos from the professional.',
            style: const TextStyle(fontSize: 13, color: Ops.muted),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'رابط صورة' : 'Image URL',
            child: TextField(
              onChanged: (v) => url = v,
              decoration: const InputDecoration(hintText: 'https://…'),
            ),
          ),
          const SizedBox(height: 12),
          V2FormField(
            label: lang == 'ar' ? 'طلب صور (ملاحظة)' : 'Request photos (note)',
            child: TextField(
              onChanged: (v) => requestNote = v,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: lang == 'ar' ? 'اختياري' : 'Optional',
              ),
            ),
          ),
        ],
      ),
      onValidate: () {
        if (url.trim().isEmpty && requestNote.trim().isEmpty) {
          v2Toast(context, lang == 'ar' ? 'أدخلي رابطاً أو ملاحظة' : 'Enter a URL or request note', error: true);
          return false;
        }
        return true;
      },
    );
    if (!ok) return;
    try {
      if (url.trim().isNotEmpty) {
        final updated = [...currentPortfolio, url.trim()];
        await staffClient.patch('/admin/providers/${widget.providerId}', data: {
          'portfolio': updated,
        });
      }
      if (requestNote.trim().isNotEmpty) {
        await staffClient.patch('/admin/providers/${widget.providerId}/notes', data: {
          'note': lang == 'ar'
              ? 'طلب صور للمعرض: ${requestNote.trim()}'
              : 'Portfolio photo request: ${requestNote.trim()}',
        });
      }
      if (mounted) {
        v2Toast(context, lang == 'ar' ? 'تم تحديث المعرض' : 'Portfolio updated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Future<void> _updatePayoutMethod(Map<String, dynamic> payoutData) async {
    try {
      await staffClient.patch('/admin/providers/${widget.providerId}', data: payoutData);
      if (mounted) {
        v2Toast(context, 'Payout method updated');
        _loadProvider();
      }
    } on ApiException catch (e) {
      if (mounted) v2Toast(context, e.message, error: true);
    }
  }

  Widget _buildMoneyTab(Map<String, dynamic> provider, String lang, StaffState staffState) {
    final payoutMethod = '${provider['payoutMethod'] ?? ''}';
    final payoutHandle = '${provider['payoutHandle'] ?? ''}';
    final earnings = asMap(provider['earnings']);
    final jobs = asMap(provider['jobs']);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Payout method
          V2Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      lang == 'ar' ? 'طريقة الدفع' : 'Payout Method',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (staffCan(staffState.effectiveRole, 'providers.vet'))
                      ElevatedButton.icon(
                        onPressed: () => _editPayoutMethod(payoutMethod, payoutHandle, lang),
                        icon: const Icon(Icons.edit, size: 16),
                        label: Text(lang == 'ar' ? 'تحرير' : 'Edit'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                
                if (payoutMethod.isEmpty)
                  Text(
                    lang == 'ar' ? 'لم يتم تحديد طريقة دفع' : 'No payout method set',
                    style: const TextStyle(color: Ops.muted),
                  )
                else ...[
                  Text(
                    '${lang == 'ar' ? 'الطريقة:' : 'Method:'} $payoutMethod',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (payoutHandle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${lang == 'ar' ? 'التفاصيل:' : 'Handle:'} $payoutHandle',
                      style: const TextStyle(fontFamily: Ops.mono, color: Ops.muted),
                    ),
                  ],
                ],
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Earnings summary
          if (earnings != null)
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'ar' ? 'ملخص الأرباح' : 'Earnings Summary',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      if (earnings['total'] != null)
                        _buildEarningStat(
                          lang == 'ar' ? 'إجمالي الأرباح' : 'Total Earnings',
                          money(asInt(earnings['total']), lang),
                        ),
                      if (earnings['pending'] != null)
                        _buildEarningStat(
                          lang == 'ar' ? 'في الانتظار' : 'Pending',
                          money(asInt(earnings['pending']), lang),
                        ),
                      if (earnings['paid'] != null)
                        _buildEarningStat(
                          lang == 'ar' ? 'تم الدفع' : 'Paid Out',
                          money(asInt(earnings['paid']), lang),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          
          if (jobs != null) ...[
            const SizedBox(height: 16),
            
            // Jobs summary
            V2Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'ar' ? 'ملخص الوظائف' : 'Jobs Summary',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  
                  Wrap(
                    spacing: 24,
                    runSpacing: 12,
                    children: [
                      if (jobs['total'] != null)
                        _buildEarningStat(
                          lang == 'ar' ? 'إجمالي الوظائف' : 'Total Jobs',
                          '${jobs['total']}',
                        ),
                      if (jobs['completed'] != null)
                        _buildEarningStat(
                          lang == 'ar' ? 'مكتملة' : 'Completed',
                          '${jobs['completed']}',
                        ),
                      if (jobs['cancelled'] != null)
                        _buildEarningStat(
                          lang == 'ar' ? 'ملغاة' : 'Cancelled',
                          '${jobs['cancelled']}',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          
          // Release payout action (if available)
          // This would require checking if there's a release endpoint
          // For now, we just show the summary
        ],
      ),
    );
  }

  Widget _buildEarningStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Ops.muted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: Ops.mono,
          ),
        ),
      ],
    );
  }

  Future<void> _editPayoutMethod(String currentMethod, String currentHandle, String lang) async {
    String method = currentMethod;
    String handle = currentHandle;
    
    final confirmed = await v2Form(
      context,
      title: lang == 'ar' ? 'تحرير طريقة الدفع' : 'Edit Payout Method',
      confirmLabel: lang == 'ar' ? 'حفظ' : 'Save',
      bodyBuilder: (ctx, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            V2FormField(
              label: lang == 'ar' ? 'طريقة الدفع' : 'Payout Method',
              child: DropdownButtonFormField<String>(
                value: method.isEmpty ? null : method,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'bank', child: Text(lang == 'ar' ? 'تحويل بنكي' : 'Bank Transfer')),
                  DropdownMenuItem(value: 'vodafone_cash', child: Text(lang == 'ar' ? 'فودافون كاش' : 'Vodafone Cash')),
                  DropdownMenuItem(value: 'orange_cash', child: Text(lang == 'ar' ? 'أورانج كاش' : 'Orange Cash')),
                  DropdownMenuItem(value: 'etisalat_cash', child: Text(lang == 'ar' ? 'اتصالات كاش' : 'Etisalat Cash')),
                ],
                onChanged: (value) => method = value ?? '',
              ),
            ),
            const SizedBox(height: 16),
            V2FormField(
              label: lang == 'ar' ? 'رقم الحساب/الهاتف' : 'Account/Phone Number',
              child: TextField(
                controller: TextEditingController(text: handle),
                decoration: const InputDecoration(border: OutlineInputBorder()),
                onChanged: (value) => handle = value,
              ),
            ),
          ],
        );
      },
    );
    
    if (confirmed) {
      _updatePayoutMethod({
        'payoutMethod': method,
        'payoutHandle': handle,
      });
    }
  }
}