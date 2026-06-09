import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/backend_config.dart';
import '../models/prediction_result.dart';
import '../services/roadvision_api.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late RoadVisionApiService _service;
  final TextEditingController _apiBaseUrlController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController(text: '37.7749');
  final TextEditingController _longitudeController = TextEditingController(text: '-122.4194');
  final TextEditingController _distanceController = TextEditingController(text: '0.8');
  final TextEditingController _speedController = TextEditingController(text: '28');

  bool _loading = false;
  String _connectionStatus = 'Checking backend';
  HealthSnapshot? _health;
  PredictionResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBackendUrl();
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _distanceController.dispose();
    _speedController.dispose();
    super.dispose();
  }

  Future<void> _loadHealth() async {
    try {
      final health = await _service.fetchHealth();
      if (!mounted) {
        return;
      }
      setState(() {
        _health = health;
        _connectionStatus = health.status == 'ok' ? 'Connected' : 'Degraded';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _connectionStatus = 'Offline';
        _errorMessage = error.toString();
      });
    }
  }

  Future<void> _loadBackendUrl() async {
    final savedUrl = await BackendConfig.loadBackendUrl();
    _apiBaseUrlController.text = savedUrl;
    _service = RoadVisionApiService(baseUrl: savedUrl);
    if (mounted) {
      setState(() {});
    }
    await _loadHealth();
  }

  Future<void> _saveBackendUrl() async {
    final urlValue = _apiBaseUrlController.text.trim();
    if (urlValue.isEmpty) {
      _showSnackBar('Enter a valid backend URL.');
      return;
    }
    final uri = Uri.tryParse(urlValue);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      _showSnackBar('Enter a valid http:// or https:// URL.');
      return;
    }

    await BackendConfig.saveBackendUrl(urlValue);
    _service = RoadVisionApiService(baseUrl: urlValue);
    _showSnackBar('Backend URL saved. Rechecking connection...');
    setState(() {
      _connectionStatus = 'Checking backend';
      _health = null;
      _errorMessage = null;
    });
    await _loadHealth();
  }

  Future<void> _runPrediction({required bool snapshotMode}) async {
    final latitude = double.tryParse(_latitudeController.text.trim());
    final longitude = double.tryParse(_longitudeController.text.trim());
    final distanceMi = double.tryParse(_distanceController.text.trim());
    final speedMph = double.tryParse(_speedController.text.trim());

    if (latitude == null || longitude == null || distanceMi == null) {
      _showSnackBar('Enter valid latitude, longitude, and distance values.');
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final result = snapshotMode
          ? await _service.predictSnapshot(
              latitude: latitude,
              longitude: longitude,
              distanceMi: distanceMi,
              speedMph: speedMph,
            )
          : await _service.predictAuto(
              latitude: latitude,
              longitude: longitude,
              distanceMi: distanceMi,
              speedMph: speedMph,
            );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.toString();
      });
      _showSnackBar('Prediction failed. Check the backend connection.');
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _riskColor(PredictionResult result) {
    return Color(_hexToArgb(result.riskColor));
  }

  int _hexToArgb(String hex) {
    final normalized = hex.replaceFirst('#', '');
    final fullHex = normalized.length == 6 ? 'FF$normalized' : normalized;
    return int.parse(fullHex, radix: 16);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final color = result == null ? theme.colorScheme.primary : _riskColor(result);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06131B), Color(0xFF04070B)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(
                  status: _connectionStatus,
                  title: AppConfig.appName,
                  subtitle: 'Mobile risk cockpit for accident prediction',
                ),
                const SizedBox(height: 16),
                _BackendUrlCard(
                  controller: _apiBaseUrlController,
                  onSave: _saveBackendUrl,
                ),
                const SizedBox(height: 18),
                _InfoStrip(
                  health: _health,
                  status: _connectionStatus,
                ),
                const SizedBox(height: 18),
                _FormCard(
                  latitudeController: _latitudeController,
                  longitudeController: _longitudeController,
                  distanceController: _distanceController,
                  speedController: _speedController,
                  loading: _loading,
                  onAuto: () => _runPrediction(snapshotMode: false),
                  onSnapshot: () => _runPrediction(snapshotMode: true),
                ),
                const SizedBox(height: 18),
                AnimatedOpacity(
                  opacity: result == null ? 0.5 : 1,
                  duration: const Duration(milliseconds: 220),
                  child: _ResultCard(result: result, accent: color),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  _StatusCard(message: _errorMessage!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.status, required this.title, required this.subtitle});

  final String status;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0D2331), Color(0xFF08161F)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 48,
                  height: 48,
                  color: const Color(0xFF041019),
                  child: Image.asset(
                    'assets/roadvisionai_logo.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.displaySmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatusPill(label: 'Backend', value: status),
              const SizedBox(width: 10),
              _StatusPill(label: 'Mode', value: 'Mobile'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BackendUrlCard extends StatelessWidget {
  const _BackendUrlCard({required this.controller, required this.onSave});

  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: const Color(0xFF0F1A24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Backend URL',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white.withOpacity(0.84), fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              hintText: 'http://192.168.1.100:8000',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onSave,
            child: const Text('Save backend URL'),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.health, required this.status});

  final HealthSnapshot? health;
  final String status;

  @override
  Widget build(BuildContext context) {
    final items = <_MiniMetric>[
      _MiniMetric(label: 'Features', value: '${health?.loadedFeatures ?? 0}'),
      _MiniMetric(label: 'Model', value: health?.modelSource ?? 'unknown'),
      _MiniMetric(label: 'Engine', value: health?.modelReady == true ? 'Ready' : 'Fallback'),
      _MiniMetric(label: 'State', value: status),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: items
          .map(
            (item) => SizedBox(
              width: (MediaQuery.of(context).size.width - 52) / 2,
              child: _MetricCard(metric: item),
            ),
          )
          .toList(),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.latitudeController,
    required this.longitudeController,
    required this.distanceController,
    required this.speedController,
    required this.loading,
    required this.onAuto,
    required this.onSnapshot,
  });

  final TextEditingController latitudeController;
  final TextEditingController longitudeController;
  final TextEditingController distanceController;
  final TextEditingController speedController;
  final bool loading;
  final VoidCallback onAuto;
  final VoidCallback onSnapshot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A26),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Route inputs', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Send coordinates and route context to the backend.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.66)),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _NumberField(label: 'Latitude', controller: latitudeController)),
              const SizedBox(width: 12),
              Expanded(child: _NumberField(label: 'Longitude', controller: longitudeController)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _NumberField(label: 'Distance mi', controller: distanceController)),
              const SizedBox(width: 12),
              Expanded(child: _NumberField(label: 'Speed mph', controller: speedController)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: loading ? null : onAuto,
                  icon: const Icon(Icons.auto_awesome),
                  label: Text(loading ? 'Working' : 'Auto score'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: loading ? null : onSnapshot,
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(loading ? 'Working' : 'Snapshot'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result, required this.accent});

  final PredictionResult? result;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    if (result == null) {
      return _StatusCard(message: 'Run a prediction to view the risk summary.');
    }

    final current = result!;
    final confidence = current.confidence.clamp(0, 100) / 100;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A26),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Prediction result', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    current.mode.toUpperCase(),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.72)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accent.withValues(alpha: 0.32)),
                ),
                child: Text(
                  current.riskLevel,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: confidence,
              minHeight: 12,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 12),
          Text('Confidence ${(current.confidence).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          if (current.liveContext.isNotEmpty) ...[
            _ContextRow(label: 'Weather', value: current.liveContext['weather_summary']?.toString() ?? '--'),
            _ContextRow(label: 'Road', value: current.liveContext['road_summary']?.toString() ?? '--'),
            _ContextRow(label: 'Updated', value: current.liveContext['timestamp']?.toString() ?? '--'),
            const SizedBox(height: 8),
          ],
          Text('Why this risk', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...current.reasons.map((item) => _BulletLine(text: item)),
          const SizedBox(height: 14),
          Text('Driving advice', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...current.drivingAdvice.map((item) => _BulletLine(text: item)),
          if (current.isFallback) ...[
            const SizedBox(height: 14),
            Text(
              'Heuristic fallback active because the saved model was not loaded.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A26),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Text(message, style: TextStyle(color: Colors.white.withValues(alpha: 0.78))),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});

  final _MiniMetric metric;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1A26),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(metric.label, style: TextStyle(color: Colors.white.withValues(alpha: 0.65))),
          const SizedBox(height: 6),
          Text(metric.value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: RichText(
        text: TextSpan(
          style: DefaultTextStyle.of(context).style,
          children: [
            TextSpan(text: '$label: ', style: TextStyle(color: Colors.white.withValues(alpha: 0.62))),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({required this.label, required this.controller});

  final String label;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.64))),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _MiniMetric {
  const _MiniMetric({required this.label, required this.value});

  final String label;
  final String value;
}