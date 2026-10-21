import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/utils/haptics.dart';
import 'package:ironlog/core/widgets/bouncy_pressable.dart';
import 'package:ironlog/core/widgets/scale_tap.dart';
import 'package:ironlog/domain/services/exercise_media_service.dart';
import 'mermaid_flowchart_view.dart';

// ── Multi-Exercise Visuals Gallery (Interactive In-Chat UI) ─────────────────
class MultiExerciseVisualsCard extends StatefulWidget {
  final Map<String, dynamic> data;
  final Function(String exerciseName) onAskExercise;

  const MultiExerciseVisualsCard({
    super.key,
    required this.data,
    required this.onAskExercise,
  });

  @override
  State<MultiExerciseVisualsCard> createState() => MultiExerciseVisualsCardState();
}

class MultiExerciseVisualsCardState extends State<MultiExerciseVisualsCard> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final rawItems = widget.data['items'] as List?;
    final items = rawItems?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    if (items.isEmpty) return const SizedBox.shrink();

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
                child: Icon(Icons.collections_rounded, size: 14, color: context.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Exercise Visuals & Targets',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  color: context.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${items.length} MOVEMENTS',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                    letterSpacing: 0.5,
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
                    '${items.length} form guides loaded • Tap to expand visual cards',
                    style: TextStyle(fontSize: 11, color: context.textSecondary),
                  ),
                  const Spacer(),
                  Icon(Icons.visibility_outlined, size: 14, color: context.accent),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final name = item['name']?.toString() ?? 'Exercise';
                  final imgUrl = item['imageUrl']?.toString();
                  final muscle = item['primaryMuscle']?.toString() ?? 'General';

                  return Container(
                    width: 154,
                    decoration: BoxDecoration(
                      color: context.isDark ? const Color(0xFF1B2230) : Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image Thumbnail with Tap to Enlarge
                        InkWell(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                          onTap: () {
                            AppHaptics.selection();
                            _showEnlargedExerciseModal(context, item);
                          },
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                            child: Stack(
                              children: [
                                Container(
                                  height: 94,
                                  width: double.infinity,
                                  color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFF1F5F9),
                                  child: _buildAdaptiveExerciseThumbnail(imgUrl, name, context),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.65),
                                      borderRadius: BorderRadius.circular(5),
                                    ),
                                    child: const Icon(Icons.fullscreen_rounded, size: 13, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () {
                                  AppHaptics.selection();
                                  _showEnlargedExerciseModal(context, item);
                                },
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.25,
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: context.accent.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      muscle.toUpperCase(),
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: context.accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              BouncyPressable(
                                onTap: () {
                                  AppHaptics.selection();
                                  widget.onAskExercise(name);
                                },
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Ask Cues',
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: context.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdaptiveExerciseThumbnail(String? imgUrl, String exerciseName, BuildContext context) {
    if (imgUrl != null && imgUrl.isNotEmpty) {
      if (imgUrl.startsWith('assets/')) {
        return Image.asset(imgUrl, fit: BoxFit.cover);
      }
      if (imgUrl.startsWith('http://') || imgUrl.startsWith('https://')) {
        return Image.network(
          imgUrl,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            final local = ExerciseMediaService.getVerifiedMedia(exerciseName);
            if (local != null) {
              return Image.asset(local.source, fit: BoxFit.cover);
            }
            return Center(
              child: Icon(Icons.fitness_center_rounded, size: 28, color: context.textTertiary),
            );
          },
        );
      }
    }
    final local = ExerciseMediaService.getVerifiedMedia(exerciseName);
    if (local != null) {
      return Image.asset(local.source, fit: BoxFit.cover);
    }
    return Center(
      child: Icon(Icons.fitness_center_rounded, size: 28, color: context.textTertiary),
    );
  }

  Future<void> _showEnlargedExerciseModal(BuildContext context, Map<String, dynamic> item) async {
    final name = item['name']?.toString() ?? 'Exercise';
    final imgUrl = item['imageUrl']?.toString();
    final muscle = item['primaryMuscle']?.toString() ?? 'General';
    final equipment = item['equipment']?.toString();

    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header bar: muscle pill + close button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: ctx.accent.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: ctx.accent.withValues(alpha: 0.4), width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.fitness_center_rounded, size: 13, color: ctx.accent),
                        const SizedBox(width: 5),
                        Text(
                          muscle.toUpperCase(),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: ctx.accent,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Enlarged interactive image viewer
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.52,
                  maxWidth: double.infinity,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F131C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.6),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 3.5,
                  child: Center(
                    child: _buildAdaptiveExerciseThumbnail(imgUrl, name, ctx),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom card with details and coach cues button
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: ctx.isDark ? const Color(0xFF1B2230) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: ctx.isDark ? const Color(0x3364B5F6) : const Color(0xFF90CAF9),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: ctx.textPrimary,
                      ),
                    ),
                    if (equipment != null && equipment.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Equipment: $equipment',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: ctx.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'Pinch to zoom • Drag to pan',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: ctx.textTertiary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: BouncyPressable(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              widget.onAskExercise(name);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 9),
                              decoration: BoxDecoration(
                                color: ctx.accent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Colors.black),
                                    SizedBox(width: 6),
                                    Text(
                                      'Ask Coach Cues & Tips',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );

    if (context.mounted) {
      FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
      FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
    }
  }
}

// ── Progression Chart Card (Interactive In-Chat UI) ─────────────────────────
class ProgressionChartCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const ProgressionChartCard({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final title = data['title']?.toString() ?? 'Progression Chart';
    final unit = data['unit']?.toString() ?? 'kg';
    final summary = data['summary']?.toString();
    final rawPoints = data['dataPoints'] as List?;
    final points = rawPoints?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];

    if (points.isEmpty) return const SizedBox.shrink();

    final values = points.map((p) => (p['value'] as num?)?.toDouble() ?? 0.0).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final double minY = (minVal * 0.9).clamp(0.0, double.infinity);
    final double maxY = maxVal > minY ? maxVal * 1.15 : minY + 10;
    final gain = maxVal - minVal;

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
                child: Icon(Icons.trending_up_rounded, size: 14, color: context.accent),
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
                  '+${gain.toStringAsFixed(1)} $unit',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: context.accent,
                  ),
                ),
              ),
            ],
          ),

          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              summary,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.35,
                color: context.textSecondary,
              ),
            ),
          ],

          const SizedBox(height: 14),

          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: ((maxY - minY) / 3).clamp(1.0, double.infinity),
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: context.isDark ? const Color(0x1AFFFFFF) : const Color(0x1F000000),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 34,
                      interval: ((maxY - minY) / 3).clamp(1.0, double.infinity),
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          fontSize: 9.5,
                          fontFamily: 'Inter',
                          color: context.textTertiary,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx >= 0 && idx < points.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              points[idx]['label']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontFamily: 'Inter',
                                color: context.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: points.asMap().entries.map((entry) {
                      final val = (entry.value['value'] as num?)?.toDouble() ?? 0.0;
                      return FlSpot(entry.key.toDouble(), val);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: context.accent,
                    barWidth: 2.8,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          context.accent.withValues(alpha: 0.3),
                          context.accent.withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Native Mermaid Diagram Renderer (Interactive In-Chat UI) ────────────────
class MermaidDiagramNativeCard extends StatelessWidget {
  final String mermaidCode;

  const MermaidDiagramNativeCard({
    super.key,
    required this.mermaidCode,
  });

  @override
  Widget build(BuildContext context) {
    return VisualDiagramCard(
      data: {
        'title': 'Workflow Flowchart',
        'diagramType': 'FLOWCHART',
        'mermaidCode': mermaidCode,
        'nodes': [],
      },
    );
  }
}
