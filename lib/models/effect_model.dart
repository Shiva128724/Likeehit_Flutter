import 'dart:math';

class EffectModel {
  final String id;
  final String name;
  final String owner;
  final String thumbnailUrl;
  final List<double> matrix;

  EffectModel({
    required this.id,
    required this.name,
    required this.owner,
    required this.thumbnailUrl,
    required this.matrix,
  });
}

class EffectService {
  /// Fetches a paginated list of mock effects, capped at 500 total to simulate a large database.
  static Future<List<EffectModel>> fetchEffects(
    int page,
    int limit, {
    String category = 'Trending',
  }) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 400));

    List<EffectModel> effects = [];
    int start = page * limit;
    int end = start + limit;

    final random = Random(
      start,
    ); // pseudo-random seed based on start index for consistency

    for (int i = start; i < end; i++) {
      if (i >= 500) break; // Hard cap at 500 effects

      // Generate distinct color matrices
      double rScale = 0.5 + random.nextDouble();
      double gScale = 0.5 + random.nextDouble();
      double bScale = 0.5 + random.nextDouble();

      effects.add(
        EffectModel(
          id: 'effect_${category.toLowerCase()}_$i',
          name: 'Filter $i ($category)',
          owner: i % 7 == 0 ? 'Zohan 🇮🇳' : 'Creator${i % 20}',
          thumbnailUrl: 'https://picsum.photos/seed/${category}_$i/150/150',
          matrix: [
            rScale,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            gScale,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            bScale,
            0.0,
            0.0,
            0.0,
            0.0,
            0.0,
            1.0,
            0.0,
          ],
        ),
      );
    }

    return effects;
  }
}
