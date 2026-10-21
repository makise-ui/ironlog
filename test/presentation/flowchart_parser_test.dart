import 'package:flutter_test/flutter_test.dart';
import 'package:ironlog/features/today/presentation/widgets/ai_assistant_sheet.dart';

void main() {
  group('MermaidFlowchartParser Tests', () {
    test('parses linear graph TD correctly', () {
      const code = '''
graph TD
  A[Dynamic Warm-up] --> B[Barbell Squats 4x6]
  B --> C[Leg Press 3x10]
''';
      final graph = MermaidFlowchartParser.parse(code);
      expect(graph.direction, equals('TD'));
      expect(graph.nodes.length, equals(3));
      expect(graph.edges.length, equals(2));
      expect(graph.nodes[0].label, equals('Dynamic Warm-up'));
      expect(graph.nodes[0].phase, equals('Warm-up'));
      expect(graph.nodes[1].phase, equals('Compound'));
    });

    test('parses decision nodes and branching edges with labels', () {
      const code = '''
flowchart TD
  Start[Begin Session] --> Bench[Bench Press 3x5]
  Bench --> Dec{Can hit 5 reps @ RPE 8?}
  Dec -->|Yes| Overload[Add 2.5kg Next Week]
  Dec -->|No| Deload[Deload 10% Protocol]
  Overload --> Accessory[Incline DB & Flyes]
  Deload --> Accessory
''';
      final graph = MermaidFlowchartParser.parse(code);
      expect(graph.nodes.any((n) => n.id == 'Dec' && n.isDecision), isTrue);

      final yesEdge = graph.edges.firstWhere((e) => e.from == 'Dec' && e.to == 'Overload');
      expect(yesEdge.label, equals('Yes'));

      final noEdge = graph.edges.firstWhere((e) => e.from == 'Dec' && e.to == 'Deload');
      expect(noEdge.label, equals('No'));

      // Layer computation
      final layers = MermaidFlowchartParser.computeLayers(graph.nodes, graph.edges);
      expect(layers.length, greaterThanOrEqualTo(5));

      // Overload and Deload should be at the same layer (branching)
      final overloadLayer = layers.indexWhere((l) => l.any((n) => n.id == 'Overload'));
      final deloadLayer = layers.indexWhere((l) => l.any((n) => n.id == 'Deload'));
      expect(overloadLayer, equals(deloadLayer));

      // The layer containing Overload and Deload should have at least 2 nodes
      expect(layers[overloadLayer].length, greaterThanOrEqualTo(2));
    });

    test('parses multi-branch splits with & syntax', () {
      const code = '''
graph TD
  Split[3-Day Split] --> Push[Day 1: Push] & Pull[Day 2: Pull] & Legs[Day 3: Legs]
  Push & Pull & Legs --> Rest[Rest Day]
''';
      final graph = MermaidFlowchartParser.parse(code);
      expect(graph.nodes.length, equals(5));
      // 3 edges from Split, 3 edges to Rest = 6 edges
      expect(graph.edges.length, equals(6));

      final layers = MermaidFlowchartParser.computeLayers(graph.nodes, graph.edges);
      expect(layers.length, equals(3));
      expect(layers[0].map((n) => n.id), contains('Split'));
      expect(layers[1].length, equals(3)); // Push, Pull, Legs in parallel
      expect(layers[2].map((n) => n.id), contains('Rest'));
    });
  });
}
