import 'dart:math' as math;

class FuzzyMatchResult<T> {
  final T item;
  final double score; // 0.0 to 1.0
  final String matchedText;

  FuzzyMatchResult({
    required this.item,
    required this.score,
    required this.matchedText,
  });
}

class FuzzyMatcher {
  FuzzyMatcher._();

  /// Calculates Levenshtein distance between two strings
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = s1.codeUnitAt(i) == s2.codeUnitAt(j) ? 0 : 1;
        v1[j + 1] = math.min(
          v1[j] + 1, // insertion
          math.min(
            v0[j + 1] + 1, // deletion
            v0[j] + cost, // substitution
          ),
        );
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  /// Calculates similarity score between query and target (0.0 to 1.0)
  static double score(String query, String target) {
    final q = query.trim().toLowerCase();
    final t = target.trim().toLowerCase();

    if (q.isEmpty || t.isEmpty) return 0.0;
    if (q == t) return 1.0;

    // Exact prefix match
    if (t.startsWith(q)) {
      return 0.95 + (0.05 * (q.length / t.length));
    }

    // Exact contains
    if (t.contains(q)) {
      return 0.85 + (0.10 * (q.length / t.length));
    }

    // Token match (e.g. "bench press" in "Flat Barbell Bench Press")
    final qTokens = q.split(RegExp(r'\s+'));
    final tTokens = t.split(RegExp(r'\s+'));
    int matchedTokens = 0;
    for (final qToken in qTokens) {
      if (tTokens.any((tToken) => tToken.contains(qToken) || qToken.contains(tToken))) {
        matchedTokens++;
      }
    }

    if (matchedTokens == qTokens.length && qTokens.isNotEmpty) {
      return 0.80;
    }

    // Levenshtein similarity
    final maxLen = math.max(q.length, t.length);
    final distance = levenshteinDistance(q, t);
    final levSimilarity = 1.0 - (distance / maxLen);

    if (levSimilarity > 0.65) {
      return levSimilarity * 0.75;
    }

    return 0.0;
  }

  /// Finds and ranks items by fuzzy score against query
  static List<FuzzyMatchResult<T>> search<T>({
    required String query,
    required List<T> items,
    required String Function(T item) textExtractor,
    double threshold = 0.35,
  }) {
    if (query.trim().isEmpty) {
      return items
          .map((item) => FuzzyMatchResult(
                item: item,
                score: 1.0,
                matchedText: textExtractor(item),
              ))
          .toList();
    }

    final results = <FuzzyMatchResult<T>>[];
    for (final item in items) {
      final text = textExtractor(item);
      final s = score(query, text);
      if (s >= threshold) {
        results.add(FuzzyMatchResult(item: item, score: s, matchedText: text));
      }
    }

    results.sort((a, b) => b.score.compareTo(a.score));
    return results;
  }

  /// Finds best matching item or null
  static FuzzyMatchResult<T>? bestMatch<T>({
    required String query,
    required List<T> items,
    required String Function(T item) textExtractor,
    double threshold = 0.40,
  }) {
    final results = search(
      query: query,
      items: items,
      textExtractor: textExtractor,
      threshold: threshold,
    );
    if (results.isEmpty) return null;
    return results.first;
  }
}
