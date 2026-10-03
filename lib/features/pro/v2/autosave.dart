import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:oons/core/locale.dart';
import 'package:oons/data/models.dart';
import 'package:oons/data/repo.dart';
import 'package:oons/ds/ds.dart';
import 'package:oons/l10n/errors.dart';

typedef ToastFn = void Function(String message, {bool error});

/// Small changes (a toggle, a chip, a switch) save themselves:
///
///   apply now → send just that change → toast «اتحفظ»
///   server says no → put it back → error toast
///
/// Requests for the *same key* (e.g. "areas") run one after another, and each one
/// builds its payload when it actually runs, so a quick second tap can never be
/// overwritten by the response to the first.
class AutosaveQueue {
  final _tails = <String, Future<void>>{};

  /// Returns true when the server accepted the change.
  Future<bool> run(
    String key, {
    required void Function() apply,
    required void Function() rollback,
    required Future<void> Function() request,
    required ToastFn toast,
    required String savedMessage,
    required String Function(Object error) errorMessage,
  }) {
    apply();
    final done = Completer<bool>();
    final prev = _tails[key] ?? Future<void>.value();
    final next = prev.then((_) async {
      try {
        await request();
        toast(savedMessage, error: false);
        done.complete(true);
      } catch (e) {
        rollback();
        toast(errorMessage(e), error: true);
        done.complete(false);
      }
    });
    _tails[key] = next;
    return done.future;
  }
}

/// App-wide queue: one per process is enough, keys keep the fields apart.
final autosaveQueueProvider = Provider<AutosaveQueue>((ref) => AutosaveQueue());

/// Wires [AutosaveQueue] to the real toast, the app language and the session:
/// a `{provider: …}` answer is folded back into the signed-in provider.
class ProAutosave {
  ProAutosave(this.context, this.ref);
  final BuildContext context;
  final WidgetRef ref;

  bool get _ar => langOf(ref) == 'ar';

  /// PATCH /pro/me with just [fields]. The caller has already applied the
  /// change locally via [apply]; [rollback] undoes it.
  Future<bool> patchMe(
    String key,
    Map<String, dynamic> Function() fields, {
    required void Function() apply,
    required void Function() rollback,
    String? savedMessage,
  }) {
    return ref.read(autosaveQueueProvider).run(
      key,
      apply: apply,
      rollback: rollback,
      request: () async {
        final r = await ref.read(repoProvider).patchPro(fields());
        absorb(r);
      },
      toast: (m, {bool error = false}) {
        if (context.mounted) DsToast.show(context, m, error: error);
      },
      savedMessage: savedMessage ?? (_ar ? 'اتحفظ' : 'Saved'),
      errorMessage: (e) => friendlyError(e, langOf(ref)),
    );
  }

  /// Generic: any request returning the usual envelope.
  Future<bool> request(
    String key,
    Future<Map<String, dynamic>> Function() send, {
    required void Function() apply,
    required void Function() rollback,
    String? savedMessage,
  }) {
    return ref.read(autosaveQueueProvider).run(
      key,
      apply: apply,
      rollback: rollback,
      request: () async => absorb(await send()),
      toast: (m, {bool error = false}) {
        if (context.mounted) DsToast.show(context, m, error: error);
      },
      savedMessage: savedMessage ?? (_ar ? 'اتحفظ' : 'Saved'),
      errorMessage: (e) => friendlyError(e, langOf(ref)),
    );
  }

  void absorb(Map<String, dynamic> r) {
    if (r['provider'] is Map) {
      ref.read(sessionProvider.notifier).setProvider(ProviderP.fromJson(r['provider'] as Map));
    }
  }
}
