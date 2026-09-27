import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/widgets/scale_tap.dart';
import '../../../../core/widgets/shimmer_loading.dart';
import '../../../../domain/services/exercise_image_search_service.dart';
import '../../../../domain/services/exercise_media_service.dart';
import 'exercise_web_search_sheet.dart';

class ExercisePositionSlideshow extends StatefulWidget {
  final String exerciseName;
  final String muscleGroupId;
  final String equipment;
  final String? currentImagePath;
  final Function(String newImagePath)? onImageSelected;
  final VoidCallback? onChangeImage;
  final double height;

  const ExercisePositionSlideshow({
    super.key,
    required this.exerciseName,
    required this.muscleGroupId,
    required this.equipment,
    this.currentImagePath,
    this.onImageSelected,
    this.onChangeImage,
    this.height = 270,
  });

  @override
  State<ExercisePositionSlideshow> createState() => _ExercisePositionSlideshowState();
}

class _ExercisePositionSlideshowState extends State<ExercisePositionSlideshow> {
  late final PageController _pageController;
  Timer? _cycleTimer;
  Timer? _retryTimer;

  bool _isLoading = false;
  bool _hasError = false;
  int _retrySecondsLeft = 3;
  int _retryAttempt = 0;
  static const int _maxRetries = 3;

  List<ExerciseImageCandidate> _candidates = [];
  int _currentIndex = 0;
  bool _isUserInteracting = false;
  bool _isSavedFeedback = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeVisuals();
  }

  void _initializeVisuals() {
    _stopTimers();

    // 1. If verified exact animation GIF exists locally, display it immediately on frame 1
    final verified = ExerciseMediaService.getVerifiedMedia(widget.exerciseName);
    if (verified != null) {
      _candidates = [
        ExerciseImageCandidate(
          title: '${widget.exerciseName} - 3D Movement Loop',
          thumbnailUrl: verified.source,
          fullUrl: verified.source,
          source: 'Verified 3D Simulation',
          positionTag: '3D MOTION LOOP',
        ),
      ];
      _isLoading = false;
      _hasError = false;
      _currentIndex = 0;
      return;
    }

    // 2. If user already has a saved custom/primary image, display it immediately
    if (widget.currentImagePath != null && widget.currentImagePath!.trim().isNotEmpty) {
      _candidates = [
        ExerciseImageCandidate(
          title: widget.exerciseName,
          thumbnailUrl: widget.currentImagePath!.trim(),
          fullUrl: widget.currentImagePath!.trim(),
          source: 'Saved Primary Visual',
          positionTag: 'PRIMARY VISUAL',
        ),
      ];
      _isLoading = false;
      _hasError = false;
      _currentIndex = 0;
      return;
    }

    // 3. No local visual exists: auto-fetch demonstration from web with single smooth shimmer
    _fetchDemonstrationImages();
  }

  @override
  void didUpdateWidget(covariant ExercisePositionSlideshow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseName != widget.exerciseName) {
      _initializeVisuals();
    } else if (oldWidget.currentImagePath != widget.currentImagePath &&
        widget.currentImagePath != null &&
        widget.currentImagePath!.isNotEmpty) {
      _syncPrimaryImage(widget.currentImagePath!);
    }
  }

  void _syncPrimaryImage(String newPath) {
    final existingIdx = _candidates.indexWhere((c) => c.thumbnailUrl == newPath);
    if (existingIdx >= 0) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(existingIdx);
      }
      setState(() {
        _currentIndex = existingIdx;
      });
    } else {
      final newCandidate = ExerciseImageCandidate(
        title: widget.exerciseName,
        thumbnailUrl: newPath,
        fullUrl: newPath,
        source: 'Primary Visual',
        positionTag: 'PRIMARY VISUAL',
      );
      setState(() {
        _candidates.insert(0, newCandidate);
        _currentIndex = 0;
      });
      if (_pageController.hasClients) {
        _pageController.jumpToPage(0);
      }
    }
  }

  @override
  void dispose() {
    _stopTimers();
    _pageController.dispose();
    super.dispose();
  }

  void _stopTimers() {
    _cycleTimer?.cancel();
    _cycleTimer = null;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  String _loadingLabel = '';

  Future<void> _fetchDemonstrationImages() async {
    _stopTimers();
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _loadingLabel = 'Searching: ${widget.exerciseName} gym exercise form...';
    });

    try {
      final results = await ExerciseImageSearchService.getExerciseDemonstrationImages(
        widget.exerciseName,
        currentImagePath: widget.currentImagePath,
      );

      if (!mounted) return;

      if (results.isNotEmpty) {
        setState(() {
          _loadingLabel = 'Loading exercise demonstration...';
        });

        // Pre-cache the first network image BEFORE switching _isLoading to false.
        // This eliminates the double-shimmer and vertical layout shift completely.
        final firstUrl = results.first.thumbnailUrl;
        if (firstUrl.startsWith('http://') || firstUrl.startsWith('https://')) {
          try {
            await precacheImage(
              NetworkImage(firstUrl),
              context,
            ).timeout(const Duration(milliseconds: 2500));
          } catch (_) {
            // Precache timeout/error is non-fatal
          }
        }

        if (!mounted) return;

        setState(() {
          _candidates = results;
          _isLoading = false;
          _hasError = false;
          _currentIndex = 0;
          _retryAttempt = 0;
        });

        // Precache remaining slides in background for smooth swiping
        _precacheRemainingImages(results);

        _startAutoCycleTimer();
      } else {
        _handleFetchFailure();
      }
    } catch (_) {
      if (!mounted) return;
      _handleFetchFailure();
    }
  }

  void _precacheRemainingImages(List<ExerciseImageCandidate> list) {
    if (list.length <= 1) return;
    for (int i = 1; i < list.length; i++) {
      final url = list[i].thumbnailUrl;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        try {
          precacheImage(NetworkImage(url), context).catchError((_) {});
        } catch (_) {}
      }
    }
  }

  void _handleFetchFailure() {
    setState(() {
      _isLoading = false;
      _hasError = true;
    });

    if (_retryAttempt < _maxRetries) {
      _retryAttempt++;
      _retrySecondsLeft = 3;
      _retryTimer?.cancel();
      _retryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _retrySecondsLeft--;
        });
        if (_retrySecondsLeft <= 0) {
          timer.cancel();
          _fetchDemonstrationImages();
        }
      });
    }
  }

  void _startAutoCycleTimer() {
    _cycleTimer?.cancel();
    if (_candidates.length <= 1) return;

    _cycleTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted || _isUserInteracting || !_pageController.hasClients) return;
      final nextIndex = (_currentIndex + 1) % _candidates.length;
      _pageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    if (!mounted) return;
    setState(() {
      _currentIndex = index;
    });
  }

  void _pinCurrentVisual() {
    if (_candidates.isEmpty) return;
    final current = _candidates[_currentIndex];
    AppHaptics.save();
    widget.onImageSelected?.call(current.thumbnailUrl);

    setState(() {
      _isSavedFeedback = true;
    });
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) {
        setState(() {
          _isSavedFeedback = false;
        });
      }
    });
  }

  void _openGoogleImages() {
    AppHaptics.tap();
    ExerciseWebSearchSheet.show(
      context,
      exerciseName: '${widget.exerciseName} gym exercise form',
      startWithImages: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: widget.height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF131418) : const Color(0xFFF4F4F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF2E313D) : const Color(0xFFE2E4EB),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          child: _isLoading
              ? KeyedSubtree(
                  key: const ValueKey('slideshow_loading'),
                  child: _buildLoadingState(isDark),
                )
              : _hasError && _candidates.isEmpty
                  ? KeyedSubtree(
                      key: const ValueKey('slideshow_error'),
                      child: _buildErrorState(isDark),
                    )
                  : KeyedSubtree(
                      key: const ValueKey('slideshow_content'),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Content Area (Carousel)
                          _buildSlideshowCarousel(isDark),

                          // 2. Top Header Badges (Position status & Muscle tag)
                          Positioned(
                            top: 10,
                            left: 12,
                            right: 12,
                            child: _buildHeaderBadges(isDark),
                          ),

                          // 3. Saved Feedback Banner Overlay
                          if (_isSavedFeedback)
                            Positioned(
                              top: 50,
                              child: _buildSavedBanner(),
                            ),

                          // 4. Bottom Controls Bar (Dots indicator, Pin visual, Change image)
                          Positioned(
                            bottom: 8,
                            left: 12,
                            right: 12,
                            child: _buildBottomControls(isDark),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Container(
      width: double.infinity,
      height: widget.height,
      padding: const EdgeInsets.fromLTRB(16, 36, 16, 36),
      alignment: Alignment.center,
      child: ShimmerLoading(
        width: double.infinity,
        height: double.infinity,
        borderRadius: BorderRadius.circular(12),
        label: _loadingLabel.isNotEmpty
            ? _loadingLabel
            : 'Searching: ${widget.exerciseName} gym exercise form...',
      ),
    );
  }

  Widget _buildSavedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: Colors.white),
          SizedBox(width: 6),
          Text(
            'Set as default exercise visual',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBadges(bool isDark) {
    if (_candidates.isEmpty) return const SizedBox.shrink();
    final candidate = _candidates[_currentIndex.clamp(0, _candidates.length - 1)];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Position tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF1E212A) : Colors.white).withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentIndex == 0 ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                candidate.positionTag ??
                    'POSITION ${_currentIndex + 1} OF ${_candidates.length}',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
        ),

        // Muscle Group tag
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            widget.muscleGroupId.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.0,
              fontWeight: FontWeight.w800,
              color: Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls(bool isDark) {
    if (_candidates.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Slide Indicators
        if (_candidates.length > 1)
          Row(
            children: List.generate(_candidates.length, (idx) {
              final isSelected = idx == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: isSelected ? 16 : 5,
                height: 5,
                decoration: BoxDecoration(
                  color: isSelected
                      ? context.accent
                      : (isDark ? Colors.white24 : Colors.black26),
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          )
        else
          const SizedBox(width: 8),

        // Action buttons
        Row(
          children: [
            // Pin visual button
            ScaleTap(
              onPressed: _pinCurrentVisual,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (isDark ? const Color(0xFF1E212A) : Colors.white).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: context.accent.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bookmark_added_outlined, size: 13, color: context.accent),
                    const SizedBox(width: 4),
                    Text(
                      'Set Primary',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Change image picker button
            if (widget.onChangeImage != null)
              ScaleTap(
                onPressed: widget.onChangeImage!,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: (isDark ? const Color(0xFF1E212A) : Colors.white).withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_outlined, size: 13, color: context.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Change',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: context.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    final isRetrying = _retryAttempt < _maxRetries;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF272935) : const Color(0xFFE5E7EB)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.image_search_rounded,
                size: 22,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Visual demonstration unavailable',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isRetrying
                  ? 'Auto-retrying in ${_retrySecondsLeft}s... (Attempt $_retryAttempt of $_maxRetries)'
                  : 'Check connection or browse live image guides on Google',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: context.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTap(
                  onPressed: () {
                    _retryAttempt = 0;
                    _fetchDemonstrationImages();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.accent.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.refresh_rounded, size: 14, color: context.accent),
                        const SizedBox(width: 4),
                        Text(
                          'Retry Now',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: context.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ScaleTap(
                  onPressed: _openGoogleImages,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: (isDark ? const Color(0xFF222430) : const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.open_in_browser_rounded, size: 14, color: context.textPrimary),
                        const SizedBox(width: 4),
                        Text(
                          'Google Search',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlideshowCarousel(bool isDark) {
    return Listener(
      onPointerDown: (_) => _isUserInteracting = true,
      onPointerUp: (_) => _isUserInteracting = false,
      onPointerCancel: (_) => _isUserInteracting = false,
      child: PageView.builder(
        controller: _pageController,
        onPageChanged: _onPageChanged,
        itemCount: _candidates.length,
        itemBuilder: (context, index) {
          final candidate = _candidates[index];
          final url = candidate.thumbnailUrl;

          return Container(
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 36),
            alignment: Alignment.center,
            child: _buildImageItem(url, isDark),
          );
        },
      ),
    );
  }

  Widget _buildImageItem(String path, bool isDark) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return ShimmerLoading(
            width: double.infinity,
            height: double.infinity,
            borderRadius: BorderRadius.circular(12),
            label: 'Loading position image...',
          );
        },
        errorBuilder: (context, error, stackTrace) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.broken_image_outlined, size: 36, color: context.textSecondary),
            const SizedBox(height: 6),
            Text(
              'Failed to load position image',
              style: TextStyle(fontSize: 11, color: context.textSecondary),
            ),
          ],
        ),
      );
    }

    final file = File(path);
    if (file.existsSync()) {
      return Image.file(
        file,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center_rounded, size: 42),
      );
    }

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => const Icon(Icons.fitness_center_rounded, size: 42),
      );
    }

    return const Icon(Icons.fitness_center_rounded, size: 42);
  }
}
