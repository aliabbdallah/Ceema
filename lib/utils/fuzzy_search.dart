import 'dart:math';

class FuzzySearch {
  /// Calculate the Levenshtein distance between two strings
  static int levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List<List<int>>.generate(
      s1.length + 1,
      (i) => List<int>.generate(s2.length + 1, (j) => 0),
    );

    for (var i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }
    for (var j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (var i = 1; i <= s1.length; i++) {
      for (var j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce(min);
      }
    }

    return matrix[s1.length][s2.length];
  }

  /// Calculate similarity score between two strings (0.0 to 1.0)
  static double similarityScore(String s1, String s2) {
    final distance = levenshteinDistance(s1.toLowerCase(), s2.toLowerCase());
    final maxLength = max(s1.length, s2.length);
    return maxLength == 0 ? 1.0 : 1.0 - (distance / maxLength);
  }

  /// Check if two strings are similar based on a threshold
  static bool isSimilar(String s1, String s2, {double threshold = 0.7}) {
    return similarityScore(s1, s2) >= threshold;
  }

  /// Find the best match from a list of strings
  static String? findBestMatch(String query, List<String> options, {double threshold = 0.7}) {
    if (options.isEmpty) return null;

    var bestMatch = options[0];
    var bestScore = similarityScore(query, bestMatch);

    for (var i = 1; i < options.length; i++) {
      final score = similarityScore(query, options[i]);
      if (score > bestScore) {
        bestScore = score;
        bestMatch = options[i];
      }
    }

    return bestScore >= threshold ? bestMatch : null;
  }
} 