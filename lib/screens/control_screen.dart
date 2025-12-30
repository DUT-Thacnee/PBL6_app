import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import '../services/device_manager.dart';
import '../services/realtime_db_service.dart';

class ControlScreen extends StatefulWidget {
  const ControlScreen({super.key});

  @override
  State<ControlScreen> createState() => _ControlScreenState();
}

class _ControlScreenState extends State<ControlScreen> {
  late DeviceManagerService _deviceManager;

  static const String _automationPrefKey = 'control_automation_enabled';

  // Simplified: single light toggle + latency
  bool _lightOn = false;
  int? _latencyMicros;
  bool _sending = false;

  // Automation state
  bool _automationOn = false;
  bool _automationBusy = false;
  String? _automationMessage;
  double? _currentTemp;
  double? _currentIaq;
  double? _currentAcSetpoint;
  int? _currentAfLevel;
  StreamSubscription<DatabaseEvent>? _automationSensorSub;
  bool _firebaseReady = false;
  DateTime? _tempHighSince;
  DateTime? _tempLowSince;
  bool _tempHighMildApplied = false;
  bool _tempHighSevereApplied = false;
  bool _tempLowMildApplied = false;
  bool _tempLowSevereApplied = false;

  @override
  void initState() {
    super.initState();
    _deviceManager = DeviceManagerService();
    _deviceManager.addListener(_updateUI);
    _syncWithDeviceManager();
    _restoreAutomationPreference();
  }

  @override
  void dispose() {
    _deviceManager.removeListener(_updateUI);
    _automationSensorSub?.cancel();
    super.dispose();
  }

  void _updateUI() {
    setState(() {});
  }

  void _syncWithDeviceManager() {
    // Sync current light state from DeviceManager into _lightOn
    final isOn = _deviceManager.getLightState('Office Lights');
    setState(() {
      _lightOn = isOn;
    });
  }

  Future<void> _restoreAutomationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_automationPrefKey) ?? false;
    if (!mounted || !saved) return;
    await _onAutomationSwitch(true);
  }

  Future<void> _persistAutomationEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_automationPrefKey, enabled);
  }

  int _getLightBrightnessFromLevel(String level) {
    switch (level) {
      case 'Off':
        return 0;
      case 'Level 1':
        return 30;
      case 'Level 2':
        return 70;
      case 'Level 3':
        return 100;
      default:
        return 70;
    }
  }

  Future<void> _onAutomationSwitch(bool value) async {
    if (value == _automationOn) return;
    if (!value) {
      await _stopAutomation();
      return;
    }

    setState(() {
      _automationMessage = 'Starting automation...';
      _automationBusy = true;
    });

    try {
      await _ensureFirebaseReady();
      await _loadInitialAutomationState();
      await _startAutomationStream();
      if (!mounted) return;
      setState(() {
        _automationOn = true;
        _automationMessage = 'Automation active.';
      });
      await _persistAutomationEnabled(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _automationOn = false;
        _automationMessage = 'Automation error: $e';
      });
      await _persistAutomationEnabled(false);
    } finally {
      if (!mounted) return;
      setState(() {
        _automationBusy = false;
      });
    }
  }

  Future<void> _ensureFirebaseReady() async {
    if (_firebaseReady) return;
    if (Firebase.apps.isNotEmpty) {
      _firebaseReady = true;
      return;
    }
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseReady = true;
  }

  Future<void> _loadInitialAutomationState() async {
    final baseUrl = RealtimeDbService.defaultBaseUrl;
    final sensorsRaw = await RealtimeDbService.get(
      baseUrl: baseUrl,
      path: '/sensors',
    );
    final controlsRaw = await RealtimeDbService.get(
      baseUrl: baseUrl,
      path: '/Control',
    );

    final sensors = _mapFromDynamic(sensorsRaw);
    final controls = _mapFromDynamic(controlsRaw);

    _currentTemp = _extractDouble(sensors,
        const ['temperature_c', 'temp_c', 'temp', 'temperature', 'tem']);
    _currentIaq =
        _extractDouble(sensors, const ['iaq', 'IAQ', 'iaq_score', 'iaqIndex']);
    _currentAcSetpoint = _extractDouble(
        controls, const ['AC', 'ac', 'setpoint', 'target_temp', 'temperature']);
    final afDouble = _extractDouble(
        controls, const ['AF', 'af', 'air_flow', 'fan', 'fan_level']);
    _currentAfLevel = afDouble?.round();
  }

  Future<void> _startAutomationStream() async {
    await _automationSensorSub?.cancel();
    _automationSensorSub = FirebaseDatabase.instance
        .ref()
        .onValue
        .listen(_handleAutomationEvent, onError: (Object e) {
      if (!mounted) return;
      setState(() {
        _automationMessage = 'Sensor stream error: $e';
      });
    });
  }

  Future<void> _stopAutomation() async {
    await _automationSensorSub?.cancel();
    _automationSensorSub = null;
    if (mounted) {
      setState(() {
        _automationOn = false;
        _automationBusy = false;
        _automationMessage = 'Automation disabled.';
        _tempHighSince = null;
        _tempLowSince = null;
        _tempHighMildApplied = false;
        _tempHighSevereApplied = false;
        _tempLowMildApplied = false;
        _tempLowSevereApplied = false;
      });
    }
    await _persistAutomationEnabled(false);
  }

  void _handleAutomationEvent(DatabaseEvent event) {
    final root = _mapFromDynamic(event.snapshot.value);
    if (root == null) return;

    final sensors = _mapFromDynamic(root['sensors']);
    final controls = _mapFromDynamic(root['Control'] ?? root['controls']);

    final temp = _extractDouble(sensors,
        const ['temperature_c', 'temp_c', 'temp', 'temperature', 'tem']);
    final iaq =
        _extractDouble(sensors, const ['iaq', 'IAQ', 'iaq_score', 'iaqIndex']);
    final acSetpoint = _extractDouble(
        controls, const ['AC', 'ac', 'setpoint', 'target_temp', 'temperature']);
    final afLevel = _extractDouble(
        controls, const ['AF', 'af', 'air_flow', 'fan', 'fan_level'])?.round();

    setState(() {
      _currentTemp = temp ?? _currentTemp;
      _currentIaq = iaq ?? _currentIaq;
      _currentAcSetpoint = acSetpoint ?? _currentAcSetpoint;
      _currentAfLevel = afLevel ?? _currentAfLevel;
    });

    if (!_automationOn) return;
    if (temp != null) {
      _processTemperature(temp);
    }
    if (iaq != null) {
      _processAirQuality(iaq);
    }
  }

  void _processTemperature(double temp) {
    final now = DateTime.now();
    if (temp > _tempHighThreshold) {
      _tempLowSince = null;
      _tempLowMildApplied = false;
      _tempLowSevereApplied = false;
      _tempHighSince ??= now;
      final elapsed = now.difference(_tempHighSince!);
      if (elapsed >= _severeDuration) {
        _applyTemperatureAdjustment(-2,
            alreadyAppliedMild: _tempHighMildApplied,
            severeFlagSetter: () => _tempHighSevereApplied = true,
            mildFlagSetter: () => _tempHighMildApplied = true,
            severeApplied: _tempHighSevereApplied);
      } else if (elapsed >= _mildDuration && !_tempHighMildApplied) {
        _queueTemperatureChange(-1);
        _tempHighMildApplied = true;
      }
    } else if (temp < _tempLowThreshold) {
      _tempHighSince = null;
      _tempHighMildApplied = false;
      _tempHighSevereApplied = false;
      _tempLowSince ??= now;
      final elapsed = now.difference(_tempLowSince!);
      if (elapsed >= _severeDuration) {
        _applyTemperatureAdjustment(2,
            alreadyAppliedMild: _tempLowMildApplied,
            severeFlagSetter: () => _tempLowSevereApplied = true,
            mildFlagSetter: () => _tempLowMildApplied = true,
            severeApplied: _tempLowSevereApplied);
      } else if (elapsed >= _mildDuration && !_tempLowMildApplied) {
        _queueTemperatureChange(1);
        _tempLowMildApplied = true;
      }
    } else {
      _tempHighSince = null;
      _tempLowSince = null;
      _tempHighMildApplied = false;
      _tempHighSevereApplied = false;
      _tempLowMildApplied = false;
      _tempLowSevereApplied = false;
    }
  }

  void _applyTemperatureAdjustment(
    int totalDelta, {
    required bool alreadyAppliedMild,
    required VoidCallback severeFlagSetter,
    required VoidCallback mildFlagSetter,
    required bool severeApplied,
  }) {
    if (severeApplied) return;
    final delta = alreadyAppliedMild ? (totalDelta > 0 ? 1 : -1) : totalDelta;
    _queueTemperatureChange(delta);
    mildFlagSetter();
    severeFlagSetter();
  }

  Future<void> _queueTemperatureChange(int delta) async {
    if (_automationBusy) return;
    setState(() {
      _automationBusy = true;
      _automationMessage =
          'Adjusting AC by ${delta > 0 ? '+' : ''}$delta °C...';
    });

    try {
      final nextValue = await _computeNextSetpoint(delta);
      if (nextValue == null) {
        if (!mounted) return;
        setState(() {
          _automationBusy = false;
          _automationMessage = 'Could not determine AC setpoint.';
        });
        return;
      }
      await _writeAcSetpoint(nextValue);
      if (!mounted) return;
      setState(() {
        _automationBusy = false;
        _currentAcSetpoint = nextValue;
        _automationMessage =
            'AC setpoint adjusted to ${nextValue.toStringAsFixed(1)} °C.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _automationBusy = false;
        _automationMessage = 'Failed to adjust AC: $e';
      });
    }
  }

  Future<double?> _computeNextSetpoint(int delta) async {
    if (_currentAcSetpoint == null) {
      final controlsRaw = await RealtimeDbService.get(
        baseUrl: RealtimeDbService.defaultBaseUrl,
        path: '/Control',
      );
      final controls = _mapFromDynamic(controlsRaw);
      _currentAcSetpoint = _extractDouble(controls,
          const ['AC', 'ac', 'setpoint', 'target_temp', 'temperature']);
    }
    final base = _currentAcSetpoint ?? _defaultAcSetpoint;
    return base + delta;
  }

  Future<void> _writeAcSetpoint(double value) async {
    await RealtimeDbService.patch(
      baseUrl: RealtimeDbService.defaultBaseUrl,
      path: '/Control',
      data: {'AC': value},
    );
  }

  void _processAirQuality(double iaq) {
    int target = _baseAfLevel;
    if (iaq >= 300) {
      target = 100;
    } else if (iaq >= 200) {
      target = 85;
    } else if (iaq >= 150) {
      target = 70;
    }

    if (_currentAfLevel == target) return;
    if (_automationBusy) return;
    setState(() {
      _automationBusy = true;
      _automationMessage = 'Updating airflow to $target.';
    });

    RealtimeDbService.patch(
      baseUrl: RealtimeDbService.defaultBaseUrl,
      path: '/Control',
      data: {'AF': target},
    ).then((_) {
      if (!mounted) return;
      setState(() {
        _automationBusy = false;
        _currentAfLevel = target;
        _automationMessage = 'Airflow level set to $target.';
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() {
        _automationBusy = false;
        _automationMessage = 'Failed to set airflow: $e';
      });
    });
  }

  Map<String, dynamic>? _mapFromDynamic(dynamic value) {
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return null;
  }

  double? _extractDouble(
      Map<String, dynamic>? map, List<String> candidateKeys) {
    if (map == null) return null;
    for (final key in candidateKeys) {
      if (map.containsKey(key)) {
        final v = map[key];
        final parsed = _toDouble(v);
        if (parsed != null) return parsed;
      }
      final match = map.entries.firstWhere(
        (entry) => entry.key.toLowerCase() == key.toLowerCase(),
        orElse: () => const MapEntry('', null),
      );
      if (match.key.isNotEmpty) {
        final parsed = _toDouble(match.value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  String _getLevelFromBrightness(int brightness) {
    if (brightness == 0) return 'Off';
    if (brightness <= 30) return 'Level 1';
    if (brightness <= 70) return 'Level 2';
    return 'Level 3';
  }

  @override
  Widget build(BuildContext context) {
    // Responsive breakpoints
    final screenWidth = MediaQuery.of(context).size.width;
    final isWebDemo = screenWidth > 800; // Web demo mode
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isWebDemo ? 24 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(isWebDemo, isMobile),
              SizedBox(height: isWebDemo ? 32 : 24),
              _buildSingleLightSection(isWebDemo),
              const SizedBox(height: 16),
              _buildAutomationSection(isWebDemo),
              SizedBox(height: isWebDemo ? 32 : 80), // Extra space for mobile
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWebDemo, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isWebDemo ? 24 : 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFF06B6D4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isWebDemo ? 12 : 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.settings,
              color: Colors.white,
              size: isWebDemo ? 28 : 24,
            ),
          ),
          SizedBox(width: isWebDemo ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device Control',
                  style: TextStyle(
                    fontSize: isWebDemo ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: isWebDemo ? 8 : 4),
                Text(
                  'Manage your office devices',
                  style: TextStyle(
                    fontSize: isWebDemo ? 16 : 14,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleLightSection(bool isWebDemo) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb,
                color: const Color(0xFF8B5CF6), size: isWebDemo ? 28 : 24),
            SizedBox(width: isWebDemo ? 12 : 8),
            Text('Light Control',
                style: TextStyle(
                    fontSize: isWebDemo ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937))),
          ],
        ),
        SizedBox(height: isWebDemo ? 16 : 12),
        Container(
          padding: EdgeInsets.all(isWebDemo ? 20 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _lightOn ? const Color(0xFF8B5CF6) : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_lightOn ? 'On' : 'Off',
                      style: TextStyle(
                          fontSize: isWebDemo ? 18 : 16,
                          fontWeight: FontWeight.w600)),
                  Switch(
                    value: _lightOn,
                    onChanged: _sending ? null : (v) => _toggleLightAndSend(v),
                    activeColor: const Color(0xFF8B5CF6),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Text(
              //     'Latency: ${_latencyMicros != null ? '${_latencyMicros} μs' : '—'}'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAutomationSection(bool isWebDemo) {
    final subtitleStyle = TextStyle(
      fontSize: isWebDemo ? 14 : 13,
      color: Colors.grey.shade600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.auto_mode,
                color: const Color(0xFF06B6D4), size: isWebDemo ? 28 : 24),
            SizedBox(width: isWebDemo ? 12 : 8),
            Text('Automation',
                style: TextStyle(
                    fontSize: isWebDemo ? 24 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2937))),
          ],
        ),
        SizedBox(height: isWebDemo ? 16 : 12),
        Container(
          padding: EdgeInsets.all(isWebDemo ? 20 : 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _automationOn
                  ? const Color(0xFF06B6D4)
                  : Colors.grey.shade300,
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _automationOn ? 'Automation On' : 'Automation Off',
                          style: TextStyle(
                            fontSize: isWebDemo ? 18 : 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automatic AC and air-flow control based on sensor readings.',
                          style: subtitleStyle,
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (_automationBusy)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      Switch(
                        value: _automationOn,
                        onChanged: _automationBusy
                            ? null
                            : (v) => _onAutomationSwitch(v),
                        activeColor: const Color(0xFF06B6D4),
                      ),
                    ],
                  ),
                ],
              ),
              if (_automationOn) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _automationChip(
                        label: 'Temperature',
                        value: _currentTemp != null
                            ? '${_currentTemp!.toStringAsFixed(1)} °C'
                            : '—'),
                    _automationChip(
                        label: 'IAQ',
                        value: _currentIaq != null
                            ? _currentIaq!.toStringAsFixed(0)
                            : '—'),
                    _automationChip(
                        label: 'AC Setpoint',
                        value: _currentAcSetpoint != null
                            ? '${_currentAcSetpoint!.toStringAsFixed(1)} °C'
                            : '—'),
                    _automationChip(
                      label: 'AF Level',
                      value: _currentAfLevel != null
                          ? _currentAfLevel.toString()
                          : '—',
                    ),
                  ],
                ),
              ],
              if (_automationMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _automationMessage!,
                  style: TextStyle(
                    fontSize: 13,
                    color: _automationOn
                        ? const Color(0xFF047857)
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _automationChip({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF111827),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // Single light control: toggle and send to RTDB with latency measurement
  Future<void> _toggleLightAndSend(bool isOn) async {
    setState(() {
      _lightOn = isOn;
      _sending = true;
    });

    try {
      final baseUrl = RealtimeDbService.defaultBaseUrl;
      final int start = DateTime.now().microsecondsSinceEpoch;
      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/Control',
        data: {
          'Light_status': _lightOn ? 'on' : 'off',
          'Light_updated_at': DateTime.now().toIso8601String(),
        },
      );
      final int end = DateTime.now().microsecondsSinceEpoch;
      final int latency = end - start;

      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/',
        data: {
          'latency': latency, // kept for compatibility (microseconds)
          'latency_us': latency,
          'latency_ms': latency ~/ 1000,
        },
      );

      setState(() {
        _latencyMicros = latency;
      });

      // sync simple state back to DeviceManager
      _deviceManager.updateLightState('Office Lights', _lightOn);
      if (!_lightOn) _deviceManager.updateLightLevel('Office Lights', 'Off');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('RTDB error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }

  // Removed AC control methods
}

const double _tempLowThreshold = 21.0;
const double _tempHighThreshold = 26.0;
const Duration _mildDuration = Duration(minutes: 1);
const Duration _severeDuration = Duration(minutes: 3);
const double _defaultAcSetpoint = 26.0;
const int _baseAfLevel = 50;

// Removed Firebase Test navigation helpers

// Light device model
class LightDevice {
  final String id;
  final String name;
  final String location;
  final bool isOn;
  final int brightness;
  final Color color;

  LightDevice({
    required this.id,
    required this.name,
    required this.location,
    required this.isOn,
    required this.brightness,
    required this.color,
  });

  LightDevice copyWith({
    String? id,
    String? name,
    String? location,
    bool? isOn,
    int? brightness,
    Color? color,
  }) {
    return LightDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      color: color ?? this.color,
    );
  }
}

// Air conditioner device model
// Removed AirConditionerDevice model since AC UI is removed
