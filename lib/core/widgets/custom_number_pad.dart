import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

class CustomNumberPad extends StatelessWidget {
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;
  final bool showDecimal;

  const CustomNumberPad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspace,
    this.onClear,
    this.showDecimal = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: AppSpacing.xs),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: AppSpacing.xs),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: AppSpacing.xs),
        _buildBottomRow(),
      ],
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      children: digits.map((digit) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildKey(
              child: Text(
                digit,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                onDigitPressed(digit);
              },
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        // Decimal button
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: showDecimal
                ? _buildKey(
                    child: const Text(
                      '.',
                      style: TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onDigitPressed('.');
                    },
                  )
                : const SizedBox(height: 52),
          ),
        ),
        // Zero button
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildKey(
              child: const Text(
                '0',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              onTap: () {
                HapticFeedback.selectionClick();
                onDigitPressed('0');
              },
            ),
          ),
        ),
        // Backspace button
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: _buildKey(
              child: const Icon(
                Icons.backspace_outlined,
                size: 22,
                color: AppColors.textPrimary,
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                onBackspace();
              },
              onLongPress: onClear != null
                  ? () {
                      HapticFeedback.mediumImpact();
                      onClear!();
                    }
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKey({
    required Widget child,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.glassFillActive,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(
          width: 1.0,
          color: AppColors.glassBorderDim,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          splashColor: AppColors.accentCyan.withValues(alpha: 0.15),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: Center(child: child),
        ),
      ),
    );
  }
}
