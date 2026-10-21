import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/haptics.dart';
import '../../../core/widgets/bouncy_pressable.dart';
import '../../../domain/models/remote_ai_model.dart';

class ModelSelectionSheet extends StatefulWidget {
  final List<RemoteAiModel> models;
  final String currentModelId;
  final String endpointUrl;

  const ModelSelectionSheet({
    super.key,
    required this.models,
    required this.currentModelId,
    required this.endpointUrl,
  });

  static Future<RemoteAiModel?> show({
    required BuildContext context,
    required List<RemoteAiModel> models,
    required String currentModelId,
    required String endpointUrl,
  }) {
    return showModalBottomSheet<RemoteAiModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ModelSelectionSheet(
        models: models,
        currentModelId: currentModelId,
        endpointUrl: endpointUrl,
      ),
    );
  }

  @override
  State<ModelSelectionSheet> createState() => _ModelSelectionSheetState();
}

class _ModelSelectionSheetState extends State<ModelSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _filterTag = 'all'; // 'all', 'free', 'fast'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<RemoteAiModel> get _filteredModels {
    return widget.models.where((m) {
      if (_filterTag == 'free' && !m.isFree) return false;
      if (_filterTag == 'fast') {
        final id = m.id.toLowerCase();
        final name = m.name.toLowerCase();
        final isFast = id.contains('flash') ||
            id.contains('mini') ||
            id.contains('haiku') ||
            id.contains('small') ||
            id.contains('fast') ||
            id.contains('8b') ||
            name.contains('flash');
        if (!isFast) return false;
      }
      if (_searchQuery.isEmpty) return true;
      return m.id.toLowerCase().contains(_searchQuery) ||
          m.name.toLowerCase().contains(_searchQuery) ||
          (m.description?.toLowerCase().contains(_searchQuery) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filteredModels;
    final freeCount = widget.models.where((m) => m.isFree).length;

    String host = '';
    try {
      final uri = Uri.parse(widget.endpointUrl);
      host = uri.host.isNotEmpty ? uri.host : widget.endpointUrl;
    } catch (_) {
      host = widget.endpointUrl;
    }

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.82,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xF8111420) : Colors.white.withValues(alpha: 0.98),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF282E44) : const Color(0xFFE2E6F2),
                width: 1.2,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF333A52) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 6, 14, 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.hub_rounded, size: 20, color: context.accent),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Select AI Model',
                                  style: TextStyle(
                                    fontFamily: AppTypography.fontFamily,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: context.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: context.chipBg,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: context.chipBorder),
                                  ),
                                  child: Text(
                                    '${widget.models.length} available',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: context.textSecondary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              host,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textTertiary,
                                fontFamily: 'monospace',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                            color: isDark ? const Color(0xFF1C2234) : const Color(0xFFEFF2F8),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.close_rounded, size: 18, color: context.textSecondary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161A28) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? const Color(0xFF282F45) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 13.5, color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search by model ID, name, or provider...',
                        hintStyle: TextStyle(fontSize: 12.5, color: context.textTertiary),
                        prefixIcon: Icon(Icons.search_rounded, size: 18, color: context.textTertiary),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () => _searchController.clear(),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      ),
                    ),
                  ),
                ),

                // Filter Chips
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  child: Row(
                    children: [
                      _buildFilterChip('All (${widget.models.length})', 'all', isDark),
                      const SizedBox(width: 8),
                      if (freeCount > 0) ...[
                        _buildFilterChip('Free Tier ($freeCount)', 'free', isDark, isHighlight: true),
                        const SizedBox(width: 8),
                      ],
                      _buildFilterChip('Fast / Flash', 'fast', isDark),
                    ],
                  ),
                ),

                const Divider(height: 12),

                // Models List
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 36, color: context.textTertiary),
                              const SizedBox(height: 8),
                              Text(
                                'No models match "$_searchQuery"',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _filterTag = 'all');
                                },
                                child: Text('Reset Filters', style: TextStyle(color: context.accent)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final model = filtered[index];
                            final isSelected = model.id == widget.currentModelId;

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: BouncyPressable(
                                onTap: () {
                                  AppHaptics.selection();
                                  Navigator.of(context).pop(model);
                                },
                                scaleDown: 0.98,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? context.accent.withValues(alpha: isDark ? 0.18 : 0.12)
                                        : (isDark ? const Color(0xFF151927) : const Color(0xFFF9FAFD)),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected
                                          ? context.accent
                                          : (isDark ? const Color(0xFF232A3E) : const Color(0xFFE5E9F2)),
                                      width: isSelected ? 1.5 : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    model.id,
                                                    style: TextStyle(
                                                      fontFamily: 'monospace',
                                                      fontSize: 12.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: isSelected ? context.accent : context.textPrimary,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (model.isFree) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: AppColors.success.withValues(alpha: 0.18),
                                                      borderRadius: BorderRadius.circular(6),
                                                      border: Border.all(
                                                        color: AppColors.success.withValues(alpha: 0.5),
                                                        width: 0.8,
                                                      ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(Icons.bolt_rounded, size: 11, color: AppColors.success),
                                                        const SizedBox(width: 2),
                                                        Text(
                                                          'FREE',
                                                          style: TextStyle(
                                                            fontSize: 9.5,
                                                            fontWeight: FontWeight.w900,
                                                            color: AppColors.success,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                                if (model.contextLength != null && model.contextLength! > 0) ...[
                                                  const SizedBox(width: 6),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: context.chipBg,
                                                      borderRadius: BorderRadius.circular(5),
                                                    ),
                                                    child: Text(
                                                      '${(model.contextLength! / 1000).round()}k ctx',
                                                      style: TextStyle(
                                                        fontSize: 9.5,
                                                        fontWeight: FontWeight.w700,
                                                        color: context.textTertiary,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            if (model.name.isNotEmpty && model.name != model.id) ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                model.name,
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: context.textSecondary,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                            if (model.description != null && model.description!.isNotEmpty) ...[
                                              const SizedBox(height: 3),
                                              Text(
                                                model.description!,
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  color: context.textTertiary,
                                                  height: 1.25,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      if (isSelected)
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: context.accent,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                        )
                                      else
                                        Icon(Icons.arrow_forward_ios_rounded, size: 12, color: context.textTertiary),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String tag, bool isDark, {bool isHighlight = false}) {
    final isSelected = _filterTag == tag;

    Color activeColor = context.accent;
    if (isHighlight) {
      activeColor = AppColors.success;
    }

    return BouncyPressable(
      onTap: () {
        AppHaptics.selection();
        setState(() => _filterTag = tag);
      },
      scaleDown: 0.94,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF161A28) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? activeColor
                : (isDark ? const Color(0xFF282F45) : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
            color: isSelected
                ? activeColor
                : (isHighlight ? AppColors.success : context.textSecondary),
          ),
        ),
      ),
    );
  }
}
