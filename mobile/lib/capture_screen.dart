import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'api_client.dart';
import 'quality_control.dart';
import 'species.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> with WidgetsBindingObserver {
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
      final configs = await _api.loadSpecies();
      if (configs.isEmpty) throw Exception('No species is enabled on the backend');
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _selected = configs.first;
        _message = null;
      });
    } catch (error) {
      if (mounted) setState(() => _message = 'Start the backend and retry settings. $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCamera() async {
    final generation = ++_cameraGeneration;
    CameraController? candidate;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw Exception('No camera is available on this device');
      final rear = cameras.where((camera) => camera.lensDirection == CameraLensDirection.back);
      candidate = CameraController(rear.isEmpty ? cameras.first : rear.first,
          ResolutionPreset.high, enableAudio: false);
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
        setState(() => _cameraError = 'Camera unavailable. Allow camera access in device settings. $error');
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

  Future<Map<String, double>?> _captureGps() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return null;
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 8)),
      );
      return {'latitude': position.latitude, 'longitude': position.longitude};
    } catch (_) {
      return null;
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    final config = _selected;
    if (_busy || camera == null || config == null || !_form.currentState!.validate()) return;
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
      final quality = await compute(checkLocalQuality, {
        'bytes': await photo.readAsBytes(), 'quality': config.quality,
      });
      if (!mounted) {
        await _deletePhoto(photo);
        return;
      }
      setState(() {
        _photo = photo;
        _quality = quality;
        _saved = false;
        _metadata = {
          'animal_id': animalId, 'operator_id': operatorId, 'species': config.species.name,
          'timestamp': timestamp.toIso8601String(), 'gps': gps,
        };
      });
    } catch (error) {
      await _deletePhoto(photo);
      if (mounted) setState(() => _message = 'Capture failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _upload() async {
    if (_photo == null || _metadata == null || _busy || _saved) return;
    setState(() => _busy = true);
    try {
      final result = await _api.upload(_photo!.path, _metadata!);
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
    unawaited(_deletePhoto(_photo));
    setState(() {
      _photo = null;
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
    unawaited(_deletePhoto(_photo));
    _api.close();
    _animal.dispose();
    _operator.dispose();
    super.dispose();
  }

  Widget _preview() {
    if (_photo != null) return Image.file(File(_photo!.path), fit: BoxFit.contain);
    if (_cameraError != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(_cameraError!, textAlign: TextAlign.center),
        TextButton(onPressed: _openCamera, child: const Text('Retry camera')),
      ]));
    }
    if (_camera == null || !_camera!.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    return Center(child: AspectRatio(aspectRatio: _camera!.value.aspectRatio, child: CameraPreview(_camera!)));
  }

  Widget _qualityCard() {
    final quality = _quality!;
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(quality.passed ? 'Local quality check passed' : 'Please retake',
            style: Theme.of(context).textTheme.titleMedium),
        Text('Sharpness: ${quality.blurVariance.toStringAsFixed(1)} · Brightness: ${quality.brightness.toStringAsFixed(1)}'),
        for (final reason in quality.reasons) Text(reason),
        Text(_metadata?['gps'] == null ? 'GPS unavailable — location will be saved as empty.' : 'GPS recorded.'),
        const Text('The server makes the final quality and framing check.'),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_busy && _photo == null;
    return Scaffold(
      appBar: AppBar(title: const Text('BioLivestock · Capture')),
      body: SafeArea(child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Text('Phase 1 · Field data collection'),
          const SizedBox(height: 12),
          Form(key: _form, child: Column(children: [
            if (_configs.isNotEmpty) DropdownButtonFormField<SpeciesConfig>(
              initialValue: _selected,
              decoration: const InputDecoration(labelText: 'Species'),
              items: _configs.map((config) => DropdownMenuItem(value: config, child: Text(config.species.name))).toList(),
              onChanged: editable ? (value) => setState(() => _selected = value) : null,
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _animal, enabled: editable, decoration: const InputDecoration(labelText: 'Animal ID'),
              validator: (value) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$').hasMatch(value?.trim() ?? '')
                  ? null : 'Use 1–64 letters, digits, underscores or hyphens'),
            const SizedBox(height: 12),
            TextFormField(controller: _operator, enabled: editable, maxLength: 100,
              decoration: const InputDecoration(labelText: 'Operator ID'),
              validator: (value) => value == null || value.trim().isEmpty ? 'Enter an operator ID' : null),
          ])),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _configs.isEmpty) OutlinedButton(onPressed: _loadConfigs, child: const Text('Retry backend settings')),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('Keep one muzzle fully visible. Move close, hold steady, and use even lighting.')),
          SizedBox(height: 320, child: ClipRRect(borderRadius: BorderRadius.circular(12), child: _preview())),
          if (_quality != null) _qualityCard(),
          if (_message != null) Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: SelectableText(_message!)),
          if (_busy) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          if (_photo == null) FilledButton.icon(
            onPressed: !_busy && _camera != null && _selected != null ? _capture : null,
            icon: const Icon(Icons.camera_alt), label: const Text('Capture'),
          ) else ...[
            FilledButton.icon(onPressed: !_busy && !_saved && (_quality?.passed ?? false) ? _upload : null,
                icon: const Icon(Icons.cloud_upload_outlined), label: Text(_saved ? 'Uploaded' : 'Upload capture')),
            OutlinedButton(onPressed: _busy ? null : _retake, child: Text(_saved ? 'Next capture' : 'Retake')),
          ],
        ]),
      ))),
    );
  }
}
