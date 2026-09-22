import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/core/utils/fuzzy_matcher.dart';

void main() {
  group('FuzzyMatcher Tests', () {
    test('Exact match has highest score', () {
      final score = FuzzyMatcher.score('Bench Press', 'Bench Press');
      expect(score, 1.0);
    });

    test('Case insensitive matching', () {
      final score = FuzzyMatcher.score('bench press', 'BENCH PRESS');
      expect(score, 1.0);
    });

    test('Tolerates typos via Levenshtein distance', () {
      final score = FuzzyMatcher.score('Bench Pres', 'Bench Press');
      expect(score, greaterThan(0.7));
    });

    test('Searches list of exercise names and ranks accurately', () {
      final catalog = [
        'Barbell Bench Press',
        'Incline Dumbbell Press',
        'Overhead Press',
        'Barbell Back Squat',
        'Romanian Deadlift',
      ];

      final results = FuzzyMatcher.search<String>(
        query: 'bench',
        items: catalog,
        textExtractor: (s) => s,
      );

      expect(results.isNotEmpty, true);
      expect(results.first.item, 'Barbell Bench Press');
    });

    test('Best match returns correct item', () {
      final catalog = [
        'Lat Pulldown',
        'Seated Cable Row',
        'Close-Grip Lat Pulldown',
      ];

      final best = FuzzyMatcher.bestMatch<String>(
        query: 'pulldown',
        items: catalog,
        textExtractor: (s) => s,
      );

      expect(best, isNotNull);
      expect(best!.item.contains('Pulldown'), true);
    });
  });
}
