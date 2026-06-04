import 'package:flutter/material.dart';

import '../models/prediction_result.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.result,
    required this.sourceLabel,
  });

  final PredictionResult result;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    final riskColor = Color(_hexToArgb(result.riskColor));
    return Scaffold(
      appBar: AppBar(
        title: Text('$sourceLabel Prediction Result'),
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF06131B), Color(0xFF041017)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _SummaryCard(result: result, accent: riskColor),
              const SizedBox(height: 18),
              _DetailsCard(result: result),
              const SizedBox(height: 18),
              _AdviceCard(advice: result.drivingAdvice),
              const SizedBox(height: 18),
              _FooterCard(sourceLabel: sourceLabel, result: result),
            ],
          ),
        ),
      ),
    );
  }

  int _hexToArgb(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final fullHex = normalized.length == 6 ? 'FF$normalized' : normalized;
    return int.parse(fullHex, radix: 16);
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.result, required this.accent});

  final PredictionResult result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final riskColor = Color(_hexToArgb(result.riskColor));
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Risk level', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  result.riskLevel,
                  style: TextStyle(color: riskColor, fontWeight: FontWeight.w700),
                ),
              ),
              const Spacer(),
              Text(
                '${result.confidence.toStringAsFixed(1)}% confidence',
                style: TextStyle(color: Colors.white.withOpacity(0.72)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Predicted using live model data and the current driving context.',
            style: TextStyle(color: Colors.white.withOpacity(0.72)),
          ),
        ],
      ),
    );
  }

  int _hexToArgb(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final fullHex = normalized.length == 6 ? 'FF$normalized' : normalized;
    return int.parse(fullHex, radix: 16);
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.result});

  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    final details = <Map<String, String>>[
      {'label': 'Mode', 'value': result.mode},
      {'label': 'Engine', 'value': result.engine ?? 'model'},
      {'label': 'Location', 'value': _formatLocation(result.inputs)},
      {'label': 'Weather', 'value': result.liveContext['weather_summary'] ?? 'N/A'},
      {'label': 'Road', 'value': result.liveContext['road_summary'] ?? 'N/A'},
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Prediction details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...details.map(
            (detail) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      detail['label']!,
                      style: TextStyle(color: Colors.white.withOpacity(0.62)),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      detail['value']!,
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLocation(Map<String, dynamic> inputs) {
    final lat = inputs['Start_Lat'];
    final lng = inputs['Start_Lng'];
    if (lat == null || lng == null) {
      return 'Unknown';
    }
    return '${double.tryParse(lat.toString())?.toStringAsFixed(4) ?? '--'}, ${double.tryParse(lng.toString())?.toStringAsFixed(4) ?? '--'}';
  }
}

class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.advice});

  final List<String> advice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.04),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Driving advice', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 14),
          ...advice.map((text) => _BulletLine(text: text)),
        ],
      ),
    );
  }
}

class _FooterCard extends StatelessWidget {
  const _FooterCard({required this.sourceLabel, required this.result});

  final String sourceLabel;
  final PredictionResult result;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.03),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Safety summary', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          Text(
            'This snapshot used the most recent live weather and road condition data to generate the prediction. Continue with the same route if the risk appears low, or adjust your driving behavior based on the advice above.',
            style: TextStyle(color: Colors.white.withOpacity(0.72)) ,
          ),
        ],
      ),
    );
  }
}

class _BulletLine extends StatelessWidget {
  const _BulletLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6),
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF67EAD6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
