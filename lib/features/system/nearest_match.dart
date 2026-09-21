/// Picks the closest REAL name to what the user typed, or null when nothing is
/// genuinely close. Never invents a suggestion: below [threshold] it stays silent.
String _norm(String s) {
  var t = s.trim().toLowerCase();
  t = t.replaceAll(RegExp('[ً-ٰٟـ]'), '');
  t = t
      .replaceAll(RegExp('[أإآ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي');
  return t.replaceAll(RegExp(r'\s+'), ' ');
}

int _lev(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      cur[j] = [cur[j - 1] + 1, prev[j] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
    }
    prev = cur;
  }
  return prev[b.length];
}

double similarity(String query, String name) {
  final q = _norm(query), n = _norm(name);
  if (q.isEmpty || n.isEmpty) return 0;
  if (n.contains(q) || q.contains(n)) return 0.9;
  final qt = q.split(' ').toSet(), nt = n.split(' ').toSet();
  final shared = qt.intersection(nt).length;
  final jaccard = shared / (qt.union(nt).length);
  // Token-level fuzzy: the best single-token edit similarity (one close word is enough).
  var fuzzy = 0.0;
  for (final a in qt) {
    var best = 0.0;
    for (final b in nt) {
      final s = 1 - _lev(a, b) / (a.length > b.length ? a.length : b.length);
      if (s > best) best = s;
    }
    if (best > fuzzy) fuzzy = best;
  }
  final whole = 1 - _lev(q, n) / (q.length > n.length ? q.length : n.length);
  return [jaccard, fuzzy * 0.85, whole].reduce((x, y) => x > y ? x : y);
}

T? nearestByName<T>(String query, Iterable<T> items, String Function(T) nameOf, {double threshold = 0.5}) {
  T? best;
  var bestScore = 0.0;
  for (final it in items) {
    final s = similarity(query, nameOf(it));
    if (s > bestScore) {
      bestScore = s;
      best = it;
    }
  }
  return bestScore >= threshold ? best : null;
}
