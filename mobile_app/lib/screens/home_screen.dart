import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/roadvision_api.dart';
import '../services/weather_service.dart';
import 'result_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final RoadVisionApiService _service = RoadVisionApiService();
  final WeatherService _weatherService = WeatherService();
  bool _loading = false;
  bool _autoRefreshing = false;
  String _status = 'Ready';
  String _locationText = '--';
  String _timeText = '--';
  String _weatherSummary = 'Waiting for live data';
  String _roadSummary = 'Road data unavailable';
  String _speedText = '-- mph';
  String _distanceText = '-- mi';
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final health = await _service.fetchHealth();
      if (!mounted) return;
      setState(() {
        _status = health.status == 'ok' ? 'Backend connected' : 'Backend degraded';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _status = 'Backend unavailable';
      });
    }
  }

  Future<Position> _requestLocationAndUpdate() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied) {
          throw Exception('Location permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permission denied forever');
      }

      if (!await Geolocator.isLocationServiceEnabled()) {
        throw Exception('Location services are disabled.');
      }

      final position = await Geolocator.getCurrentPosition();
      final now = DateTime.now();
      final speedMph = max(0.0, position.speed * 2.23694);
      final distanceMi = max(0.0, position.speed * 0.000621371 * 60);
      final weatherSummary = await _weatherService.fetchWeatherSummary(
        position.latitude,
        position.longitude,
      );

      if (!mounted) return position;
      setState(() {
        _locationText = '${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}';
        _timeText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        _speedText = '${speedMph.toStringAsFixed(1)} mph';
        _distanceText = '${distanceMi.toStringAsFixed(2)} mi';
        _weatherSummary = weatherSummary;
        _roadSummary = 'Traffic signal: false, Crosswalk: false, Construction zone: false, School zone: false';
      });
      return position;
    } catch (error) {
      if (!mounted) return Future.error(error);
      setState(() {
        _errorMessage = error.toString();
      });
      rethrow;
    }
  }

  Future<void> _predict({required bool automatically}) async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final position = await _requestLocationAndUpdate();
      final speedMph = max(0.0, position.speed * 2.23694);
      final distanceMi = max(0.0, position.speed * 0.000621371 * 60);

      final roadFeatures = {
        'traffic_signal': false,
        'crosswalk': false,
        'construction_zone': false,
        'school_zone': false,
      };

      final result = automatically
          ? await _service.predictAuto(
              latitude: position.latitude,
              longitude: position.longitude,
              distanceMi: distanceMi,
              speedMph: speedMph,
              roadFeatures: roadFeatures,
            )
          : await _service.predictSnapshot(
              latitude: position.latitude,
              longitude: position.longitude,
              distanceMi: distanceMi,
              speedMph: speedMph,
              roadFeatures: roadFeatures,
            );

      if (!mounted) return;
      setState(() {
        _weatherSummary = result.liveContext['weather_summary'] ?? _weatherSummary;
        _roadSummary = result.liveContext['road_summary'] ?? _roadSummary;
        _status = automatically ? 'Automatic refresh active' : 'Snapshot complete';
      });

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            result: result,
            sourceLabel: automatically ? 'Automatic' : 'Snapshot',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _startAutomatic() {
    if (_autoRefreshing) return;
    setState(() {
      _autoRefreshing = true;
      _status = 'Starting automatic prediction';
    });
    _predict(automatically: true).ignore();
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!_autoRefreshing) return;
      _predict(automatically: true).ignore();
    });
  }

  void _stopAutomatic() {
    _autoRefreshing = false;
    _refreshTimer?.cancel();
    setState(() {
      _status = 'Automatic mode stopped';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF06131B), Color(0xFF091724)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Row(
                children: [
                  Container(
                    height: 58,
                    width: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Image.asset('assets/roadvisionai_logo.png', fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RoadVisionAI', style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          'Live accident risk intelligence',
                          style: TextStyle(color: Colors.white.withOpacity(0.72)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _StatusBanner(status: _status),
              const SizedBox(height: 18),
              _SummaryPanel(
                location: _locationText,
                time: _timeText,
                weather: _weatherSummary,
                road: _roadSummary,
                speed: _speedText,
                distance: _distanceText,
              ),
              const SizedBox(height: 24),
              _ActionPanel(
                loading: _loading,
                autoMode: _autoRefreshing,
                onAutomatic: _startAutomatic,
                onAutomaticStop: _stopAutomatic,
                onSnapshot: _predictSnapshot,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 18),
                _ErrorPanel(message: _errorMessage!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _predictSnapshot() => _predict(automatically: false);
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF67EAD6)),
          const SizedBox(width: 12),
          Expanded(child: Text(status, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}

class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.location,
    required this.time,
    required this.weather,
    required this.road,
    required this.speed,
    required this.distance,
  });

  final String location;
  final String time;
  final String weather;
  final String road;
  final String speed;
  final String distance;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Current driving context', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _InfoTile(label: 'Location', value: location),
        const SizedBox(height: 12),
        _InfoTile(label: 'Time', value: time),
        const SizedBox(height: 12),
        _InfoTile(label: 'Weather', value: weather),
        const SizedBox(height: 12),
        _InfoTile(label: 'Road', value: road),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _InfoTile(label: 'Speed', value: speed)),
            const SizedBox(width: 12),
            Expanded(child: _InfoTile(label: 'Distance', value: distance)),
          ],
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.62))),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionPanel extends StatelessWidget {
  const _ActionPanel({
    required this.loading,
    required this.autoMode,
    required this.onAutomatic,
    required this.onAutomaticStop,
    required this.onSnapshot,
  });

  final bool loading;
  final bool autoMode;
  final VoidCallback onAutomatic;
  final VoidCallback onAutomaticStop;
  final VoidCallback onSnapshot;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select prediction mode', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: loading ? null : (autoMode ? onAutomaticStop : onAutomatic),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            backgroundColor: autoMode ? const Color(0xFF67EAD6) : const Color(0xFF9AB0FF),
          ),
          child: Text(autoMode ? 'Stop automatic prediction' : 'Start automatic prediction'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: loading ? null : onSnapshot,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(56),
            side: const BorderSide(color: Color(0xFF67EAD6)),
          ),
          child: const Text('Manual snapshot prediction'),
        ),
      ],
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.red.withOpacity(0.24)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }
}
