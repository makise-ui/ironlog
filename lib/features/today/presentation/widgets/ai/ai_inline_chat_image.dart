import 'package:flutter/material.dart';
import 'package:ironlog/core/theme/app_colors.dart';
import 'package:ironlog/core/utils/haptics.dart';
import 'package:ironlog/core/widgets/shimmer_loading.dart';
import 'package:ironlog/domain/services/exercise_media_service.dart';

// ── Inline Chat Exercise Image (with Shimmer Loading & Tap to Enlarge) ───────
class InlineChatExerciseImage extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final String? altText;

  const InlineChatExerciseImage({
    super.key,
    required this.imageUrl,
    this.title,
    this.altText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayLabel = (altText != null && altText!.isNotEmpty)
        ? altText!
        : (title != null && title!.isNotEmpty ? title! : 'Exercise Form');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: GestureDetector(
        onTap: () {
          AppHaptics.tap();
          _showFullScreenImage(context, imageUrl, displayLabel);
        },
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 420,
            maxHeight: 220,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141722) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (imageUrl.startsWith('assets/'))
                Image.asset(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                )
              else
                Image.network(
                  imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return ShimmerLoading(
                      width: double.infinity,
                      height: 200,
                      borderRadius: BorderRadius.circular(14),
                      label: 'Loading $displayLabel...',
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    final local = ExerciseMediaService.getVerifiedMedia(displayLabel);
                    if (local != null) {
                      return Image.asset(
                        local.source,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      );
                    }
                    return Container(
                      width: double.infinity,
                      height: 120,
                      padding: const EdgeInsets.all(12),
                      color: isDark ? const Color(0xFF161924) : const Color(0xFFE2E8F0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fitness_center_rounded, size: 22, color: context.accent),
                          const SizedBox(height: 6),
                          Text(
                            displayLabel,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              // Bottom Pill Tag Badge
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.68),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.16),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.fit_screen_rounded,
                        size: 11,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          displayLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showFullScreenImage(BuildContext context, String url, String label) async {
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);

    await showDialog(
      context: context,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                clipBehavior: Clip.none,
                minScale: 0.8,
                maxScale: 3.5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: url.startsWith('assets/')
                      ? Image.asset(url, fit: BoxFit.contain)
                      : Image.network(
                          url,
                          fit: BoxFit.contain,
                          loadingBuilder: (c, child, progress) {
                            if (progress == null) return child;
                            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                          },
                          errorBuilder: (c, e, s) {
                            final local = ExerciseMediaService.getVerifiedMedia(label);
                            if (local != null) {
                              return Image.asset(local.source, fit: BoxFit.contain);
                            }
                            return const Center(
                              child: Icon(Icons.broken_image_rounded, size: 48, color: Colors.white54),
                            );
                          },
                        ),
                ),
              ),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  onPressed: () {
                    FocusScope.of(ctx).unfocus(disposition: UnfocusDisposition.scope);
                    Navigator.of(ctx).pop();
                  },
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
          FocusManager.instance.primaryFocus?.unfocus(disposition: UnfocusDisposition.scope);
        }
      });
    }
  }
}
