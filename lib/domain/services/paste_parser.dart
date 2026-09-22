class ParsedSetEntry {
  final double weight;
  final int reps;
  final String rawText;

  ParsedSetEntry({
    required this.weight,
    required this.reps,
    required this.rawText,
  });

  @override
  String toString() => '$weight x $reps';
}

class ParsedExerciseBlock {
  final String exerciseName;
  final List<ParsedSetEntry> sets;
  final String rawLine;

  ParsedExerciseBlock({
    required this.exerciseName,
    required this.sets,
    required this.rawLine,
  });
}

class PasteParser {
  PasteParser._();

  /// Parses a multi-line text input into exercise blocks with sets.
  /// Example inputs:
  /// "BENCH PRESS: 7.5/15, 10/13, 10/15"
  /// "Squats: 100x5, 105x5, 110x5"
  /// "Incline DB Press: 32kg x 8, 32kg x 8, 30kg x 10"
  /// "Deadlift - 140/5, 150/3"
  static List<ParsedExerciseBlock> parse(String text) {
    if (text.trim().isEmpty) return [];

    final lines = text.split(RegExp(r'\r?\n'));
    final results = <ParsedExerciseBlock>[];

    for (final line in lines) {
      final trimmedLine = line.trim();
      if (trimmedLine.isEmpty) continue;

      final block = _parseLine(trimmedLine);
      if (block != null && block.sets.isNotEmpty) {
        results.add(block);
      }
    }

    return results;
  }

  static ParsedExerciseBlock? _parseLine(String line) {
    // Clean leading bullets or numbering e.g. "1. ", "- ", "* "
    String cleaned = line.replaceFirst(RegExp(r'^\s*(\d+[\.\)]\s*|[-*•]\s*)'), '');

    String exerciseName = '';
    String setsPart = '';

    // Look for ':' or ' - ' or ';' separating exercise name from sets
    if (cleaned.contains(':')) {
      final idx = cleaned.indexOf(':');
      exerciseName = cleaned.substring(0, idx).trim();
      setsPart = cleaned.substring(idx + 1).trim();
    } else if (cleaned.contains(' - ')) {
      final idx = cleaned.indexOf(' - ');
      exerciseName = cleaned.substring(0, idx).trim();
      setsPart = cleaned.substring(idx + 3).trim();
    } else {
      // Try to find the first occurrence of digit followed by 'x', '/', '@', or unit
      final match = RegExp(r'(\d+(?:\.\d+)?\s*(?:kg|lbs?|x|X|\/|@))').firstMatch(cleaned);
      if (match != null && match.start > 0) {
        exerciseName = cleaned.substring(0, match.start).trim();
        setsPart = cleaned.substring(match.start).trim();
      } else {
        return null;
      }
    }

    if (exerciseName.isEmpty || setsPart.isEmpty) return null;

    final sets = _parseSets(setsPart);
    if (sets.isEmpty) return null;

    return ParsedExerciseBlock(
      exerciseName: exerciseName,
      sets: sets,
      rawLine: line,
    );
  }

  static List<ParsedSetEntry> _parseSets(String setsText) {
    final sets = <ParsedSetEntry>[];

    // Pattern matching weight and reps:
    // e.g. "7.5/15", "100x5", "32 kg x 8", "140 / 5", "100 @ 5"
    // Also handles "+5kg x 8" or "BW x 12" (BW = 0 weight)
    final setRegex = RegExp(
      r'([+]?\d+(?:\.\d+)?|bw|bodyweight)\s*(?:kg|lbs?)?\s*(?:x|X|\/|@|\*)\s*(\d+)',
      caseSensitive: false,
    );

    final matches = setRegex.allMatches(setsText);
    for (final match in matches) {
      final rawWeight = match.group(1)!.toLowerCase();
      final reps = int.tryParse(match.group(2)!) ?? 0;

      double weight = 0.0;
      if (rawWeight == 'bw' || rawWeight == 'bodyweight') {
        weight = 0.0;
      } else {
        final cleanWeight = rawWeight.replaceAll('+', '').trim();
        weight = double.tryParse(cleanWeight) ?? 0.0;
      }

      if (reps > 0) {
        sets.add(ParsedSetEntry(
          weight: weight,
          reps: reps,
          rawText: match.group(0)!,
        ));
      }
    }

    return sets;
  }
}
