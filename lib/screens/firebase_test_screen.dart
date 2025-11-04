import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../firebase_options.dart';
import '../firebase_custom.dart';
import '../services/realtime_db_service.dart';

class FirebaseTestScreen extends StatefulWidget {
  const FirebaseTestScreen({super.key});

  @override
  State<FirebaseTestScreen> createState() => _FirebaseTestScreenState();
}

class _FirebaseTestScreenState extends State<FirebaseTestScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  // Use the default URL from service (sourced from dart-define or baked-in).
  bool _initialized = false;
  bool _loading = false;
  String _status = 'Not initialized';
  String? _uid;
  String? _lastError;
  String? _rawAcData;
  // AC fields
  String? _acMode;
  int? _acTemp;

  // Connectivity & Firestore listener
  StreamSubscription<ConnectivityResult>? _connectivitySub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _acSub;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _initFirebase();
    _setupConnectivity();
  }

  void _setupConnectivity() {
    // Initial connectivity
    Connectivity().checkConnectivity().then((r) => _onConnectivityChanged(r));
    // Listen for changes
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);
  }

  void _onConnectivityChanged(ConnectivityResult result) {
    final online = result != ConnectivityResult.none;
    if (online == _isOnline) return;
    setState(() => _isOnline = online);

    if (_isOnline) {
      // start realtime listener when online
      _startAcListener();
    } else {
      // stop realtime listener when offline
      _stopAcListener();
    }
  }

  void _startAcListener() {
    if (!_initialized) return;
    if (_acSub != null) return; // already listening

    _acSub = FirebaseFirestore.instance
        .collection('test')
        .doc('ac')
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final raw = snapshot.data() ?? {};

      // Normalize keys: remove invisible whitespace and trim
      final Map<String, dynamic> data = {};
      for (final entry in raw.entries) {
        final String rawKey = entry.key.toString();
        final String k =
            rawKey.replaceAll(RegExp(r'[\u00A0\u200B\u200C\u200D]'), '').trim();
        data[k] = entry.value;
      }

      // Debug: record raw data and print keys/types
      _rawAcData = raw.toString();
      debugPrint('AC snapshot raw: $_rawAcData');
      debugPrint('AC keys: ${data.keys.toList()}');
      debugPrint(
          'mode=${data["mode"]} (${data["mode"]?.runtimeType}), temp=${data["temp"]} (${data["temp"]?.runtimeType})');

      setState(() {
        final mode = data['mode'];
        final t = data['temp'];
        _acMode = (mode != null) ? mode.toString() : null;
        _acTemp = (t is num) ? t.toInt() : null;
      });
    }, onError: (e) {
      _lastError = 'AC listener error: $e';
      setState(() {});
    });
  }

  void _stopAcListener() {
    _acSub?.cancel();
    _acSub = null;
  }

  Future<void> _reloadAcOnce() async {
    if (!_initialized) return _showMessage('Firebase not initialized');
    if (!_isOnline) return _showMessage('No connectivity');

    try {
      final doc =
          await FirebaseFirestore.instance.collection('test').doc('ac').get();
      if (!doc.exists) return _showMessage('No ac document');
      final data = doc.data() ?? {};
      _rawAcData = data.toString();
      debugPrint('Reloaded AC raw: $_rawAcData');
      setState(() {
        final mode = data['mode'];
        final t = data['temp'];
        _acMode = (mode != null) ? mode.toString() : null;
        _acTemp = (t is num) ? t.toInt() : null;
      });
      _showMessage('Reloaded');
    } catch (e) {
      _lastError = 'Reload error: $e';
      setState(() {});
      _showMessage('Reload failed');
    }
  }

  Future<void> _initFirebase() async {
    try {
      setState(() => _status = 'Initializing...');
      // Prefer a custom set of FirebaseOptions if provided in `firebase_custom.dart`.
      final opts = FirebaseCustomOptions.options ??
          DefaultFirebaseOptions.currentPlatform;
      await Firebase.initializeApp(
        options: opts,
      );
      // Try to sign in anonymously if not already signed in.
      await _ensureSignedIn();
      setState(() {
        _initialized = true;
        _status = 'Firebase initialized';
      });
      // If we are already online, start the realtime listener now (avoid race)
      if (_isOnline) {
        _startAcListener();
      }
    } catch (e) {
      setState(() => _status = 'Init error: $e');
    }
  }

  Future<void> _ensureSignedIn() async {
    try {
      final auth = FirebaseAuth.instance;
      if (auth.currentUser == null) {
        // Attempt anonymous sign-in (requires Anonymous sign-in enabled in Firebase Console)
        final cred = await auth.signInAnonymously();
        _uid = cred.user?.uid;
      } else {
        _uid = auth.currentUser?.uid;
      }
      setState(() {});
    } catch (e) {
      // don't block initialization — just record error for debugging
      _lastError = 'Auth error: $e';
      setState(() {});
    }
  }

  Future<void> _sendData() async {
    // Send to Realtime Database instead of Firestore
    final baseUrl = RealtimeDbService.defaultBaseUrl;
    final name = _nameController.text.trim();
    final ageText = _ageController.text.trim();
    if (name.isEmpty || ageText.isEmpty) {
      return _showMessage('Please fill both');
    }
    final age = int.tryParse(ageText);
    if (age == null) return _showMessage('Age must be a whole number');

    setState(() => _loading = true);
    try {
      // Patch at /test/user (creates keys if not present)
      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/',
        data: {
          'light': name,
          'AC': age,
          'updatedAt': DateTime.now().toIso8601String(),
        },
      );

      setState(() => _loading = false);
      _showMessage('Sent to Realtime DB');
      _nameController.clear();
      _ageController.clear();
    } catch (e) {
      setState(() => _loading = false);
      _lastError = 'Realtime DB error: $e';
      _showMessage('Error: $e');
      setState(() {});
    }
  }

  // Send the control payload at root path as in screenshot
  Future<void> _sendRootControl() async {
    final baseUrl = RealtimeDbService.defaultBaseUrl;
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
      await RealtimeDbService.patch(
        baseUrl: baseUrl,
        path: '/',
        data: {
          'AC': 22,
          'ac_status': 'on',
          'datetime': fmt.format(now),
          'light': 'on',
          'ts': now.millisecondsSinceEpoch ~/ 1000,
        },
      );
      _showMessage('Sent control payload to RTDB root');
    } catch (e) {
      _lastError = 'Realtime DB error: $e';
      _showMessage('Error: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // Small probe writer to help diagnose permission issues
  Future<void> _probeWrite() async {
    if (!_initialized) return _showMessage('Firebase not initialized');
    try {
      final ref = FirebaseFirestore.instance.collection('test').doc('probe');
      await ref.set({'ok': true, 'time': FieldValue.serverTimestamp()});
      _showMessage('Probe write OK');
    } on FirebaseException catch (e) {
      _lastError = 'Probe write FirebaseException: ${e.code} - ${e.message}';
      setState(() {});
      _showMessage('Probe failed: ${e.code}');
    } catch (e) {
      _lastError = 'Probe write error: $e';
      setState(() {});
      _showMessage('Probe failed');
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _acSub?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase Test')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status: $_status'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Age (years)'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loading ? null : _sendData,
              icon: _loading ? const SizedBox.shrink() : const Icon(Icons.send),
              label: Text(_loading ? 'Sending...' : 'Send to Realtime DB'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _sendRootControl,
              child: Text(_loading ? 'Sending...' : 'Send control (root)'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AC Mode',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_acMode ?? '—',
                              style: const TextStyle(fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('AC Temp',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(_acTemp?.toString() ?? '—',
                              style: const TextStyle(fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isOnline ? _reloadAcOnce : null,
                  child: const Text('Reload AC (offline->online)'),
                ),
                const SizedBox(width: 12),
                Text('Online: ${_isOnline ? "Yes" : "No"}'),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Notes:'),
            const SizedBox(height: 8),
            const Text(
                '- This screen initializes Firebase for web/android/ios using firebase_options.dart.'),
            const Text(
                '- It writes to Realtime Database path /test/user with fields: name(string), age(number), updatedAt(ISO string).'),
            const SizedBox(height: 8),
            const Text(
                '- If you see errors, check your Realtime Database URL, rules, and optional RTDB_AUTH (use --dart-define).'),
            const SizedBox(height: 12),
            const SizedBox(height: 8),
            // Show which FirebaseOptions are in use to help debugging
            Builder(builder: (ctx) {
              // Access DefaultFirebaseOptions.currentPlatform safely
              String pid = '(unknown)';
              String api = '(unknown)';
              try {
                final opts = DefaultFirebaseOptions.currentPlatform;
                pid = opts.projectId;
                api = opts.apiKey;
              } catch (_) {}
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Firebase projectId: $pid'),
                  Text(
                      'Firebase apiKey: ${api.substring(0, api.length > 8 ? 8 : api.length)}...'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _initialized ? _probeWrite : null,
                    child: const Text('Try probe write to test/probe'),
                  ),
                ],
              );
            }),
            const SizedBox(height: 8),
            Text('Auth uid: ${_uid ?? "(not signed in)"}'),
            if (_lastError != null) ...[
              const SizedBox(height: 8),
              Text('Last error: $_lastError',
                  style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    );
  }
}
