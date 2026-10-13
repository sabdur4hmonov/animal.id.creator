import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';
import 'animal_id.dart';
import 'device_signals.dart';
import 'offline_queue.dart';
import 'quality_control.dart';
import 'species.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  final _api = ApiClient();
  final _form = GlobalKey<FormState>();
  final _animal = TextEditingController();
  final _operator = TextEditingController(text: authenticatedOperatorId);
  CameraController? _camera;
  List<SpeciesConfig> _configs = [];
  SpeciesConfig? _selected;
  XFile? _photo;
  LocalQuality? _quality;
  Map<String, dynamic>? _metadata;
  OfflineQueue? _queue;
  QueuedCapture? _queued;
  List<QueuedCapture> _pending = [];
  List<String> _queueIssues = [];
  String get _backend => apiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  String? _message;
  String? _cameraError;
  bool _busy = false;
  bool _loading = true;
  bool _saved = false;
  bool _active = true;
  int _cameraGeneration = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadConfigs());
    unawaited(_openCamera());
  }

  Future<void> _loadConfigs() async {
    setState(() => _loading = true);
    try {
      _queue ??= OfflineQueue(
        Directory(
          '${(await getApplicationSupportDirectory()).path}/capture_queue',
        ),
      );
      List<SpeciesConfig> configs;
      var cached = false;
      try {
        configs = await _api.loadSpecies();
        await _queue!.cacheSettings(
          _backend,
          configs.map((item) => item.toJson()).toList(),
        );
      } catch (_) {
        configs = (await _queue!.cachedSettings(
          _backend,
        )).map(SpeciesConfig.fromJson).where((item) => item.enabled).toList();
        cached = true;
      }
      if (configs.isEmpty) {
        throw Exception('No species is enabled on the backend');
      }
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _selected = configs.first;
        _message = cached
            ? 'Offline settings loaded. Save captures now; upload when the backend is available.'
            : null;
      });
      await _refreshQueue();
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'Connect to the backend once to cache settings, then retry. $error',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshQueue() async {
    if (_queue == null) return;
    try {
      final pending = await _queue!.pending(_backend, authenticatedOperatorId);
      if (mounted) {
        setState(() {
          _pending = pending;
          _queueIssues = List.of(_queue!.issues);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _queueIssues = [
            'Queue review failed: $error. Local files retained.',
          ],
        );
      }
    }
  }

  Future<void> _syncQueue() async {
    if (_busy || _queue == null) return;
    setState(() => _busy = true);
    try {
      final count = await _queue!.sync(
        _backend,
        authenticatedOperatorId,
        _api.upload,
      );
      final acknowledged =
          _queued != null && await _queue!.acknowledged(_queued!);
      if (mounted) {
        setState(() {
          _message =
              'Uploaded $count queued captures. Local originals and receipts retained.';
          if (_queued != null) _saved = acknowledged;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message =
              'Queue paused: $error. Unsaved captures remain on this phone.',
        );
      }
    } finally {
      await _refreshQueue();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _showReceipts() async {
    try {
      final saved = await _queue!.receipts(_backend, authenticatedOperatorId);
      if (!mounted) return;
      setState(() => _queueIssues = List.of(_queue!.issues));
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Saved upload receipts'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: SelectableText(
                saved.isEmpty
                    ? 'No uploads acknowledged yet.'
                    : saved
                          .map(
                            (item) =>
                                '${item['animal_id']} · ${item['species']}\nRequest: ${item['request_key']}\n'
                                'Capture: ${item['id']}\nFile: ${item['file_path']}',
                          )
                          .join('\n\n'),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(
          () =>
              _message = 'Receipt review failed: $error. Local files retained.',
        );
      }
    }
  }

  void _openQueued(QueuedCapture entry) {
    if (_busy || _photo != null) return;
    final quality = entry.journal.quality;
    _animal.text = entry.metadata['animal_id'] as String;
    setState(() {
      _queued = entry;
      _photo = XFile(entry.imagePath);
      _metadata = entry.metadata;
      _quality = LocalQuality(
        quality.blurVariance,
        quality.brightness,
        quality.reasons,
      );
      _saved = false;
      _message =
          'Recovered ${entry.metadata['animal_id']} from this phone. Labels/time preserved.';
    });
  }

  Future<void> _openCamera() async {
    final generation = ++_cameraGeneration;
    CameraController? candidate;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No camera is available on this device');
      }
      final rear = cameras.where(
        (camera) => camera.lensDirection == CameraLensDirection.back,
      );
      candidate = CameraController(
        rear.isEmpty ? cameras.first : rear.first,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await candidate.initialize();
      if (!mounted || !_active || generation != _cameraGeneration) {
        await candidate.dispose();
        return;
      }
      setState(() {
        _camera = candidate;
        _cameraError = null;
      });
    } catch (error) {
      await candidate?.dispose();
      if (mounted && generation == _cameraGeneration) {
        setState(
          () => _cameraError =
              'Camera unavailable. Allow camera access in device settings. $error',
        );
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _active = state == AppLifecycleState.resumed;
    if (!_active) {
      ++_cameraGeneration;
      final old = _camera;
      _camera = null;
      unawaited(old?.dispose());
      if (mounted) setState(() {});
    } else if (_camera == null) {
      unawaited(_openCamera());
    }
  }

  Future<Map<String, dynamic>?> _captureGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return {
        'gps': {'latitude': position.latitude, 'longitude': position.longitude},
        'gps_evidence': {
          'source': Platform.isAndroid ? 'android_location' : 'ios_location',
          'is_mock': position.isMocked,
          'accuracy_m': position.accuracy,
          'observed_at': position.timestamp.toUtc().toIso8601String(),
        },
      };
    } catch (_) {
      return null;
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    final config = _selected;
    if (_busy ||
        camera == null ||
        config == null ||
        _queue == null ||
        !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    XFile? photo;
    try {
      // Snapshot labels before asynchronous work; fields stay locked during capture.
      final animalId = _animal.text.trim();
      final operatorId = _operator.text.trim();
      final timestamp = DateTime.now().toUtc();
      photo = await camera.takePicture();
      final gps = await _captureGps();
      final deviceSignals = await readDeviceSignals();
      final quality = await compute(checkLocalQuality, {
        'bytes': await photo.readAsBytes(),
        'quality': config.quality,
      });
      final metadata = {
        'animal_id': animalId,
        'operator_id': operatorId,
        'species': config.species.name,
        'timestamp': timestamp.toIso8601String(),
        'gps': gps?['gps'],
        'gps_evidence': gps?['gps_evidence'],
        'device_signals': deviceSignals,
      };
      final queued = quality.passed
          ? await _queue!.enqueue(photo.path, metadata, {
              'blur_variance': quality.blurVariance,
              'brightness': quality.brightness,
              'reasons': quality.reasons,
            }, _backend)
          : null;
      if (!mounted) {
        await _deletePhoto(photo);
        return;
      }
      setState(() {
        _photo = queued == null ? photo : XFile(queued.imagePath);
        _queued = queued;
        _quality = quality;
        _saved = false;
        _metadata = metadata;
        if (queued != null) {
          _message =
              'Saved on this phone. Request ${queued.key}. Upload now or collect the next capture.';
        }
      });
      if (queued != null) await _deletePhoto(photo);
      await _refreshQueue();
    } catch (error) {
      await _deletePhoto(photo);
      if (mounted) setState(() => _message = 'Capture failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_queued == null || _queue == null || _busy || _saved) return;
    setState(() => _busy = true);
    try {
      final result = await _queue!.uploadOne(_queued!, _api.upload);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _message = result['crop_status'] == 'cropped'
            ? 'Saved original and muzzle crop. Capture ${result['id']}'
            : 'Saved original. Cropping is pending a trained model. Capture ${result['id']}';
      });
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      await _refreshQueue();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deletePhoto(XFile? photo) async {
    if (photo == null) return;
    try {
      await File(photo.path).delete();
    } on FileSystemException {
      // Camera temporary files may already have been removed by the OS.
    }
  }

  void _retake() {
    if (_queued == null) unawaited(_deletePhoto(_photo));
    setState(() {
      _photo = null;
      _queued = null;
      _quality = null;
      _metadata = null;
      _message = null;
      _saved = false;
    });
  }

  @override
  void dispose() {
    ++_cameraGeneration;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_camera?.dispose());
    if (_queued == null) unawaited(_deletePhoto(_photo));
    _api.close();
    _animal.dispose();
    _operator.dispose();
    super.dispose();
  }

  Widget _preview() {
    if (_photo != null) {
      return Image.file(File(_photo!.path), fit: BoxFit.contain);
    }
    if (_cameraError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_cameraError!, textAlign: TextAlign.center),
            TextButton(
              onPressed: _openCamera,
              child: const Text('Retry camera'),
            ),
          ],
        ),
      );
    }
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _camera!.value.aspectRatio,
        child: CameraPreview(_camera!),
      ),
    );
  }

  Widget _qualityCard() {
    final quality = _quality!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              quality.passed ? 'Local quality check passed' : 'Please retake',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              'Sharpness: ${quality.blurVariance.toStringAsFixed(1)} · Brightness: ${quality.brightness.toStringAsFixed(1)}',
            ),
            for (final reason in quality.reasons) Text(reason),
            Text(
              _metadata?['gps'] == null
                  ? 'GPS unavailable — location will be saved as empty.'
                  : 'GPS recorded.',
            ),
            const Text('The server makes the final quality and framing check.'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_busy && _photo == null;
    return Scaffold(
      appBar: AppBar(title: const Text('BioLivestock · Capture')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text('Phase 1 · Field data collection'),
                const SizedBox(height: 12),
                Form(
                  key: _form,
                  child: Column(
                    children: [
                      if (_configs.isNotEmpty)
                        DropdownButtonFormField<SpeciesConfig>(
                          initialValue: _selected,
                          decoration: const InputDecoration(
                            labelText: 'Species',
                          ),
                          items: _configs
                              .map(
                                (config) => DropdownMenuItem(
                                  value: config,
                                  child: Text(config.species.name),
                                ),
                              )
                              .toList(),
                          onChanged: editable
                              ? (value) => setState(() => _selected = value)
                              : null,
                        ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _animal,
                        enabled: editable,
                        decoration: const InputDecoration(
                          labelText: 'Animal ID',
                        ),
                        validator: validateAnimalId,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _operator,
                        enabled: false,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Operator ID',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter an operator ID'
                            : null,
                      ),
                    ],
                  ),
                ),
                if (_loading) const LinearProgressIndicator(),
                if (!_loading && _configs.isEmpty)
                  OutlinedButton(
                    onPressed: _loadConfigs,
                    child: const Text('Retry backend settings'),
                  ),
                Text(
                  'Pending uploads: ${_pending.length}. Saved originals remain on this phone.',
                ),
                OutlinedButton(
                  onPressed: !_busy && _pending.isNotEmpty ? _syncQueue : null,
                  child: const Text('Upload pending captures'),
                ),
                TextButton(
                  onPressed: !_busy && _queue != null ? _showReceipts : null,
                  child: const Text('Review saved upload receipts'),
                ),
                for (final issue in _queueIssues) Text(issue),
                if (_photo == null)
                  for (final entry in _pending)
                    ListTile(
                      title: Text(
                        '${entry.metadata['animal_id']} · ${entry.metadata['species']}',
                      ),
                      subtitle: Text(
                        '${entry.metadata['timestamp']} · ${entry.key}',
                      ),
                      onTap: _busy ? null : () => _openQueued(entry),
                    ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Keep one muzzle fully visible. Move close, hold steady, and use even lighting.',
                  ),
                ),
                SizedBox(
                  height: 320,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _preview(),
                  ),
                ),
                if (_quality != null) _qualityCard(),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: SelectableText(_message!),
                  ),
                if (_busy) const LinearProgressIndicator(),
                const SizedBox(height: 12),
                if (_photo == null)
                  FilledButton.icon(
                    onPressed: !_busy && _camera != null && _selected != null
                        ? _capture
                        : null,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Capture'),
                  )
                else ...[
                  FilledButton.icon(
                    onPressed: !_busy && !_saved && (_quality?.passed ?? false)
                        ? _upload
                        : null,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: Text(_saved ? 'Uploaded' : 'Upload capture'),
                  ),
                  OutlinedButton(
                    onPressed: _busy ? null : _retake,
                    child: Text(
                      _queued != null
                          ? 'Next capture (saved locally)'
                          : 'Retake',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
