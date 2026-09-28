import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../domain/services/exercise_media_service.dart';
import '../../../../domain/services/exercise_auto_image_service.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import 'exercise_diagram_painter.dart';

class ExerciseVisualThumbnail extends StatelessWidget {
  final String? exerciseId;
  final String? exerciseName;
  final String? imagePath;
  final String muscleGroupId;
  final String equipment;
  final double size;
  final VoidCallback? onTap;

  const ExerciseVisualThumbnail({
    super.key,
    this.exerciseId,
    this.exerciseName,
    this.imagePath,
    required this.muscleGroupId,
    required this.equipment,
    this.size = 46.0,
    this.onTap,
  });

  IconData _getEquipmentIcon(String eq) {
    switch (eq.toLowerCase()) {
      case 'barbell':
        return Icons.fitness_center_rounded;
      case 'dumbbell':
        return Icons.sports_gymnastics_rounded;
      case 'cable':
        return Icons.swap_vert_circle_rounded;
      case 'machine':
      case 'leverage machine':
      case 'sled machine':
        return Icons.precision_manufacturing_rounded;
      case 'bodyweight':
        return Icons.accessibility_new_rounded;
      default:
        return Icons.fitness_center_rounded;
    }
  }

  Widget _buildCustomImage(String path, bool isDark) {
    final isGif = path.toLowerCase().endsWith('.gif');
    final fit = isGif ? BoxFit.contain : BoxFit.cover;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: fit,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ShimmerLoading(
            width: size,
            height: size,
            borderRadius: BorderRadius.circular(9),
          );
        },
        errorBuilder: (context, error, stackTrace) => _buildFallbackVector(isDark),
      );
    }
    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: fit,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (context, error, stackTrace) => _buildFallbackVector(isDark),
      );
    }
    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: fit,
        cacheWidth: (size * 2).toInt(),
        cacheHeight: (size * 2).toInt(),
        errorBuilder: (context, error, stackTrace) => _buildFallbackVector(isDark),
      );
    }
    return _buildFallbackVector(isDark);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final mediaInfo = exerciseName != null
        ? ExerciseMediaService.getVerifiedMedia(exerciseName!)
        : null;

    return ListenableBuilder(
      listenable: ExerciseAutoImageService.resolvedImagesNotifier,
      builder: (context, _) {
        final autoResolved = ExerciseAutoImageService.getResolvedPath(exerciseName);
        final effectiveImagePath = (imagePath != null && imagePath!.isNotEmpty)
            ? imagePath
            : autoResolved;

        // If no image is available yet and not a verified GIF, trigger background fetch
        if (effectiveImagePath == null && mediaInfo == null && exerciseName != null) {
          ExerciseAutoImageService.prefetch(
            exerciseName: exerciseName!,
            exerciseId: exerciseId,
          );
        }

        final badge = RepaintBoundary(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF202022) : const Color(0xFFF1F1F4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF383838) : const Color(0xFFE2E2E8),
                width: 1.0,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (effectiveImagePath != null && effectiveImagePath.isNotEmpty)
                    _buildCustomImage(effectiveImagePath, isDark)
                  else if (mediaInfo != null)
                    Padding(
                      padding: const EdgeInsets.all(2.0),
                      child: mediaInfo.isLocalAsset
                          ? Image.asset(
                              mediaInfo.source,
                              fit: BoxFit.contain,
                              cacheWidth: (size * 2).toInt(),
                              cacheHeight: (size * 2).toInt(),
                              errorBuilder: (context, error, stackTrace) => _buildFallbackVector(isDark),
                            )
                          : Image.network(
                              mediaInfo.source,
                              fit: BoxFit.contain,
                              cacheWidth: (size * 2).toInt(),
                              cacheHeight: (size * 2).toInt(),
                              errorBuilder: (context, error, stackTrace) => _buildFallbackVector(isDark),
                            ),
                    )
                  else
                    _buildFallbackVector(isDark),

                  // Equipment micro icon overlay on bottom-right
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: (isDark ? const Color(0xFF141416) : Colors.white).withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF424242) : const Color(0xFFE5E5E5),
                          width: 0.5,
                        ),
                      ),
                      child: Icon(
                        _getEquipmentIcon(equipment),
                        size: 9,
                        color: isDark ? const Color(0xFFD4D4D8) : const Color(0xFF555555),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        if (onTap != null) {
          return GestureDetector(
            onTap: onTap,
            child: badge,
          );
        }
        return badge;
      },
    );
  }

  Widget _buildFallbackVector(bool isDark) {
    return CustomPaint(
      size: Size(size, size),
      painter: ExerciseDiagramPainter(
        muscleGroupId: muscleGroupId,
        equipment: equipment,
        isDark: isDark,
        isThumbnail: true,
      ),
    );
  }
}
