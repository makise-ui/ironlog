import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/theme/app_typography.dart';
import 'package:ironlog/core/utils/haptics.dart';
import 'package:ironlog/core/widgets/scale_tap.dart';
import 'package:ironlog/domain/models/ai_memory_model.dart';
import 'package:ironlog/domain/services/ai_memory_service.dart';

// ── In-Chat Badge When Memory is Persisted ────────────────────────────────────
class MemorySavedBadge extends StatelessWidget {
  final String fact;
  final String? category;

  const MemorySavedBadge({
    super.key,
    required this.fact,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4, left: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.accent.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.psychology_rounded, size: 14, color: context.accent),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              '🧠 Remembered: "$fact"',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: context.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Manage Memories Sheet (Modal UI) ──────────────────────────────────────────
class ManageMemoriesSheet extends ConsumerStatefulWidget {
  final String companionName;

  const ManageMemoriesSheet({
    super.key,
    required this.companionName,
  });

  @override
  ConsumerState<ManageMemoriesSheet> createState() => ManageMemoriesSheetState();
}

class ManageMemoriesSheetState extends ConsumerState<ManageMemoriesSheet> {
  final TextEditingController _addController = TextEditingController();
  List<AiUserMemory> _memories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMemories();
  }

  @override
  void dispose() {
    _addController.dispose();
    super.dispose();
  }

  Future<void> _loadMemories() async {
    final list = await ref.read(aiMemoryServiceProvider).getMemories();
    if (mounted) {
      setState(() {
        _memories = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _addMemory() async {
    final text = _addController.text.trim();
    if (text.isEmpty) return;

    AppHaptics.success();
    await ref.read(aiMemoryServiceProvider).saveMemory(fact: text);
    _addController.clear();
    await _loadMemories();
  }

  Future<void> _deleteMemory(AiUserMemory mem) async {
    AppHaptics.tap();
    await ref.read(aiMemoryServiceProvider).deleteMemory(mem.id);
    await _loadMemories();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Removed memory: "${mem.fact}"', style: const TextStyle(fontSize: 12)),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear All Memories?'),
        content: Text('This will erase all facts ${widget.companionName} remembers about you.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      AppHaptics.warning();
      await ref.read(aiMemoryServiceProvider).clearAllMemories();
      await _loadMemories();
    }
  }

  Color _categoryColor(String category, BuildContext context) {
    switch (category.toLowerCase()) {
      case 'injury':
        return const Color(0xFFEF4444); // Red
      case 'goal':
        return const Color(0xFFF59E0B); // Amber
      case 'equipment':
        return const Color(0xFF06B6D4); // Cyan
      case 'preference':
        return const Color(0xFFA855F7); // Purple
      case 'schedule':
        return const Color(0xFF10B981); // Emerald
      default:
        return context.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D0F18) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.psychology_rounded, size: 24, color: context.accent),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agent Memory',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamilyDisplay,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'What ${widget.companionName} remembers across all conversations',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_memories.isNotEmpty)
                  TextButton(
                    onPressed: _clearAll,
                    child: const Text(
                      'Clear',
                      style: TextStyle(fontSize: 12, color: AppColors.error),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Input Bar to Add Memory Manually
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF161926) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _addController,
                      style: TextStyle(fontSize: 13, color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add fact (e.g. "Left wrist pain during bench")',
                        hintStyle: TextStyle(fontSize: 12, color: context.textTertiary),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _addMemory(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ScaleTap(
                  onPressed: _addMemory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: context.accent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '+ Add',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Memory Items List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _memories.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.psychology_outlined,
                                size: 48,
                                color: context.textTertiary.withValues(alpha: 0.6),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No memories stored yet',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: context.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'As you chat with ${widget.companionName}, key injuries, equipment limits, and goals you share will be remembered here automatically across all sessions.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: context.textTertiary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        itemCount: _memories.length,
                        itemBuilder: (context, index) {
                          final mem = _memories[index];
                          final catColor = _categoryColor(mem.category, context);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141724) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category Pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    mem.category.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      color: catColor,
                                      letterSpacing: 0.4,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mem.fact,
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: context.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(
                                    Icons.delete_outline_rounded,
                                    size: 16,
                                    color: context.textTertiary,
                                  ),
                                  tooltip: 'Forget this memory',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () => _deleteMemory(mem),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
