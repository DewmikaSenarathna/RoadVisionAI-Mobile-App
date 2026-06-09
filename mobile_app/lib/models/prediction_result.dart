class PredictionResult {
  const PredictionResult({
    required this.mode,
    required this.riskLevel,
    required this.riskColor,
    required this.confidence,
    required this.reasons,
    required this.drivingAdvice,
    required this.liveContext,
    required this.inputs,
    required this.engine,
  });

  final String mode;
  final String riskLevel;
  final String riskColor;
  final double confidence;
  final List<String> reasons;
  final List<String> drivingAdvice;
  final Map<String, dynamic> liveContext;
  final Map<String, dynamic> inputs;
  final String? engine;

  bool get isFallback => engine == 'heuristic';

  factory PredictionResult.fromJson(Map<String, dynamic> json) {
    return PredictionResult(
      mode: (json['mode'] ?? 'unknown').toString(),
      riskLevel: (json['risk_level'] ?? 'Medium').toString(),
      riskColor: (json['risk_color'] ?? '#ffbf47').toString(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      reasons: (json['reasons'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList(),
      drivingAdvice: (json['driving_advice'] as List<dynamic>? ?? const []).map((item) => item.toString()).toList(),
      liveContext: Map<String, dynamic>.from(json['live_context'] as Map? ?? const {}),
      inputs: Map<String, dynamic>.from(json['inputs'] as Map? ?? const {}),
      engine: json['engine']?.toString(),
    );
  }
}

class HealthSnapshot {
  const HealthSnapshot({
    required this.status,
    required this.loadedFeatures,
    required this.modelReady,
    required this.preprocessorReady,
    required this.modelSource,
    required this.timestamp,
  });

  final String status;
  final int loadedFeatures;
  final bool modelReady;
  final bool preprocessorReady;
  final String modelSource;
  final String timestamp;

  factory HealthSnapshot.fromJson(Map<String, dynamic> json) {
    return HealthSnapshot(
      status: (json['status'] ?? 'unknown').toString(),
      loadedFeatures: (json['loaded_features'] as num?)?.toInt() ?? 0,
      modelReady: json['model_ready'] == true,
      preprocessorReady: json['preprocessor_ready'] == true,
      modelSource: (json['model_source'] ?? 'fallback').toString(),
      timestamp: (json['timestamp'] ?? '').toString(),
    );
  }
}