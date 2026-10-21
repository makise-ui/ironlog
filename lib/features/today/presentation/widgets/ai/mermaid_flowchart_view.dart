import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/theme/app_typography.dart';
import 'package:ironlog/core/utils/haptics.dart';
import 'package:ironlog/core/widgets/bouncy_pressable.dart';
import 'package:ironlog/core/widgets/scale_tap.dart';
import 'mermaid_flowchart_parser.dart';

// ── Flowchart Inspection Full-Screen Modal (Interactive Pan & Zoom) ─────────

class FlowchartInspectionModal extends StatefulWidget {
  final FlowchartGraph graph;

  const FlowchartInspectionModal({super.key, required this.graph});

  static Future<void> show(BuildContext context, FlowchartGraph graph) {
    AppHaptics.selection();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FlowchartInspectionModal(graph: graph),
    );
  }

  @override
  State<FlowchartInspectionModal> createState() => _FlowchartInspectionModalState();
}

class _FlowchartInspectionModalState extends State<FlowchartInspectionModal> {
  final TransformationController _transController = TransformationController();
  double _currentScale = 1.0;

  void _setScale(double scale) {
    AppHaptics.tap();
    setState(() {
      _currentScale = scale;
      _transController.value = Matrix4.identity()..scale(scale);
    });
  }

  void _resetZoom() {
    AppHaptics.tap();
    setState(() {
      _currentScale = 1.0;
      _transController.value = Matrix4.identity();
    });
  }

  @override
  void dispose() {
    _transController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final layers = MermaidFlowchartParser.computeLayers(widget.graph.nodes, widget.graph.edges);

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xF80F121C) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF262E44) : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF333D56) : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Modal Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 14, 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.account_tree_rounded, size: 18, color: context.accent),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.graph.title,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.graph.nodes.length} nodes · ${widget.graph.edges.length} connections · Pinch & pan to inspect',
                          style: TextStyle(
                            fontSize: 11,
                            color: context.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  BouncyPressable(
                    onTap: () => Navigator.of(context).pop(),
                    scaleDown: 0.90,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E2638) : const Color(0xFFEFF2F8),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: context.textSecondary),
                    ),
                  ),
                ],
              ),
            ),

            // Zoom Presets Toolbar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: isDark ? const Color(0xFF131724) : const Color(0xFFF1F5F9),
              child: Row(
                children: [
                  Text(
                    'Zoom: ${(_currentScale * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: context.accent,
                    ),
                  ),
                  const Spacer(),
                  _buildZoomChip('Fit (0.7x)', () => _setScale(0.7)),
                  const SizedBox(width: 6),
                  _buildZoomChip('100%', () => _setScale(1.0)),
                  const SizedBox(width: 6),
                  _buildZoomChip('150%', () => _setScale(1.5)),
                  const SizedBox(width: 6),
                  _buildZoomChip('Reset', _resetZoom),
                ],
              ),
            ),

            // Full InteractiveViewer Graph Canvas
            Expanded(
              child: InteractiveViewer(
                transformationController: _transController,
                constrained: false,
                minScale: 0.3,
                maxScale: 4.0,
                boundaryMargin: const EdgeInsets.all(200),
                onInteractionUpdate: (details) {
                  _currentScale = _transController.value.getMaxScaleOnAxis();
                },
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        for (int i = 0; i < layers.length; i++) ...[
                          _buildLayerRow(layers[i], i, isDark, context),
                          if (i < layers.length - 1)
                            _buildConnectorBetweenLayers(layers[i], layers[i + 1], context),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomChip(String label, VoidCallback onTap) {
    return BouncyPressable(
      onTap: onTap,
      scaleDown: 0.92,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1E2638)
              : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF2C364F)
                : const Color(0xFFCBD5E1),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: context.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildLayerRow(List<FlowchartNode> layerNodes, int layerIndex, bool isDark, BuildContext context) {
    if (layerNodes.length == 1) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340, minWidth: 180),
          child: _buildNodeCard(layerNodes.first, isDark, context),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < layerNodes.length; i++) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240, minWidth: 140),
            child: _buildNodeCard(layerNodes[i], isDark, context),
          ),
          if (i < layerNodes.length - 1) const SizedBox(width: 16),
        ],
      ],
    );
  }

  Widget _buildNodeCard(FlowchartNode node, bool isDark, BuildContext context) {
    final phaseColor = _getPhaseColor(node.phase, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2234) : Colors.white,
        borderRadius: BorderRadius.circular(node.shape == 'pill' ? 22 : 12),
        border: Border.all(
          color: node.isDecision
              ? const Color(0xFFF59E0B)
              : phaseColor.withValues(alpha: isDark ? 0.55 : 0.7),
          width: node.isDecision ? 1.6 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (node.isDecision) ...[
                const Icon(Icons.alt_route_rounded, size: 13, color: Color(0xFFF59E0B)),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  (node.isDecision ? 'DECISION' : node.phase).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            node.label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: context.textPrimary,
            ),
          ),
          if (node.description != null && node.description!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              node.description!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                color: context.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConnectorBetweenLayers(
    List<FlowchartNode> parentLayer,
    List<FlowchartNode> childLayer,
    BuildContext context,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Icon(Icons.arrow_downward_rounded, size: 16, color: context.accent),
    );
  }

  Color _getPhaseColor(String phase, BuildContext context) {
    final lower = phase.toLowerCase();
    if (lower.contains('warm')) return const Color(0xFFF59E0B);
    if (lower.contains('compound') || lower.contains('heavy') || lower.contains('primary')) {
      return context.accent;
    }
    if (lower.contains('accessory') || lower.contains('hypertrophy') || lower.contains('secondary')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('finish') || lower.contains('pump') || lower.contains('burn')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('decision') || lower.contains('eval')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('rest') || lower.contains('deload')) {
      return const Color(0xFF64748B);
    }
    if (lower.contains('split') || lower.contains('day')) {
      return const Color(0xFF38BDF8);
    }
    return context.accent;
  }
}

// ── Flowchart Graphical Visualizer Widget ────────────────────────────────────

class FlowchartGraphView extends StatefulWidget {
  final FlowchartGraph graph;

  const FlowchartGraphView({
    super.key,
    required this.graph,
  });

  @override
  State<FlowchartGraphView> createState() => _FlowchartGraphViewState();
}

class _FlowchartGraphViewState extends State<FlowchartGraphView> {
  bool _zoomMode = false;

  Color _getPhaseColor(String phase, BuildContext context) {
    final lower = phase.toLowerCase();
    if (lower.contains('warm')) return const Color(0xFFF59E0B);
    if (lower.contains('compound') || lower.contains('heavy') || lower.contains('primary')) {
      return context.accent;
    }
    if (lower.contains('accessory') || lower.contains('hypertrophy') || lower.contains('secondary')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('finish') || lower.contains('pump') || lower.contains('burn')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('decision') || lower.contains('eval')) {
      return const Color(0xFFF59E0B);
    }
    if (lower.contains('rest') || lower.contains('deload')) {
      return const Color(0xFF64748B);
    }
    if (lower.contains('split') || lower.contains('day')) {
      return const Color(0xFF38BDF8);
    }
    return context.accent;
  }

  @override
  Widget build(BuildContext context) {
    final layers = MermaidFlowchartParser.computeLayers(widget.graph.nodes, widget.graph.edges);
    if (layers.isEmpty) {
      return const Center(child: Text('No diagram nodes available'));
    }

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < layers.length; i++) ...[
          _buildLayerRow(layers[i], i),
          if (i < layers.length - 1)
            _buildConnectorBetweenLayers(layers[i], layers[i + 1]),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Controls Toolbar
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.hub_rounded, size: 12, color: context.accent),
              const SizedBox(width: 5),
              Text(
                '${widget.graph.nodes.length} nodes • ${widget.graph.edges.length} branches',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: context.textSecondary,
                ),
              ),
              const Spacer(),
              // Inspect / Full Screen Button
              ScaleTap(
                onPressed: () => FlowchartInspectionModal.show(context, widget.graph),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: context.accent.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen_rounded, size: 12, color: context.accent),
                      const SizedBox(width: 3),
                      Text(
                        'Inspect 🔍',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: context.accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Pan Mode Toggle
              ScaleTap(
                onPressed: () {
                  AppHaptics.selection();
                  setState(() => _zoomMode = !_zoomMode);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _zoomMode ? context.accent.withValues(alpha: 0.2) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _zoomMode ? context.accent : Colors.transparent,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _zoomMode ? Icons.zoom_out_map_rounded : Icons.pan_tool_outlined,
                        size: 11,
                        color: _zoomMode ? context.accent : context.textSecondary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        _zoomMode ? 'Pan' : 'Scroll',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: _zoomMode ? context.accent : context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Graph Canvas
        _zoomMode
            ? SizedBox(
                height: 380,
                width: double.infinity,
                child: InteractiveViewer(
                  constrained: false,
                  minScale: 0.4,
                  maxScale: 2.8,
                  boundaryMargin: const EdgeInsets.all(80),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: content,
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: MediaQuery.of(context).size.width * 0.84,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: content,
                    ),
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildLayerRow(List<FlowchartNode> layerNodes, int layerIndex) {
    if (layerNodes.length == 1) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 160),
          child: _buildNodeCard(layerNodes.first),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < layerNodes.length; i++) ...[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220, minWidth: 130),
            child: _buildNodeCard(layerNodes[i]),
          ),
          if (i < layerNodes.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }

  Widget _buildConnectorBetweenLayers(
    List<FlowchartNode> parentLayer,
    List<FlowchartNode> childLayer,
  ) {
    if (parentLayer.length == 1 && childLayer.length == 1) {
      final parentNode = parentLayer.first;
      final childNode = childLayer.first;
      final edge = widget.graph.edges.cast<FlowchartEdge?>().firstWhere(
            (e) => e != null && e.from == parentNode.id && e.to == childNode.id,
            orElse: () => null,
          );

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 1.5,
            height: 10,
            color: context.accent.withValues(alpha: 0.45),
          ),
          if (edge?.label != null && edge!.label!.isNotEmpty)
            _buildEdgeLabelBadge(edge.label!),
          Container(
            width: 1.5,
            height: 10,
            color: context.accent.withValues(alpha: 0.45),
          ),
          Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: context.accent),
        ],
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Icon(Icons.arrow_downward_rounded, size: 14, color: context.accent),
    );
  }

  Widget _buildEdgeLabelBadge(String label) {
    final lower = label.toLowerCase();
    Color bg = context.accent.withValues(alpha: 0.15);
    Color fg = context.accent;

    if (lower.contains('yes') || lower.contains('pass') || lower.contains('+')) {
      bg = const Color(0xFF10B981).withValues(alpha: 0.18);
      fg = const Color(0xFF10B981);
    } else if (lower.contains('no') || lower.contains('fail') || lower.contains('-')) {
      bg = const Color(0xFFEF4444).withValues(alpha: 0.18);
      fg = const Color(0xFFEF4444);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: fg.withValues(alpha: 0.3), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  Widget _buildNodeCard(FlowchartNode node) {
    final phaseColor = _getPhaseColor(node.phase, context);
    final isDark = context.isDark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          AppHaptics.selection();
          _showNodeDetailsDialog(node);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1B2230) : Colors.white,
            borderRadius: BorderRadius.circular(node.shape == 'pill' ? 20 : 10),
            border: Border.all(
              color: node.isDecision
                  ? const Color(0xFFF59E0B)
                  : phaseColor.withValues(alpha: isDark ? 0.45 : 0.6),
              width: node.isDecision ? 1.4 : 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (node.isDecision) ...[
                    const Icon(Icons.alt_route_rounded, size: 12, color: Color(0xFFF59E0B)),
                    const SizedBox(width: 3),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      (node.isDecision ? 'DECISION' : node.phase).toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                node.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: context.textPrimary,
                ),
              ),
              if (node.description != null && node.description!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  node.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    height: 1.25,
                    color: context.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showNodeDetailsDialog(FlowchartNode node) {
    final phaseColor = _getPhaseColor(node.phase, context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: ctx.isDark ? const Color(0xFF1E2638) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: phaseColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: phaseColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                node.phase.toUpperCase(),
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: phaseColor),
              ),
            ),
          ],
        ),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              node.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: ctx.textPrimary,
              ),
            ),
            if (node.description != null && node.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                node.description!,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: ctx.textSecondary,
                ),
              ),
            ],
            if (node.next.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Connected Steps: ${node.next.join(", ")}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: ctx.accent,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close', style: TextStyle(color: ctx.textSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Visual Diagram & Flowchart Card (Interactive In-Chat UI) ────────────────

class VisualDiagramCard extends StatefulWidget {
  final Map<String, dynamic> data;

  const VisualDiagramCard({super.key, required this.data});

  @override
  State<VisualDiagramCard> createState() => _VisualDiagramCardState();
}

class _VisualDiagramCardState extends State<VisualDiagramCard> {
  int _activeTab = 0; // 0 = Flowchart Graph, 1 = Step Cards, 2 = Mermaid Code
  bool _isCollapsed = false;

  Color _getPhaseColor(String phase, BuildContext context) {
    final lower = phase.toLowerCase();
    if (lower.contains('warm')) return const Color(0xFFF59E0B);
    if (lower.contains('compound') || lower.contains('heavy') || lower.contains('primary')) {
      return context.accent;
    }
    if (lower.contains('accessory') || lower.contains('hypertrophy') || lower.contains('secondary')) {
      return const Color(0xFF8B5CF6);
    }
    if (lower.contains('finish') || lower.contains('pump') || lower.contains('burn')) {
      return const Color(0xFF10B981);
    }
    if (lower.contains('rest') || lower.contains('deload')) {
      return const Color(0xFF64748B);
    }
    return context.accent;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.data['title']?.toString() ?? 'Visual Flowchart';
    final diagramType = widget.data['diagramType']?.toString().toUpperCase() ?? 'FLOWCHART';
    final summary = widget.data['summary']?.toString();
    final rawNodes = widget.data['nodes'] as List?;
    final nodes = rawNodes?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    final mermaidCode = widget.data['mermaidCode']?.toString() ?? '';

    final graph = MermaidFlowchartParser.parse(
      mermaidCode,
      defaultTitle: title,
      fallbackNodes: nodes,
    );

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF141923) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.isDark ? const Color(0x3364B5F6) : const Color(0xFF90CAF9),
          width: 1.1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.account_tree_rounded, size: 14, color: context.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  diagramType,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Inspect / Pan & Zoom
              ScaleTap(
                onPressed: () => FlowchartInspectionModal.show(context, graph),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fullscreen_rounded, size: 12, color: context.accent),
                      const SizedBox(width: 2),
                      Text(
                        'Inspect',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: context.accent),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              ScaleTap(
                onPressed: () {
                  AppHaptics.tap();
                  setState(() => _isCollapsed = !_isCollapsed);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: context.chipBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: context.chipBorder),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _isCollapsed ? 'Show' : 'Hide',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.textSecondary),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        _isCollapsed ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_up_rounded,
                        size: 13,
                        color: context.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_isCollapsed) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: () {
                AppHaptics.tap();
                setState(() => _isCollapsed = false);
              },
              child: Row(
                children: [
                  Text(
                    '${graph.nodes.length} nodes (${graph.edges.length} connections) • Tap to expand flowchart',
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                  const Spacer(),
                  Icon(Icons.visibility_outlined, size: 14, color: context.accent),
                ],
              ),
            ),
          ] else ...[
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                summary,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  height: 1.35,
                  color: context.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 10),

            // Tab bar
            Row(
              children: [
                _buildModePill(0, Icons.hub_rounded, 'Flowchart'),
                const SizedBox(width: 6),
                _buildModePill(1, Icons.view_agenda_rounded, 'Step Cards (${graph.nodes.length})'),
                if (mermaidCode.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  _buildModePill(2, Icons.code_rounded, 'Mermaid Code'),
                ],
              ],
            ),

            const SizedBox(height: 10),

            if (_activeTab == 0)
              FlowchartGraphView(graph: graph)
            else if (_activeTab == 1)
              _buildStepCardsList(graph.nodes)
            else if (_activeTab == 2 && mermaidCode.isNotEmpty)
              _buildMermaidCodeView(mermaidCode),
          ],
        ],
      ),
    );
  }

  Widget _buildModePill(int index, IconData icon, String label) {
    final isSelected = _activeTab == index;
    return ScaleTap(
      onPressed: () {
        AppHaptics.selection();
        setState(() => _activeTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: isSelected ? context.accent : (context.isDark ? const Color(0xFF1B2230) : const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11.5,
              color: isSelected ? Colors.black : context.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.black : context.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMermaidCodeView(String code) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Mermaid Syntax',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
              ),
              BouncyPressable(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  AppHaptics.tap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mermaid code copied to clipboard'), duration: Duration(seconds: 2)),
                  );
                },
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 12, color: context.accent),
                    const SizedBox(width: 4),
                    Text('Copy', style: TextStyle(fontSize: 11, color: context.accent, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SelectableText(
            code,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 11.5,
              height: 1.35,
              color: Color(0xFF38BDF8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepCardsList(List<FlowchartNode> nodes) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (int i = 0; i < nodes.length; i++) ...[
          _buildNodeItem(nodes[i], i, i == nodes.length - 1),
          if (i < nodes.length - 1)
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.arrow_downward_rounded, size: 14, color: context.accent),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildNodeItem(FlowchartNode node, int index, bool isLast) {
    final phaseColor = _getPhaseColor(node.phase, context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF1B2230) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: node.isDecision
              ? const Color(0xFFF59E0B)
              : (context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor, width: 1.2),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        node.label,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: (node.isDecision ? const Color(0xFFF59E0B) : phaseColor).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        (node.isDecision ? 'DECISION' : node.phase).toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: node.isDecision ? const Color(0xFFF59E0B) : phaseColor,
                        ),
                      ),
                    ),
                  ],
                ),
                if (node.description != null && node.description!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    node.description!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      height: 1.3,
                      color: context.textSecondary,
                    ),
                  ),
                ],
                if (node.next.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    '➔ Next: ${node.next.join(", ")}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: context.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
