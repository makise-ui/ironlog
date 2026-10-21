// ── Flowchart & Visual Diagram Engine (Multi-Branching Mermaid Graph) ─────────

class FlowchartNode {
  final String id;
  final String label;
  final String phase;
  final String? description;
  final bool isDecision;
  final String? shape;
  final List<String> next;

  FlowchartNode({
    required this.id,
    required this.label,
    required this.phase,
    this.description,
    this.isDecision = false,
    this.shape,
    this.next = const [],
  });
}

class FlowchartEdge {
  final String from;
  final String to;
  final String? label;

  FlowchartEdge({
    required this.from,
    required this.to,
    this.label,
  });
}

class FlowchartGraph {
  final String title;
  final String direction;
  final List<FlowchartNode> nodes;
  final List<FlowchartEdge> edges;

  FlowchartGraph({
    required this.title,
    this.direction = 'TD',
    required this.nodes,
    required this.edges,
  });
}

class MermaidFlowchartParser {
  static FlowchartGraph parse(
    String code, {
    String defaultTitle = 'Visual Flowchart',
    List<Map<String, dynamic>>? fallbackNodes,
  }) {
    final cleanCode = code
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(r'\n', '\n');

    final lines = cleanCode.split('\n');
    String direction = 'TD';
    final Map<String, FlowchartNode> nodesMap = {};
    final List<FlowchartEdge> edges = [];

    // Parse direction
    final dirMatch = RegExp(r'(?:graph|flowchart)\s+([A-Za-z]{2})', caseSensitive: false).firstMatch(cleanCode);
    if (dirMatch != null) {
      direction = dirMatch.group(1)?.toUpperCase() ?? 'TD';
    }

    void registerNode(String id, String label, {bool isDecision = false, String? shape}) {
      final cleanId = id.trim();
      final cleanLabel = label.trim();
      if (cleanId.isEmpty) return;

      if (!nodesMap.containsKey(cleanId)) {
        final phase = _inferPhase(cleanLabel, isDecision: isDecision);
        nodesMap[cleanId] = FlowchartNode(
          id: cleanId,
          label: cleanLabel.isNotEmpty ? cleanLabel : cleanId,
          phase: phase,
          isDecision: isDecision,
          shape: shape,
        );
      }
    }

    // Node shape regexes
    final pillRegex = RegExp(r'([A-Za-z0-9_]+)\s*\(\[\s*"?([^"\]\)]+)"?\s*\]\)');
    final diamondRegex = RegExp(r'([A-Za-z0-9_]+)\s*\{\s*"?([^"\}]+)"?\s*\}');
    final roundRegex = RegExp(r'([A-Za-z0-9_]+)\s*\(\s*"?([^"\)]+)"?\s*\)');
    final squareRegex = RegExp(r'([A-Za-z0-9_]+)\s*\[\s*"?([^"\]]+)"?\s*\]');

    final edgeLabeled1 = RegExp(r'(.+?)\s*(?:-->|==>|-\.->)\s*\|([^|]+)\|\s*(.+)');
    final edgeLabeled2 = RegExp(r'(.+?)\s*--\s*([^-]+)\s*-->\s*(.+)');
    final edgeSimple = RegExp(r'(.+?)\s*(?:-->|==>|-\.->)\s*(.+)');

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty ||
          trimmed.startsWith('%%') ||
          trimmed.startsWith('graph ') ||
          trimmed.startsWith('flowchart ')) {
        continue;
      }

      // 1. Extract node definitions
      for (final m in pillRegex.allMatches(trimmed)) {
        registerNode(m.group(1)!, m.group(2)!, shape: 'pill');
      }
      for (final m in diamondRegex.allMatches(trimmed)) {
        registerNode(m.group(1)!, m.group(2)!, isDecision: true, shape: 'diamond');
      }
      for (final m in roundRegex.allMatches(trimmed)) {
        if (!m.group(0)!.contains('([')) {
          registerNode(m.group(1)!, m.group(2)!, shape: 'round');
        }
      }
      for (final m in squareRegex.allMatches(trimmed)) {
        registerNode(m.group(1)!, m.group(2)!, shape: 'square');
      }

      // 2. Extract edge connections
      final m1 = edgeLabeled1.allMatches(trimmed);
      final m2 = edgeLabeled2.allMatches(trimmed);
      if (m1.isNotEmpty) {
        for (final m in m1) {
          _addEdges(m.group(1)!, m.group(3)!, m.group(2)?.trim(), edges, registerNode);
        }
      } else if (m2.isNotEmpty) {
        for (final m in m2) {
          _addEdges(m.group(1)!, m.group(3)!, m.group(2)?.trim(), edges, registerNode);
        }
      } else {
        for (final m in edgeSimple.allMatches(trimmed)) {
          _addEdges(m.group(1)!, m.group(2)!, null, edges, registerNode);
        }
      }
    }

    // 3. Fallback nodes from toolcall
    if (fallbackNodes != null && fallbackNodes.isNotEmpty) {
      for (int i = 0; i < fallbackNodes.length; i++) {
        final fn = fallbackNodes[i];
        final id = fn['id']?.toString() ?? '${i + 1}';
        final label = fn['label']?.toString() ?? id;
        final phase = fn['phase']?.toString() ?? _inferPhase(label);
        final desc = fn['description']?.toString();
        final rawNext = fn['next'];
        final nextList = rawNext is List
            ? rawNext.map((e) => e.toString()).toList()
            : (i < fallbackNodes.length - 1 ? ['${i + 2}'] : <String>[]);

        final existing = nodesMap[id];
        final isDec = existing?.isDecision ?? (phase.toLowerCase().contains('decis') || label.contains('?'));

        nodesMap[id] = FlowchartNode(
          id: id,
          label: existing != null && existing.label.isNotEmpty ? existing.label : label,
          phase: phase,
          description: desc,
          isDecision: isDec,
          shape: existing?.shape,
          next: nextList,
        );

        for (final nxt in nextList) {
          if (!edges.any((e) => e.from == id && e.to == nxt)) {
            edges.add(FlowchartEdge(from: id, to: nxt));
          }
        }
      }
    }

    return FlowchartGraph(
      title: defaultTitle,
      direction: direction,
      nodes: nodesMap.values.toList(),
      edges: edges,
    );
  }

  static void _addEdges(
    String fromStr,
    String toStr,
    String? label,
    List<FlowchartEdge> edges,
    void Function(String id, String label, {bool isDecision, String? shape}) registerNode,
  ) {
    final fromIds = _extractIds(fromStr);
    final toIds = _extractIds(toStr);

    for (final f in fromIds) {
      registerNode(f, f);
      for (final t in toIds) {
        registerNode(t, t);
        if (!edges.any((e) => e.from == f && e.to == t)) {
          edges.add(FlowchartEdge(from: f, to: t, label: label));
        }
      }
    }
  }

  static List<String> _extractIds(String str) {
    final tokens = str.split('&');
    final List<String> result = [];
    for (final tok in tokens) {
      final m = RegExp(r'([A-Za-z0-9_]+)').firstMatch(tok.trim());
      if (m != null) {
        result.add(m.group(1)!);
      }
    }
    return result;
  }

  static String _inferPhase(String label, {bool isDecision = false}) {
    if (isDecision) return 'Decision';
    final lower = label.toLowerCase();
    if (lower.contains('?')) return 'Decision';
    if (lower.contains('warm')) return 'Warm-up';
    if (lower.contains('compound') ||
        lower.contains('heavy') ||
        lower.contains('squat') ||
        lower.contains('bench') ||
        lower.contains('deadlift') ||
        lower.contains('press')) {
      return 'Compound';
    }
    if (lower.contains('accessory') ||
        lower.contains('hypertrophy') ||
        lower.contains('curl') ||
        lower.contains('raise') ||
        lower.contains('fly') ||
        lower.contains('extension') ||
        lower.contains('pull') ||
        lower.contains('row')) {
      return 'Accessory';
    }
    if (lower.contains('finish') ||
        lower.contains('burn') ||
        lower.contains('pump') ||
        lower.contains('drop') ||
        lower.contains('cooldown')) {
      return 'Finisher';
    }
    if (lower.contains('rest') || lower.contains('deload') || lower.contains('recover')) {
      return 'Rest';
    }
    if (lower.contains('split') ||
        lower.contains('day 1') ||
        lower.contains('day 2') ||
        lower.contains('day 3') ||
        lower.contains('push') ||
        lower.contains('legs')) {
      return 'Split';
    }
    return 'Step';
  }

  static List<List<FlowchartNode>> computeLayers(
    List<FlowchartNode> nodes,
    List<FlowchartEdge> edges,
  ) {
    if (nodes.isEmpty) return [];

    final nodeMap = {for (final n in nodes) n.id: n};
    final incomingCount = <String, int>{for (final n in nodes) n.id: 0};
    final outgoing = <String, List<String>>{for (final n in nodes) n.id: []};

    for (final e in edges) {
      if (nodeMap.containsKey(e.from) && nodeMap.containsKey(e.to)) {
        incomingCount[e.to] = (incomingCount[e.to] ?? 0) + 1;
        outgoing[e.from]!.add(e.to);
      }
    }

    var roots = nodes.where((n) => (incomingCount[n.id] ?? 0) == 0).map((n) => n.id).toList();
    if (roots.isEmpty) {
      roots = [nodes.first.id];
    }

    final levelMap = <String, int>{};
    for (final r in roots) {
      levelMap[r] = 0;
    }

    final queue = List<String>.from(roots);
    final visited = <String>{};

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      visited.add(curr);
      final currLevel = levelMap[curr] ?? 0;

      for (final next in outgoing[curr] ?? []) {
        final existingLevel = levelMap[next] ?? 0;
        final newLevel = currLevel + 1;
        if (newLevel > existingLevel) {
          levelMap[next] = newLevel;
        }
        if (!visited.contains(next) && !queue.contains(next)) {
          queue.add(next);
        }
      }
    }

    int maxLevel = levelMap.values.fold(0, (max, v) => v > max ? v : max);
    for (final n in nodes) {
      if (!levelMap.containsKey(n.id)) {
        maxLevel++;
        levelMap[n.id] = maxLevel;
      }
    }

    final Map<int, List<FlowchartNode>> layersMap = {};
    for (final n in nodes) {
      final lvl = levelMap[n.id] ?? 0;
      layersMap.putIfAbsent(lvl, () => []).add(n);
    }

    final sortedKeys = layersMap.keys.toList()..sort();
    return sortedKeys.map((k) => layersMap[k]!).toList();
  }
}
