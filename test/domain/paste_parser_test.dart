import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/domain/services/paste_parser.dart';

void main() {
  group('PasteParser Tests', () {
    test('Parses slash notation "BENCH PRESS: 7.5/15, 10/13, 10/15"', () {
      const input = 'BENCH PRESS: 7.5/15, 10/13, 10/15';
      final results = PasteParser.parse(input);

      expect(results.length, 1);
      expect(results[0].exerciseName, 'BENCH PRESS');
      expect(results[0].sets.length, 3);
      expect(results[0].sets[0].weight, 7.5);
      expect(results[0].sets[0].reps, 15);
      expect(results[0].sets[1].weight, 10.0);
      expect(results[0].sets[1].reps, 13);
      expect(results[0].sets[2].weight, 10.0);
      expect(results[0].sets[2].reps, 15);
    });

    test('Parses cross notation "Squats: 100x5, 105x5, 110x5"', () {
      const input = 'Squats: 100x5, 105x5, 110x5';
      final results = PasteParser.parse(input);

      expect(results.length, 1);
      expect(results[0].exerciseName, 'Squats');
      expect(results[0].sets.length, 3);
      expect(results[0].sets[0].weight, 100.0);
      expect(results[0].sets[0].reps, 5);
      expect(results[0].sets[1].weight, 105.0);
      expect(results[0].sets[2].weight, 110.0);
    });

    test('Parses units and spaces "Incline DB Press: 32kg x 8, 32kg x 8, 30kg x 10"', () {
      const input = 'Incline DB Press: 32kg x 8, 32kg x 8, 30kg x 10';
      final results = PasteParser.parse(input);

      expect(results.length, 1);
      expect(results[0].exerciseName, 'Incline DB Press');
      expect(results[0].sets.length, 3);
      expect(results[0].sets[0].weight, 32.0);
      expect(results[0].sets[0].reps, 8);
      expect(results[0].sets[2].weight, 30.0);
      expect(results[0].sets[2].reps, 10);
    });

    test('Parses dash separated line "Deadlift - 140 / 5, 150 / 3"', () {
      const input = 'Deadlift - 140 / 5, 150 / 3';
      final results = PasteParser.parse(input);

      expect(results.length, 1);
      expect(results[0].exerciseName, 'Deadlift');
      expect(results[0].sets.length, 2);
      expect(results[0].sets[0].weight, 140.0);
      expect(results[0].sets[0].reps, 5);
      expect(results[0].sets[1].weight, 150.0);
      expect(results[0].sets[1].reps, 3);
    });

    test('Parses multi-line log with numbered bullets', () {
      const input = '''
1. Flat Bench: 80x8, 80x8, 82.5x6
2. Overhead Press: 45 / 8, 45 / 8
* Tricep Pushdown: 25kg x 12, 30kg x 10
''';
      final results = PasteParser.parse(input);

      expect(results.length, 3);
      expect(results[0].exerciseName, 'Flat Bench');
      expect(results[0].sets.length, 3);
      expect(results[1].exerciseName, 'Overhead Press');
      expect(results[1].sets.length, 2);
      expect(results[2].exerciseName, 'Tricep Pushdown');
      expect(results[2].sets.length, 2);
    });

    test('Handles bodyweight sets "Pull-ups: BW x 10, BW x 8"', () {
      const input = 'Pull-ups: BW x 10, BW x 8';
      final results = PasteParser.parse(input);

      expect(results.length, 1);
      expect(results[0].exerciseName, 'Pull-ups');
      expect(results[0].sets[0].weight, 0.0);
      expect(results[0].sets[0].reps, 10);
      expect(results[0].sets[1].weight, 0.0);
      expect(results[0].sets[1].reps, 8);
    });
  });
}
