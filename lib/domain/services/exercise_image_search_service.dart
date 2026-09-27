import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class ExerciseImageCandidate {
  final String title;
  final String thumbnailUrl;
  final String fullUrl;
  final String source;
  final String? positionTag;

  const ExerciseImageCandidate({
    required this.title,
    required this.thumbnailUrl,
    required this.fullUrl,
    this.source = 'Web Search',
    this.positionTag,
  });
}

class ExerciseImageSearchService {
  static const Map<String, String> _webHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
  };

  static final Map<String, List<ExerciseImageCandidate>> _memorySearchCache = {};

  /// Pre-populates the cache for testing to prevent network requests.
  static void setSearchCacheForTesting(String exerciseName, List<ExerciseImageCandidate> results) {
    _memorySearchCache[exerciseName.trim().toLowerCase()] = results;
  }

  /// Searches the web dynamically for exercise demonstration images using:
  /// "[exerciseName] gym exercise form"
  static Future<List<ExerciseImageCandidate>> searchWebExerciseImages(String exerciseName) async {
    final clean = exerciseName.trim();
    if (clean.isEmpty) return [];

    final cacheKey = clean.toLowerCase();
    if (_memorySearchCache.containsKey(cacheKey) && _memorySearchCache[cacheKey]!.isNotEmpty) {
      return _memorySearchCache[cacheKey]!;
    }

    final query = '$clean gym exercise form';
    final url = Uri.parse(
      'https://www.bing.com/images/search?q=${Uri.encodeComponent(query)}&FORM=HDRSC2',
    );

    try {
      final response = await http
          .get(url, headers: _webHeaders)
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final html = response.body;
        final murlRegex = RegExp(r'&quot;murl&quot;:&quot;(https://[^&]+)&quot;');
        final titleRegex = RegExp(r'&quot;t&quot;:&quot;([^&]+)&quot;');

        final murlMatches = murlRegex.allMatches(html).toList();
        final titleMatches = titleRegex.allMatches(html).toList();

        final List<ExerciseImageCandidate> candidates = [];
        final Set<String> seenUrls = {};

        for (int i = 0; i < murlMatches.length && candidates.length < 8; i++) {
          final imgUrl = murlMatches[i].group(1);
          if (imgUrl == null || seenUrls.contains(imgUrl)) continue;

          final lower = imgUrl.toLowerCase();
          // Filter out SVG logos, icons, user avatars, or ad tracking pixels
          if (lower.endsWith('.svg') ||
              lower.contains('logo') ||
              lower.contains('avatar') ||
              lower.contains('icon') ||
              lower.contains('tracker')) {
            continue;
          }

          seenUrls.add(imgUrl);
          String title = i < titleMatches.length
              ? (titleMatches[i].group(1) ?? '$clean Form')
              : '$clean Form';
          title = title
              .replaceAll('&quot;', '"')
              .replaceAll('&#39;', "'")
              .replaceAll('&amp;', '&');

          final tag = candidates.isEmpty ? 'STARTING POSITION' : 'FORM DEMONSTRATION';

          candidates.add(
            ExerciseImageCandidate(
              title: title,
              thumbnailUrl: imgUrl,
              fullUrl: imgUrl,
              source: 'Web Search',
              positionTag: tag,
            ),
          );
        }

        if (candidates.isNotEmpty) {
          _memorySearchCache[cacheKey] = candidates;
          return candidates;
        }
      }
    } catch (_) {}

    // Fallback: Wikimedia Commons query with the exact gym exercise form query
    final fallbackCandidates = await _searchWikimediaPositionImages(clean);
    if (fallbackCandidates.isNotEmpty) {
      _memorySearchCache[cacheKey] = fallbackCandidates;
      return fallbackCandidates;
    }

    return [];
  }

  /// Automatically retrieves high-quality position demonstration visuals for an exercise
  static Future<List<ExerciseImageCandidate>> getExerciseDemonstrationImages(
    String exerciseName, {
    String? currentImagePath,
  }) async {
    final clean = exerciseName.trim();
    if (clean.isEmpty) return [];

    final List<ExerciseImageCandidate> candidates = [];

    // 1. Current custom image if present
    if (currentImagePath != null && currentImagePath.isNotEmpty) {
      candidates.add(
        ExerciseImageCandidate(
          title: '$clean (Active Selection)',
          thumbnailUrl: currentImagePath,
          fullUrl: currentImagePath,
          source: 'Current Selected Visual',
          positionTag: 'ACTIVE SELECTION',
        ),
      );
    }

    // 2. Perform web image search for "$exerciseName gym exercise form"
    final webResults = await searchWebExerciseImages(clean);
    for (final r in webResults) {
      if (!candidates.any((c) => c.thumbnailUrl == r.thumbnailUrl)) {
        candidates.add(r);
      }
    }

    return candidates;
  }

  /// Searches candidate images with position demonstration priority
  static Future<List<ExerciseImageCandidate>> searchCandidateImages(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return [];

    return searchWebExerciseImages(clean);
  }

  static Future<List<ExerciseImageCandidate>> _searchWikimediaPositionImages(String clean) async {
    try {
      final searchTerm = '$clean gym exercise form';
      final endpoint = Uri.parse(
        'https://commons.wikimedia.org/w/api.php?'
        'action=query&'
        'generator=search&'
        'gsrnamespace=6&'
        'gsrsearch=${Uri.encodeComponent(searchTerm)}&'
        'gsrlimit=8&'
        'prop=imageinfo&'
        'iiprop=url|mime|size&'
        'iiurlwidth=500&'
        'format=json',
      );

      final response = await http.get(endpoint, headers: {
        'User-Agent': 'IronLogGymApp/1.0 (fitness workout tracker; offline-first; contact@ironlog.app)',
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return [];

      final data = json.decode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final pages = data['query']?['pages'] as Map<String, dynamic>?;
      if (pages == null) return [];

      final List<ExerciseImageCandidate> candidates = [];
      final validMimes = {'image/jpeg', 'image/png', 'image/webp'};

      for (final rawPage in pages.values) {
        final page = rawPage as Map<String, dynamic>;
        final infos = page['imageinfo'] as List<dynamic>?;
        if (infos == null || infos.isEmpty) continue;

        final info = infos.first as Map<String, dynamic>;
        final mime = (info['mime'] as String? ?? '').toLowerCase();
        if (!validMimes.any((m) => mime.startsWith(m))) continue;

        final thumbUrl = info['thumburl'] as String? ?? info['url'] as String?;
        final fullUrl = info['url'] as String? ?? thumbUrl;
        if (thumbUrl == null || thumbUrl.isEmpty) continue;

        String rawTitle = page['title'] as String? ?? 'Exercise Image';
        if (rawTitle.startsWith('File:')) rawTitle = rawTitle.substring(5);

        final lower = rawTitle.toLowerCase();
        if (lower.endsWith('.pdf') ||
            lower.endsWith('.djvu') ||
            lower.contains('manual') ||
            lower.contains('catalogue')) {
          continue;
        }

        final cleanTitle = rawTitle.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');

        candidates.add(
          ExerciseImageCandidate(
            title: cleanTitle,
            thumbnailUrl: thumbUrl,
            fullUrl: fullUrl ?? thumbUrl,
            source: 'Wikimedia Commons',
            positionTag: 'FORM DEMONSTRATION',
          ),
        );
      }

      return candidates;
    } catch (_) {
      return [];
    }
  }

  /// Downloads an online image and caches it permanently in the local app documents directory
  static Future<String?> downloadAndCacheImage({
    required String exerciseId,
    required String imageUrl,
  }) async {
    try {
      final response = await http.get(Uri.parse(imageUrl), headers: _webHeaders).timeout(
        const Duration(seconds: 10),
      );

      if (response.statusCode != 200) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/exercise_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final ext = imageUrl.toLowerCase().contains('.png') ? 'png' : 'jpg';
      final fileName = '${exerciseId}_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final localFile = File('${imagesDir.path}/$fileName');

      await localFile.writeAsBytes(response.bodyBytes);
      return localFile.path;
    } catch (_) {
      return imageUrl;
    }
  }

  /// Lets the user select an image from their local photo gallery
  static Future<String?> pickImageFromGallery({required String exerciseId}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );

      if (picked == null) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/exercise_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${exerciseId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destination = File('${imagesDir.path}/$fileName');
      await File(picked.path).copy(destination.path);

      return destination.path;
    } catch (_) {
      return null;
    }
  }

  /// Lets the user take a live photo using device camera
  static Future<String?> pickImageFromCamera({required String exerciseId}) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );

      if (picked == null) return null;

      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/exercise_images');
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      final fileName = '${exerciseId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destination = File('${imagesDir.path}/$fileName');
      await File(picked.path).copy(destination.path);

      return destination.path;
    } catch (_) {
      return null;
    }
  }
}
