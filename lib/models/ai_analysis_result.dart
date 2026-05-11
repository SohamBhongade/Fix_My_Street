/// Structured output returned by Gemini when analyzing a street-issue photo.
class AIAnalysisResult {
  final String category;
  final int severity;
  final String description;

  const AIAnalysisResult({
    required this.category,
    required this.severity,
    required this.description,
  });

  factory AIAnalysisResult.fromJson(Map<String, dynamic> json) {
    final rawSeverity = json['severity'];
    int parsedSeverity;
    if (rawSeverity is int) {
      parsedSeverity = rawSeverity;
    } else if (rawSeverity is double) {
      parsedSeverity = rawSeverity.round();
    } else {
      parsedSeverity = int.tryParse('${rawSeverity ?? 1}') ?? 1;
    }
    parsedSeverity = parsedSeverity.clamp(1, 10);

    return AIAnalysisResult(
      category: (json['category'] as String?)?.trim().isNotEmpty == true
          ? json['category'] as String
          : 'Unknown',
      severity: parsedSeverity,
      description: (json['description'] as String?)?.trim().isNotEmpty == true
          ? json['description'] as String
          : 'No description available.',
    );
  }

  Map<String, dynamic> toJson() => {
        'category': category,
        'severity': severity,
        'description': description,
      };

  static AIAnalysisResult fallback() => const AIAnalysisResult(
        category: 'Unknown',
        severity: 1,
        description:
            'AI analysis could not be completed. Please review manually.',
      );
}
