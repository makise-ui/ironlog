import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/utils/haptics.dart';
import 'package:ironlog/core/widgets/bouncy_pressable.dart';
import 'package:ironlog/domain/models/ai_chat_message.dart';

// ── Agent Question Card (Interactive In-Chat UI) ──────────────────────────
class AgentQuestionCard extends StatefulWidget {
  final AiToolExecutionResult result;
  final Function(String option) onAnswer;

  const AgentQuestionCard({
    super.key,
    required this.result,
    required this.onAnswer,
  });

  @override
  State<AgentQuestionCard> createState() => AgentQuestionCardState();
}

class AgentQuestionCardState extends State<AgentQuestionCard> {
  final TextEditingController _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustom() {
    final text = _customController.text.trim();
    if (text.isNotEmpty) {
      widget.onAnswer(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = widget.result.data?['question']?.toString() ?? 'Question';
    final summary = widget.result.data?['summary']?.toString();
    final optionsRaw = widget.result.data?['options'] as List?;
    final options = optionsRaw?.map((e) => e.toString()).toList() ?? [];
    final selectedOption = widget.result.data?['selectedOption']?.toString();
    final isAnswered = selectedOption != null;

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.94),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.isDark ? const Color(0xFF161B26) : const Color(0xFFF1F5F9),
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
                child: Icon(
                  Icons.help_outline_rounded,
                  size: 15,
                  color: context.accent,
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Coach Question',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              // Copy Question Action
              IconButton(
                icon: Icon(Icons.copy_rounded, size: 14, color: context.textTertiary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Copy question',
                onPressed: () {
                  final textToCopy = '${summary != null && summary.isNotEmpty ? "$summary\n\n" : ""}$question\nOptions: ${options.join(', ')}';
                  Clipboard.setData(ClipboardData(text: textToCopy));
                  AppHaptics.tap();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Question copied to clipboard', style: TextStyle(fontSize: 12)),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      width: 220,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  );
                },
              ),
            ],
          ),

          // Context Summary ("What is what")
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: context.isDark ? const Color(0xFF0F131C) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: context.isDark ? const Color(0x1FFFFFFF) : const Color(0x1F000000),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 14, color: context.accent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      summary,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        height: 1.35,
                        color: context.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 8),
          Text(
            question,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              height: 1.38,
              color: context.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),

          // Option choices - handles both long sentences (full-width) & short tags without any overflow
          if (options.any((o) => o.length > 22)) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final opt in options)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: BouncyPressable(
                      onTap: isAnswered ? null : () => widget.onAnswer(opt),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                        decoration: BoxDecoration(
                          color: selectedOption == opt
                              ? context.accent
                              : (context.isDark ? const Color(0xFF1E2433) : Colors.white),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: selectedOption == opt
                                ? context.accent
                                : (context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            if (selectedOption == opt) ...[
                              const Icon(Icons.check_circle_rounded, size: 15, color: Colors.black),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                opt,
                                softWrap: true,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                  color: selectedOption == opt
                                      ? Colors.black
                                      : context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isAnswered && !options.contains(selectedOption))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 15, color: Colors.black),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              selectedOption,
                              softWrap: true,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                height: 1.35,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ] else ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final opt in options)
                  BouncyPressable(
                    onTap: isAnswered ? null : () => widget.onAnswer(opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: selectedOption == opt
                            ? context.accent
                            : (context.isDark ? const Color(0xFF1E2433) : Colors.white),
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: selectedOption == opt
                              ? context.accent
                              : (context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1)),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (selectedOption == opt) ...[
                            const Icon(Icons.check_rounded, size: 13, color: Colors.black),
                            const SizedBox(width: 4),
                          ],
                          Flexible(
                            child: Text(
                              opt,
                              softWrap: true,
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selectedOption == opt
                                    ? Colors.black
                                    : context.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (isAnswered && !options.contains(selectedOption))
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: context.accent,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_rounded, size: 13, color: Colors.black),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            selectedOption,
                            softWrap: true,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],

          // Custom Write-In Option when not answered
          if (!isAnswered) ...[
            const SizedBox(height: 8),
            if (!_showCustomInput)
              BouncyPressable(
                onTap: () {
                  AppHaptics.tap();
                  setState(() => _showCustomInput = true);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.isDark ? const Color(0x15FFFFFF) : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: context.isDark ? const Color(0x22FFFFFF) : const Color(0xFFCBD5E1),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_note_rounded, size: 14, color: context.accent),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          'Write custom answer...',
                          softWrap: true,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.accent,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.isDark ? const Color(0xFF0F131C) : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.accent, width: 1.2),
                      ),
                      child: TextField(
                        controller: _customController,
                        autofocus: true,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: context.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Type your custom response...',
                          hintStyle: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            color: context.textTertiary,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                        ),
                        onSubmitted: (_) => _submitCustom(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  BouncyPressable(
                    onTap: _submitCustom,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.arrow_upward_rounded, size: 18, color: Colors.black),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
