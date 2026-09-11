import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/core/tokens.dart';
import 'package:oons/data/api.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/features/pro/pro_chrome.dart';
import 'package:oons/l10n/errors.dart';

/// "الفريق" — a provider's own roster of named team members (workers), each
/// vetted (ID + criminal record, staff-reviewed) before they can be assigned
/// to a confirmed booking. Mirrors the provider's own KYC flow, scoped per
/// worker.
class ProTeamScreen extends ConsumerStatefulWidget {
  const ProTeamScreen({super.key});

  @override
  ConsumerState<ProTeamScreen> createState() => _ProTeamScreenState();
}

class _ProTeamScreenState extends ConsumerState<ProTeamScreen> {
  List<Map<String, dynamic>> workers = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final rows = await ref.read(repoProvider).proWorkers();
      if (mounted) setState(() { workers = rows; loading = false; });
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? existing}) async {
    final lang = langOf(ref);
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Pro.bg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) => _WorkerEditorSheet(lang: lang, existing: existing, repo: ref.read(repoProvider)),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final lang = langOf(ref);
    final ar = lang == 'ar';
    return Scaffold(
      backgroundColor: Pro.bg,
      appBar: AppBar(
        backgroundColor: Pro.bg,
        elevation: 0,
        foregroundColor: Pro.ink,
        title: Text(ar ? 'الفريق' : 'Team'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator(color: Pro.plum))
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Text(
                  ar
                      ? 'ضيفي أعضاء فريقك — الاسم، الرقم، والأوراق. لازم يتوثقوا (البطاقة والفيش) قبل ما تقدري تكلّفيهم بأي حجز.'
                      : 'Add your team members — name, phone, and documents. Each one must be vetted (ID + criminal record) before you can assign them to a booking.',
                  style: const TextStyle(fontSize: 13, color: Pro.muted, height: 1.45),
                ),
                const SizedBox(height: 16),
                if (workers.isEmpty)
                  ProCard(
                    child: Text(
                      ar ? 'مفيش حد في الفريق لسه.' : 'No team members yet.',
                      style: const TextStyle(fontSize: 14, color: Pro.muted),
                    ),
                  )
                else
                  ...workers.map((w) => _workerCard(lang, w)),
                const SizedBox(height: 14),
                ProSoftButton(label: ar ? '+ ضيفي عضو فريق' : '+ Add team member', onTap: () => _openEditor()),
              ],
            ),
    );
  }

  Widget _workerCard(String lang, Map<String, dynamic> w) {
    final ar = lang == 'ar';
    final name = '${w['firstName'] ?? ''} ${w['lastName'] ?? ''}'.trim();
    final vetted = w['vetted'] == true;
    final active = w['active'] == true;
    final idStatus = '${w['idDocStatus'] ?? 'unknown'}';
    final fishStatus = '${w['fishDocStatus'] ?? 'unknown'}';
    String status;
    var soft = true;
    var hot = false;
    if (!active) {
      status = ar ? 'متوقّف' : 'Paused';
    } else if (vetted) {
      status = ar ? 'موثّق' : 'Vetted';
      hot = true;
      soft = false;
    } else if (idStatus == 'rejected' || fishStatus == 'rejected') {
      status = ar ? 'محتاج تعديل' : 'Needs changes';
    } else {
      status = ar ? 'قيد المراجعة' : 'Under review';
    }
    final note = '${w['idDocNote'] ?? ''}'.isNotEmpty
        ? '${w['idDocNote']}'
        : ('${w['fishDocNote'] ?? ''}'.isNotEmpty ? '${w['fishDocNote']}' : null);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openEditor(existing: w),
        borderRadius: BorderRadius.circular(Pro.rCard),
        child: ProCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      name.isEmpty ? (ar ? 'بدون اسم' : 'Unnamed') : name,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Pro.ink),
                    ),
                  ),
                  ProPill(status, soft: soft, hot: hot),
                ],
              ),
              if ('${w['phone'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('${w['phone']}', style: const TextStyle(fontFamily: T.mono, fontSize: 12, color: Pro.muted)),
              ],
              if (note != null) ...[
                const SizedBox(height: 6),
                Text(note, style: const TextStyle(fontSize: 12, color: Pro.danger)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkerEditorSheet extends StatefulWidget {
  const _WorkerEditorSheet({required this.lang, required this.existing, required this.repo});
  final String lang;
  final Map<String, dynamic>? existing;
  final Repo repo;

  @override
  State<_WorkerEditorSheet> createState() => _WorkerEditorSheetState();
}

class _WorkerEditorSheetState extends State<_WorkerEditorSheet> {
  late final firstName = TextEditingController(text: '${widget.existing?['firstName'] ?? ''}');
  late final lastName = TextEditingController(text: '${widget.existing?['lastName'] ?? ''}');
  late final phone = TextEditingController(text: '${widget.existing?['phone'] ?? ''}');
  late final address = TextEditingController(text: '${widget.existing?['address'] ?? ''}');
  final nationalId = TextEditingController();
  bool active = true;
  bool busy = false;
  bool changed = false;
  double? uploadProgress;
  String? uploadLabel;
  String? workerId;
  Map<String, dynamic>? current;

  bool get ar => widget.lang == 'ar';
  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    current = widget.existing;
    workerId = widget.existing?['id'] as String?;
    active = widget.existing?['active'] != false;
  }

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    address.dispose();
    nationalId.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final fn = firstName.text.trim();
    if (fn.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? "محتاجة اسم العضو." : "Need the member's name.")),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final body = {
        'firstName': fn,
        'lastName': lastName.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        if (nationalId.text.trim().isNotEmpty) 'nationalId': nationalId.text.trim(),
        'active': active,
      };
      final r = isEdit ? await widget.repo.proPatchWorker(workerId!, body) : await widget.repo.proCreateWorker(body);
      if (r['worker'] is Map) {
        current = Map<String, dynamic>.from(r['worker'] as Map);
        workerId = '${current!['id']}';
        nationalId.clear();
      }
      changed = true;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'اتحفظ ✓' : 'Saved ✓')));
        setState(() {});
      }
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _pickAndUpload(bool fish) async {
    if (workerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ar ? 'احفظي بيانات العضو الأول.' : "Save the member's details first.")),
      );
      return;
    }
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      uploadProgress = 0;
      uploadLabel = fish ? (ar ? 'جارٍ رفع الفيش…' : 'Uploading criminal record…') : (ar ? 'جارٍ رفع البطاقة…' : 'Uploading ID…');
    });
    try {
      final r = fish
          ? await widget.repo.uploadWorkerFish(workerId!, bytes, filename: file.name, onProgress: (f) {
              if (mounted) setState(() => uploadProgress = f);
            })
          : await widget.repo.uploadWorkerId(workerId!, bytes, filename: file.name, onProgress: (f) {
              if (mounted) setState(() => uploadProgress = f);
            });
      if (r['worker'] is Map) {
        current = Map<String, dynamic>.from(r['worker'] as Map);
      }
      changed = true;
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ar ? 'اترفعت ✓' : 'Uploaded ✓')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e, widget.lang))));
    } finally {
      if (mounted) setState(() { uploadProgress = null; uploadLabel = null; });
    }
  }

  Future<void> _delete() async {
    if (workerId == null) {
      Navigator.pop(context, changed);
      return;
    }
    setState(() => busy = true);
    try {
      await widget.repo.proDeleteWorker(workerId!);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Widget _docStatus(String label, String status, String? note) {
    String text;
    Color color;
    switch (status) {
      case 'accepted':
        text = ar ? 'مقبولة' : 'Accepted';
        color = Pro.plum;
      case 'rejected':
        text = ar ? 'مرفوضة' : 'Rejected';
        color = Pro.danger;
      case 'pending':
        text = ar ? 'قيد المراجعة' : 'Under review';
        color = Pro.pendingInk;
      case 'uploaded':
        text = ar ? 'اترفعت' : 'Uploaded';
        color = Pro.muted;
      default:
        text = ar ? 'لسه ما اترفعتش' : 'Not uploaded yet';
        color = Pro.muted;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $text', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        if (note != null && note.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(note, style: const TextStyle(fontSize: 11, color: Pro.danger)),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Pro.lineSoft, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? (ar ? 'عضو الفريق' : 'Team member') : (ar ? 'ضيفي عضو فريق' : 'Add team member'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Pro.ink),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context, changed), icon: const Icon(Icons.close, color: Pro.muted)),
              ],
            ),
            const SizedBox(height: 14),
            Text(ar ? 'الاسم الأول' : 'First name', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            const SizedBox(height: 6),
            ProField(controller: firstName),
            const SizedBox(height: 12),
            Text(ar ? 'الاسم الأخير' : 'Last name', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            const SizedBox(height: 6),
            ProField(controller: lastName),
            const SizedBox(height: 12),
            Text(ar ? 'رقم الموبايل' : 'Mobile number', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            const SizedBox(height: 6),
            ProField(controller: phone, mono: true, keyboard: TextInputType.phone),
            const SizedBox(height: 12),
            Text(ar ? 'العنوان' : 'Address', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            const SizedBox(height: 6),
            ProField(controller: address),
            const SizedBox(height: 12),
            Text(ar ? 'الرقم القومي (١٤ رقم)' : 'National ID (14 digits)', style: const TextStyle(fontSize: 12, color: Pro.muted)),
            const SizedBox(height: 6),
            ProField(
              controller: nationalId,
              mono: true,
              keyboard: TextInputType.number,
              hint: current?['nationalIdMasked'] != null && '${current!['nationalIdMasked']}'.isNotEmpty
                  ? '${current!['nationalIdMasked']}'
                  : null,
            ),
            const SizedBox(height: 14),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(ar ? 'نشط' : 'Active', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              value: active,
              activeColor: Pro.plum,
              onChanged: (v) => setState(() => active = v),
            ),
            const SizedBox(height: 6),
            ProPrimaryButton(label: ar ? 'احفظي' : 'Save', enabled: !busy, onTap: _save),
            if (isEdit) ...[
              const SizedBox(height: 20),
              const Divider(color: Pro.lineSoft),
              const SizedBox(height: 12),
              Text(ar ? 'الأوراق' : 'Documents', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Pro.ink)),
              const SizedBox(height: 4),
              Text(
                ar
                    ? 'لازم البطاقة والفيش يتقبلوا من فريق أُنس قبل ما تقدري تكلّفي العضو ده بأي حجز.'
                    : 'Both the ID and the criminal record must be accepted by Oons before you can assign this member to a booking.',
                style: const TextStyle(fontSize: 12, color: Pro.muted, height: 1.4),
              ),
              const SizedBox(height: 10),
              _docStatus(ar ? 'البطاقة' : 'ID', '${current?['idDocStatus'] ?? 'unknown'}', current?['idDocNote'] as String?),
              const SizedBox(height: 6),
              ProSoftButton(label: ar ? 'ارفعي صورة البطاقة' : 'Upload ID photo', onTap: () => _pickAndUpload(false)),
              const SizedBox(height: 14),
              _docStatus(ar ? 'الفيش والتشبيه' : 'Criminal record', '${current?['fishDocStatus'] ?? 'unknown'}', current?['fishDocNote'] as String?),
              const SizedBox(height: 6),
              ProSoftButton(label: ar ? 'ارفعي صورة الفيش' : 'Upload criminal record', onTap: () => _pickAndUpload(true)),
              if (uploadProgress != null) ...[
                const SizedBox(height: 12),
                Text(uploadLabel ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Pro.muted)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: uploadProgress!.clamp(0.0, 1.0), minHeight: 6, color: Pro.plum, backgroundColor: Pro.chip),
              ],
              const SizedBox(height: 20),
              ProSoftButton(label: ar ? 'امسحي العضو ده' : 'Remove this member', danger: true, onTap: _delete),
            ],
          ],
        ),
      ),
    );
  }
}
