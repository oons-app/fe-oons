import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:oons/features/pro/v2/autosave.dart';

void main() {
  group('AutosaveQueue', () {
    late AutosaveQueue q;
    late List<String> toasts;
    setUp(() {
      q = AutosaveQueue();
      toasts = [];
    });
    void toast(String m, {bool error = false}) => toasts.add(error ? 'ERR:$m' : m);

    test('applies at once, sends, then says «اتحفظ»', () async {
      var on = false;
      final f = q.run('k',
          apply: () => on = true,
          rollback: () => on = false,
          request: () async {},
          toast: toast,
          savedMessage: 'اتحفظ',
          errorMessage: (e) => 'bad');
      expect(on, isTrue, reason: 'optimistic: visible before the server answers');
      expect(await f, isTrue);
      expect(on, isTrue);
      expect(toasts, ['اتحفظ']);
    });

    test('a refused change is rolled back and explained', () async {
      var on = false;
      final ok = await q.run('k',
          apply: () => on = true,
          rollback: () => on = false,
          request: () async => throw StateError('nope'),
          toast: toast,
          savedMessage: 'اتحفظ',
          errorMessage: (e) => 'مقدرناش نحفظ');
      expect(ok, isFalse);
      expect(on, isFalse, reason: 'rolled back');
      expect(toasts, ['ERR:مقدرناش نحفظ']);
    });

    test('same key: requests run in order and build their payload when they run', () async {
      final areas = <String>{};
      final sent = <List<String>>[];
      final gate = Completer<void>();
      final f1 = q.run('areas',
          apply: () => areas.add('a'),
          rollback: () => areas.remove('a'),
          request: () async {
            sent.add(areas.toList()..sort());
            await gate.future; // the server is slow on the first one
          },
          toast: toast,
          savedMessage: 's',
          errorMessage: (e) => 'e');
      final f2 = q.run('areas',
          apply: () => areas.add('b'),
          rollback: () => areas.remove('b'),
          request: () async => sent.add(areas.toList()..sort()),
          toast: toast,
          savedMessage: 's',
          errorMessage: (e) => 'e');
      await Future<void>.delayed(Duration.zero);
      expect(sent, [
        ['a', 'b']
      ], reason: 'the second request has not started: the first is still in flight');
      gate.complete();
      await Future.wait([f1, f2]);
      expect(sent.last, ['a', 'b'], reason: 'the last write carries both toggles');
      expect(sent.length, 2);
    });

    test('different keys do not wait for each other', () async {
      final gate = Completer<void>();
      var second = false;
      final f1 = q.run('x', apply: () {}, rollback: () {}, request: () => gate.future, toast: toast, savedMessage: 's', errorMessage: (e) => 'e');
      final f2 = q.run('y', apply: () {}, rollback: () {}, request: () async => second = true, toast: toast, savedMessage: 's', errorMessage: (e) => 'e');
      await f2;
      expect(second, isTrue);
      gate.complete();
      await f1;
    });

    test('one failure does not block the next change', () async {
      var n = 0;
      await q.run('k', apply: () {}, rollback: () {}, request: () async => throw StateError('x'), toast: toast, savedMessage: 's', errorMessage: (e) => 'e');
      expect(await q.run('k', apply: () {}, rollback: () {}, request: () async => n++, toast: toast, savedMessage: 's', errorMessage: (e) => 'e'), isTrue);
      expect(n, 1);
    });
  });
}
