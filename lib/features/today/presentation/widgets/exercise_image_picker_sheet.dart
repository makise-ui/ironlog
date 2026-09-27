import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/glass_button.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../data/providers.dart';
import '../../../../domain/models/exercise_model.dart';
import '../../../../domain/services/exercise_image_search_service.dart';
import '../../../../core/widgets/shimmer_loading.dart';

class ExerciseImagePickerSheet extends ConsumerStatefulWidget {
  final ExerciseModel exercise;
  final Function(String? newImagePath)? onImageSelected;

  const ExerciseImagePickerSheet({
    super.key,
    required this.exercise,
    this.onImageSelected,
  });

  static Future<String?> show(
    BuildContext context, {
    required ExerciseModel exercise,
    Function(String? newImagePath)? onImageSelected,
  }) {
    AppHaptics.tap();
    return showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExerciseImagePickerSheet(
        exercise: exercise,
        onImageSelected: onImageSelected,
      ),
    );
  }

  @override
  ConsumerState<ExerciseImagePickerSheet> createState() => _ExerciseImagePickerSheetState();
}

class _ExerciseImagePickerSheetState extends ConsumerState<ExerciseImagePickerSheet> {
  late final TextEditingController _searchController;
  List<ExerciseImageCandidate> _candidates = [];
  bool _isLoading = true;
  String? _selectedImageUrl;
  String? _selectedLocalPath;
  bool _isSaving = false;
  int _previewIndex = 0;
  Timer? _carouselTimer;
  bool _userHasSelected = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.exercise.name);
    _selectedLocalPath = widget.exercise.imagePath;
    _runSearch();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _startCarouselTimer() {
    _carouselTimer?.cancel();
    if (_candidates.isEmpty || _userHasSelected) return;

    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (!mounted || _userHasSelected) {
        timer.cancel();
        return;
      }
      setState(() {
        _previewIndex = (_previewIndex + 1) % _candidates.length.clamp(1, 6);
      });
    });
  }

  Future<void> _runSearch() async {
    setState(() {
      _isLoading = true;
    });

    final results = await ExerciseImageSearchService.searchCandidateImages(_searchController.text);
    if (!mounted) return;

    setState(() {
      _candidates = results;
      _isLoading = false;
      _previewIndex = 0;
    });

    _startCarouselTimer();
  }

  void _selectCandidate(ExerciseImageCandidate candidate) {
    AppHaptics.selection();
    _carouselTimer?.cancel();
    setState(() {
      _userHasSelected = true;
      _selectedImageUrl = candidate.fullUrl;
      _selectedLocalPath = null;
    });
  }

  Future<void> _pickFromGallery() async {
    AppHaptics.tap();
    final pickedPath = await ExerciseImageSearchService.pickImageFromGallery(
      exerciseId: widget.exercise.id,
    );
    if (pickedPath != null && mounted) {
      setState(() {
        _userHasSelected = true;
        _selectedLocalPath = pickedPath;
        _selectedImageUrl = null;
      });
    }
  }

  Future<void> _pickFromCamera() async {
    AppHaptics.tap();
    final pickedPath = await ExerciseImageSearchService.pickImageFromCamera(
      exerciseId: widget.exercise.id,
    );
    if (pickedPath != null && mounted) {
      setState(() {
        _userHasSelected = true;
        _selectedLocalPath = pickedPath;
        _selectedImageUrl = null;
      });
    }
  }

  Future<void> _confirmSelection() async {
    if (_selectedImageUrl == null && _selectedLocalPath == null) return;

    setState(() => _isSaving = true);
    AppHaptics.save();

    String? finalPath = _selectedLocalPath;

    if (_selectedImageUrl != null) {
      finalPath = await ExerciseImageSearchService.downloadAndCacheImage(
        exerciseId: widget.exercise.id,
        imageUrl: _selectedImageUrl!,
      );
      finalPath ??= _selectedImageUrl;
    }

    if (finalPath != null) {
      await ref.read(exerciseRepositoryProvider).updateExerciseImage(
        widget.exercise.id,
        finalPath,
      );
      widget.onImageSelected?.call(finalPath);
    }

    if (mounted) {
      Navigator.of(context).pop(finalPath);
    }
  }

  Future<void> _removeImage() async {
    AppHaptics.tap();
    setState(() => _isSaving = true);
    await ref.read(exerciseRepositoryProvider).updateExerciseImage(
      widget.exercise.id,
      null,
    );
    widget.onImageSelected?.call(null);
    if (mounted) {
      Navigator.of(context).pop(null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeHeroUrl = _selectedImageUrl ??
        (_selectedLocalPath == null && _candidates.isNotEmpty
            ? _candidates[_previewIndex.clamp(0, _candidates.length - 1)].thumbnailUrl
            : null);

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusLg)),
        border: Border(top: BorderSide(color: context.sheetBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.handleBar,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.image_search_rounded, color: context.accent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select Exercise Image',
                        style: TextStyle(
                          fontFamily: AppTypography.fontFamilyDisplay,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        widget.exercise.name,
                        style: TextStyle(fontSize: 12, color: context.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: context.inputBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.inputBorder),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(Icons.search_rounded, color: context.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(color: context.textPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search images...',
                        hintStyle: TextStyle(color: context.textTertiary, fontSize: 13),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      onSubmitted: (_) => _runSearch(),
                    ),
                  ),
                  ScaleTap(
                    onPressed: _runSearch,
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: context.accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Search',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.onAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Hero Preview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 160,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141722) : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _userHasSelected ? context.accent : context.cardBorder,
                  width: _userHasSelected ? 1.5 : 1.0,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_selectedLocalPath != null)
                      Image.file(
                        File(_selectedLocalPath!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => _buildPreviewPlaceholder(context),
                      )
                    else if (activeHeroUrl != null)
                      Image.network(
                        activeHeroUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => _buildPreviewPlaceholder(context),
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return ShimmerLoading(
                            width: double.infinity,
                            height: double.infinity,
                            borderRadius: BorderRadius.circular(13),
                            label: 'Loading preview...',
                          );
                        },
                      )
                    else
                      _buildPreviewPlaceholder(context),

                    // Top Status Badge
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: context.cardBorder),
                        ),
                        child: Text(
                          _userHasSelected
                              ? 'SELECTED IMAGE'
                              : (_candidates.isNotEmpty
                                  ? 'AUTO-PREVIEWING (${_previewIndex + 1}/${_candidates.length.clamp(1, 6)})'
                                  : 'NO IMAGE SELECTED'),
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                            color: _userHasSelected ? context.accent : context.textSecondary,
                          ),
                        ),
                      ),
                    ),

                    // Tap to choose current preview shortcut
                    if (!_userHasSelected && _candidates.isNotEmpty)
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: ScaleTap(
                          onPressed: () {
                            if (_candidates.isNotEmpty) {
                              _selectCandidate(_candidates[_previewIndex.clamp(0, _candidates.length - 1)]);
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: context.accent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_rounded, size: 14, color: context.onAccent),
                                const SizedBox(width: 4),
                                Text(
                                  'Select This',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: context.onAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Secondary Options (Gallery / Camera / Reset)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ScaleTap(
                    onPressed: _pickFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: context.chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.chipBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.photo_library_outlined, size: 15, color: context.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Gallery',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ScaleTap(
                    onPressed: _pickFromCamera,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: context.chipBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: context.chipBorder),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined, size: 15, color: context.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Camera',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (widget.exercise.imagePath != null) ...[
                  const SizedBox(width: 8),
                  ScaleTap(
                    onPressed: _removeImage,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, size: 15, color: AppColors.error),
                          SizedBox(width: 4),
                          Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 8),
          Divider(height: 1, color: context.cardBorder),

          // Candidate Results Grid
          Expanded(
            child: _isLoading
                ? GridView.builder(
                    padding: const EdgeInsets.all(16),
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: 4,
                    itemBuilder: (context, index) {
                      return ShimmerLoading(
                        width: double.infinity,
                        height: double.infinity,
                        borderRadius: BorderRadius.circular(10),
                        label: index == 0 ? 'Searching images...' : null,
                      );
                    },
                  )
                : _candidates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.image_not_supported_outlined, size: 36, color: context.textTertiary),
                            const SizedBox(height: 8),
                            Text(
                              'No matching images found',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Try refining the search term or pick a photo from your gallery',
                              style: TextStyle(fontSize: 12, color: context.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        physics: const BouncingScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.05,
                        ),
                        itemCount: _candidates.length,
                        itemBuilder: (context, index) {
                          final candidate = _candidates[index];
                          final isSelected = _selectedImageUrl == candidate.fullUrl;

                          return ScaleTap(
                            onPressed: () => _selectCandidate(candidate),
                            child: Container(
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1B1E2B) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? context.accent : context.cardBorder,
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: Image.network(
                                      candidate.thumbnailUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _buildGridPlaceholder(context),
                                      loadingBuilder: (context, child, progress) {
                                        if (progress == null) return child;
                                        return ShimmerLoading(
                                          width: double.infinity,
                                          height: double.infinity,
                                          borderRadius: BorderRadius.circular(9),
                                        );
                                      },
                                    ),
                                  ),
                                  // Selected checkmark overlay
                                  if (isSelected)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: context.accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: context.onAccent,
                                        ),
                                      ),
                                    ),
                                  // Image Title Footer
                                  Positioned(
                                    bottom: 0,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(9)),
                                      ),
                                      child: Text(
                                        candidate.title,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Confirm Action
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: GlassButton(
                  text: _isSaving ? 'Saving...' : 'Set as Exercise Image',
                  icon: Icons.check_circle_outline_rounded,
                  style: GlassButtonStyle.primary,
                  onPressed: (_selectedImageUrl != null || _selectedLocalPath != null) && !_isSaving
                      ? _confirmSelection
                      : () {},
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center_rounded, size: 36, color: context.textTertiary),
          const SizedBox(height: 6),
          Text(
            'Select an image below to set it for ${widget.exercise.name}',
            style: TextStyle(fontSize: 12, color: context.textTertiary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildGridPlaceholder(BuildContext context) {
    return Container(
      color: context.cardBg,
      child: Center(
        child: Icon(Icons.broken_image_rounded, size: 24, color: context.textTertiary),
      ),
    );
  }
}
