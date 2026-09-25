import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/haptics.dart';
import '../../../../core/utils/url_launcher_utils.dart';

/// In-App Google Search & Image Viewer for exercises
/// Displays live Google Image Search and Web results inside the app
/// with full touch scrolling, gesture recognition, and responsive navigation.
class ExerciseWebSearchSheet extends StatefulWidget {
  final String exerciseName;
  final bool startWithImages;

  const ExerciseWebSearchSheet({
    super.key,
    required this.exerciseName,
    this.startWithImages = true,
  });

  static void show(
    BuildContext context, {
    required String exerciseName,
    bool startWithImages = true,
  }) {
    AppHaptics.tap();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false, // Ensures WebView captures all vertical scrolling gestures
      backgroundColor: Colors.transparent,
      builder: (ctx) => ExerciseWebSearchSheet(
        exerciseName: exerciseName,
        startWithImages: startWithImages,
      ),
    );
  }

  @override
  State<ExerciseWebSearchSheet> createState() => _ExerciseWebSearchSheetState();
}

class _ExerciseWebSearchSheetState extends State<ExerciseWebSearchSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _loadingProgress = 0.0;
  late bool _isImagesTab;
  bool _canGoBack = false;
  bool _canGoForward = false;

  String _buildUrl(bool images) {
    final query = Uri.encodeComponent('${widget.exerciseName} gym exercise form');
    if (images) {
      return 'https://www.google.com/search?tbm=isch&q=$query';
    } else {
      return 'https://www.google.com/search?q=$query';
    }
  }

  @override
  void initState() {
    super.initState();
    _isImagesTab = widget.startWithImages;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) {
              setState(() {
                _loadingProgress = progress / 100.0;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (_) async {
            if (mounted) setState(() => _isLoading = true);
            _updateNavState();
          },
          onPageFinished: (_) async {
            if (mounted) setState(() => _isLoading = false);
            _updateNavState();
          },
          onWebResourceError: (error) {
            if (mounted) setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(_buildUrl(_isImagesTab)));
  }

  Future<void> _updateNavState() async {
    final canBack = await _controller.canGoBack();
    final canFwd = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = canBack;
        _canGoForward = canFwd;
      });
    }
  }

  void _switchTab(bool images) {
    if (_isImagesTab == images) return;
    AppHaptics.step();
    setState(() {
      _isImagesTab = images;
    });
    _controller.loadRequest(Uri.parse(_buildUrl(images)));
  }

  Future<void> _openExternal() async {
    AppHaptics.tap();
    final currentUrl = await _controller.currentUrl() ?? _buildUrl(_isImagesTab);
    await UrlLauncherUtils.openUrl(currentUrl);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: context.sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: context.sheetBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          // Top Header Area (swiping down here allows closing)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 250) {
                Navigator.of(context).pop();
              }
            },
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.handleBar,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Header row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Google Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2E) : const Color(0xFFF1F1F5),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'G',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                color: Color(0xFF4285F4),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Google',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          widget.exerciseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.fontFamilyDisplay,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: context.textPrimary,
                          ),
                        ),
                      ),

                      // External browser icon
                      IconButton(
                        tooltip: 'Open in Chrome',
                        icon: Icon(Icons.open_in_new_rounded, size: 17, color: context.textSecondary),
                        onPressed: _openExternal,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),

                      // Close button
                      IconButton(
                        icon: Icon(Icons.close_rounded, size: 19, color: context.textSecondary),
                        onPressed: () => Navigator.of(context).pop(),
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),

                // Search Mode Pill Tabs (Images vs All Results) & Web Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 12, 6),
                  child: Row(
                    children: [
                      // Tab: Images
                      _buildTabButton(
                        title: 'Images',
                        isActive: _isImagesTab,
                        onTap: () => _switchTab(true),
                      ),
                      const SizedBox(width: 6),

                      // Tab: All / Form Guides
                      _buildTabButton(
                        title: 'Guides',
                        isActive: !_isImagesTab,
                        onTap: () => _switchTab(false),
                      ),

                      const Spacer(),

                      // Back button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded, size: 13),
                        color: _canGoBack ? context.textPrimary : context.textSecondary.withValues(alpha: 0.3),
                        onPressed: _canGoBack ? () => _controller.goBack() : null,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                      ),

                      // Forward button
                      IconButton(
                        icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
                        color: _canGoForward ? context.textPrimary : context.textSecondary.withValues(alpha: 0.3),
                        onPressed: _canGoForward ? () => _controller.goForward() : null,
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                      ),

                      // Reload button
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded, size: 17),
                        color: context.textSecondary,
                        onPressed: () => _controller.reload(),
                        constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                        padding: EdgeInsets.zero,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Loading bar
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadingProgress > 0 ? _loadingProgress : null,
              minHeight: 2.0,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF4285F4)),
            )
          else
            const SizedBox(height: 2),

          // WebView content with EagerGestureRecognizer for 100% fluid touch scrolling
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
              child: WebViewWidget(
                controller: _controller,
                gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                  Factory<OneSequenceGestureRecognizer>(
                    () => EagerGestureRecognizer(),
                  ),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton({
    required String title,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? (isDark ? Colors.white : const Color(0xFF1E1E22))
              : (isDark ? const Color(0xFF222226) : const Color(0xFFEDEDF2)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isActive
                ? (isDark ? Colors.black : Colors.white)
                : context.textSecondary,
          ),
        ),
      ),
    );
  }
}
