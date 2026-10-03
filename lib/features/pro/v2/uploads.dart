import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:oons/core/analytics.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/l10n/errors.dart';

enum ProUpload { face, id, fish, portfolio }

/// Picks a photo and uploads it. [onProgress] gets 0..1 while it uploads and
/// `null` when it is over; the provider on the answer is folded back into the
/// session. A failure shows the server's reason in an error toast.
typedef ProgressFn = void Function(double? fraction);

Future<bool> proUpload(
  BuildContext context,
  WidgetRef ref,
  ProUpload kind, {
  ProgressFn? onProgress,
  Future<XFile?> Function()? pick,
}) async {
  final lang = langOf(ref);
  final ar = lang == 'ar';
  final file = await (pick ?? () => ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85))();
  if (file == null) return false;
  final bytes = await file.readAsBytes();
  onProgress?.call(0);
  final repo = ref.read(repoProvider);
  void p(double f) => onProgress?.call(f);
  try {
    final r = switch (kind) {
      ProUpload.id => await repo.uploadProID(bytes, filename: file.name, onProgress: p),
      ProUpload.fish => await repo.uploadProFish(bytes, filename: file.name, onProgress: p),
      ProUpload.face => await repo.uploadProPhoto(bytes, filename: file.name, onProgress: p),
      ProUpload.portfolio => await repo.uploadProPortfolio(bytes, filename: file.name, onProgress: p),
    };
    if (r['provider'] is Map) {
      ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
    }
    await ref.read(sessionProvider.notifier).refreshMe();
    if (kind == ProUpload.portfolio) unawaited(AppAnalytics.providerPortfolioUploaded());
    if (context.mounted) DsToast.show(context, ar ? 'اتحفظ' : 'Saved');
    return true;
  } catch (e) {
    if (context.mounted) DsToast.show(context, friendlyError(e, lang), error: true);
    return false;
  } finally {
    onProgress?.call(null);
  }
}
