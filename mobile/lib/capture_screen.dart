import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import 'api_client.dart';
import 'localization.dart';
import 'app_design.dart';
import 'animal_registry.dart';
import 'registry_journal.dart';
import 'animal_id.dart';
import 'capture_environment.dart';
import 'ar_screen.dart';
import 'offline_queue.dart';
import 'quality_control.dart';
import 'species.dart';
import 'bundled_configs.dart';
import 'field_store.dart';
import 'field_widgets.dart';

class CaptureScreen extends StatefulWidget {
  final CaptureEnvironment? environment;
  const CaptureScreen({super.key, this.environment});
  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen>
    with WidgetsBindingObserver {
  late final CaptureEnvironment _environment;
  ApiClient get _api => _environment.api;
  final _form = GlobalKey<FormState>();
  final _animal = TextEditingController();
  final _operator = TextEditingController();
  CaptureCamera? _camera;
  List<SpeciesConfig> _configs = [];
  SpeciesConfig? _selected;
  XFile? _photo;
  LocalQuality? _quality;
  Map<String, dynamic>? _metadata;
  OfflineQueue? _queue;
  QueuedCapture? _queued;
  List<QueuedCapture> _pending = [];
  List<Object> _queueIssues = [];
  FieldStore? _fieldStore;
  Map<String, dynamic>? _localAnimal;
  List<Map<String, dynamic>> _localAnimals = [];
  Set<String> _completedViews = {};
  String _view = fieldViews.first;
  String _session = '';
  bool _bundledSettings = false;
  String get _captureBackend =>
      _localAnimal == null ? _backend : provisionalBackend;
  String get _captureOperator => _localAnimal == null
      ? _environment.operatorId
      : (_fieldStore?.operatorId ?? '');
  String get _backend => _environment.backend;
  int _queuePage = 0;
  int _tab = 0;
  bool _cachedSettings = false;
  static const _pageSize = 50;
  Object? _message;
  bool _messageError = false;
  String? _cameraError;
  bool _busy = false;
  bool _loading = true;
  bool _saved = false;
  bool _active = true;
  int _cameraGeneration = 0;
  bool _measuringAr = false;

  void _showMessage(Object message, {bool error = false}) {
    setState(() {
      _message = message;
      _messageError = error;
    });
  }

  @override
  void initState() {
    super.initState();
    _environment =
        widget.environment ??
        CaptureEnvironment.native(
          backupShareText: () => const UiText(
            'Chorvam phone backup — save a copy outside this app.',
          ).resolve(context),
        );
    _operator.text = _environment.operatorId;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadConfigs());
    unawaited(_openCamera());
  }

  Future<void> _loadConfigs() async {
    setState(() => _loading = true);
    try {
      _queue ??= await _environment.openQueue();
      if (_environment.fieldTools && _fieldStore == null) {
        _fieldStore = FieldStore(_queue!.root);
        await _fieldStore!.initialize();
        _localAnimals = await _fieldStore!.records('animal');
        _session = fieldSession(_environment.now());
        if (_localAnimals.isNotEmpty && _animal.text.isEmpty) {
          _localAnimal = _localAnimals.last;
          _animal.text = _localAnimal!['label'] as String;
          _operator.text = _fieldStore!.operatorId;
        }
      }
      List<SpeciesConfig> configs;
      var cached = false;
      var bundled = false;
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
        if (configs.isEmpty) {
          if (!_environment.fieldTools) rethrow;
          configs = await bundledSpecies();
          bundled = true;
        }
        cached = true;
      }
      if (configs.isEmpty) {
        throw Exception('No species is enabled on the backend');
      }
      if (!mounted) return;
      setState(() {
        _configs = configs;
        _selected = configs.first;
        _cachedSettings = cached;
        _bundledSettings = bundled;
        _messageError = false;
        _message = cached
            ? UiText(
                "Offline settings loaded. Save captures now; upload when the backend is available.",
              )
            : null;
      });
      await _refreshQueue();
    } catch (error) {
      if (mounted) {
        _showMessage(
          UiText(
            "Connect to the backend once to cache settings, then retry. {0}",
            [userError(error)],
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _refreshQueue() async {
    if (_queue == null) return;
    try {
      final pending = await _queue!.pending(_captureBackend, _captureOperator);
      if (_fieldStore != null) {
        _completedViews = await _fieldStore!.completed(_animal.text, _session);
        _localAnimals = await _fieldStore!.records('animal');
      }
      if (mounted) {
        setState(() {
          _pending = pending;
          _queuePage = _queuePage.clamp(
            0,
            pending.isEmpty ? 0 : (pending.length - 1) ~/ _pageSize,
          );
          _queueIssues = List.of(_queue!.issues);
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _queueIssues = [
            UiText("Queue review failed: {0}. Local files retained.", [
              userError(error),
            ]),
          ],
        );
      }
    }
  }

  Future<void> _syncQueue() async {
    if (_localAnimal != null) return;
    if (_busy || _queue == null) return;
    setState(() => _busy = true);
    try {
      final count = await _queue!.sync(
        _backend,
        _environment.operatorId,
        _api.upload,
      );
      final acknowledged =
          _queued != null && await _queue!.acknowledged(_queued!);
      if (mounted) {
        setState(() {
          _message = UiText(
            "Uploaded {0} queued captures. Local originals and receipts retained.",
            [count],
          );
          _messageError = false;
          if (_queued != null) _saved = acknowledged;
        });
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          UiText("Queue paused: {0}. Pending captures remain on this phone.", [
            userError(error),
          ]),
          error: true,
        );
      }
    } finally {
      await _refreshQueue();
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _showReceipts() async {
    try {
      final saved = await _queue!.receipts(_backend, _environment.operatorId);
      if (!mounted) return;
      setState(() => _queueIssues = List.of(_queue!.issues));
      var page = 0;
      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const FieldText(UiText("Saved upload receipts")),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (saved.isEmpty)
                      const FieldText(UiText("No uploads acknowledged yet."))
                    else
                      for (final item
                          in saved.skip(page * _pageSize).take(_pageSize))
                        _receiptTile(item),
                  ],
                ),
              ),
            ),
            actions: [
              if (saved.length > _pageSize) ...[
                TextButton(
                  onPressed: page > 0 ? () => update(() => page--) : null,
                  child: const FieldText(UiText("Previous receipts")),
                ),
                FieldText(
                  UiText("Page {0} of {1}", [
                    page + 1,
                    (saved.length + _pageSize - 1) ~/ _pageSize,
                  ]),
                ),
                TextButton(
                  onPressed: (page + 1) * _pageSize < saved.length
                      ? () => update(() => page++)
                      : null,
                  child: const FieldText(UiText("Next receipts")),
                ),
              ],
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const FieldText(UiText("Close")),
              ),
            ],
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        _showMessage(
          UiText("Receipt review failed: {0}. Local files retained.", [
            userError(error),
          ]),
          error: true,
        );
      }
    }
  }

  Future<void> _exportBackup(Rect origin) async {
    if (_busy || _queue == null) return;
    setState(() {
      _busy = true;
      _message = UiText("Preparing phone backup…");
      _messageError = false;
    });
    try {
      final directory = await _environment.exportDirectory();
      await directory.create(recursive: true);
      final file = File(
        '${directory.path}/biolivestock-${DateTime.now().microsecondsSinceEpoch}.zip',
      );
      final manifest = await _environment.backup(_queue!.root.path, file.path);
      if (!mounted) return;
      await _environment.share(file, origin);
      if (mounted) {
        _showMessage(
          UiText(
            "Verified backup of {0} files. Save a copy outside this app. Originals retained.",
            [(manifest['files'] as Map).length],
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        _showMessage(
          UiText("Backup failed: {0}. Originals retained on this phone.", [
            userError(error),
          ]),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _openQueued(QueuedCapture entry) {
    if (_busy || _photo != null) return;
    final quality = entry.journal.quality;
    _animal.text = entry.metadata['animal_id'] as String;
    _localAnimal = entry.backend == provisionalBackend
        ? _localAnimals.firstWhere((a) => a['label'] == _animal.text)
        : null;
    _operator.text = entry.metadata['operator_id'] as String;
    setState(() {
      _tab = 0;
      _queued = entry;
      _photo = XFile(entry.imagePath);
      _metadata = entry.metadata;
      _quality = LocalQuality(
        quality.blurVariance,
        quality.brightness,
        quality.reasons,
      );
      _saved = false;
      _messageError = false;
      _message = UiText(
        "Recovered {0} from this phone. Labels/time preserved.",
        [entry.metadata['animal_id']],
      );
    });
  }

  Future<void> _openCamera() async {
    if (_measuringAr) return;
    final generation = ++_cameraGeneration;
    CaptureCamera? candidate;
    try {
      candidate = await _environment.openCamera();
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
      if (mounted) {
        setState(() {});
      }
    } else if (_camera == null && !_measuringAr) {
      unawaited(_openCamera());
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    final config = _selected;
    if (_busy || camera == null || config == null || _queue == null) {
      return;
    }
    if (!(_form.currentState?.validate() ?? false)) {
      final formContext = _form.currentContext;
      if (formContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            formContext,
            duration: const Duration(milliseconds: 200),
            alignment: 1,
          ),
        );
      }
      return;
    }
    if (_localAnimal != null && !validFieldOperator(_captureOperator)) {
      _showMessage(
        const UiText('Set an offline operator ID in Tools first.'),
        error: true,
      );
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
      _messageError = false;
    });
    FocusScope.of(context).unfocus();
    XFile? photo;
    try {
      // Snapshot labels before asynchronous work; fields stay locked during capture.
      final animalId = _animal.text.trim();
      final operatorId = _captureOperator;
      final timestamp = _environment.now().toUtc();
      photo = await camera.takePicture();
      final gps = await _environment.gps();
      final deviceSignals = await _environment.deviceSignals();
      final quality = await _environment.quality(photo, config);
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
            }, _captureBackend)
          : null;
      Object? fieldWarning;
      if (queued != null && _fieldStore != null) {
        try {
          await _fieldStore!.recordScan(
            queued,
            _localAnimal,
            _view,
            _session,
            config.toJson(),
          );
        } catch (error) {
          fieldWarning = UiText(
            'Original saved; field ledger needs review: {0}',
            [userError(error)],
          );
        }
        try {
          final save = _environment.saveGallery;
          if (save != null) {
            final name =
                '${animalId}_${_view}_${timestamp.toIso8601String().replaceAll(RegExp(r'[:.]'), '-')}_${queued.key.substring(0, 8)}';
            await save(queued.imagePath, name);
            await _fieldStore!.append('field-gallery-${queued.key}.json', {
              'version': 1,
              'request_key': queued.key,
              'album': 'Chorvam',
              'name': name,
              'saved': true,
            });
          }
        } catch (error) {
          fieldWarning = UiText(
            'Original saved. Gallery copy failed; check permission and storage. {0}',
            [userError(error)],
          );
        }
      }
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
          _message = UiText(
            "Saved on this phone. Upload now or collect the next capture.",
          );
          if (fieldWarning != null) {
            _message = fieldWarning;
            _messageError = true;
          }
        }
      });
      if (queued != null) {
        await _deletePhoto(photo);
      }
      await _refreshQueue();
    } catch (error) {
      await _deletePhoto(photo);
      if (mounted) {
        _showMessage(
          UiText("Capture failed: {0}", [userError(error)]),
          error: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _newAnimal() async {
    if (_busy || _photo != null || _queue == null || _selected == null) return;
    setState(() => _busy = true);
    try {
      final animal = await issueAnimalDialog(
        context,
        _api,
        RegistryJournal(_queue!.root, _backend, _environment.operatorId),
        _selected!,
      );
      if (animal != null && mounted) {
        if (animal['lifecycle'] != 'active') {
          _showMessage(
            UiText(
              "This ID is now archived. History retained; choose an active animal.",
            ),
            error: true,
          );
          return;
        }
        _animal.text = animal['animal_id'] as String;
        _localAnimal = null;
        _operator.text = _environment.operatorId;
        _showMessage(
          UiText(
            "ID {0} is registered. Write it on the tag/ledger and keep using this ID.",
            [animal['animal_id']],
          ),
        );
      }
    } catch (error) {
      if (mounted) _showMessage(userError(error), error: true);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _useRegisteredAnimal(Map<String, dynamic> animal) {
    if (_busy || _photo != null) {
      setState(() => _tab = 0);
      _showMessage(
        UiText("Finish the open capture before choosing another animal."),
        error: true,
      );
      return;
    }
    _animal.text = animal['animal_id'] as String;
    _localAnimal = null;
    _operator.text = _environment.operatorId;
    setState(() {
      _selected = _configs.firstWhere(
        (config) => config.species.name == animal['species'],
      );
      _tab = 0;
      _message = null;
    });
  }

  Future<void> _upload() async {
    if (_queued?.backend == provisionalBackend) return;
    if (_queued == null || _queue == null || _busy || _saved) return;
    setState(() => _busy = true);
    try {
      final result = await _queue!.uploadOne(_queued!, _api.upload);
      if (!mounted) return;
      setState(() {
        _saved = true;
        _messageError = false;
        _message = result['crop_status'] == 'cropped'
            ? UiText("Saved original and muzzle crop. Capture {0}", [
                result['id'],
              ])
            : UiText(
                "Saved original. Cropping is pending a trained model. Capture {0}",
                [result['id']],
              );
      });
    } catch (error) {
      if (mounted) {
        _showMessage(
          UiText("Upload failed: {0}. Original retained on this phone.", [
            userError(error),
          ]),
          error: true,
        );
      }
    } finally {
      await _refreshQueue();
      if (mounted) {
        setState(() => _busy = false);
      }
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
      if (_fieldStore != null && _completedViews.length < 6) {
        _view = fieldViews.firstWhere(
          (v) => !_completedViews.contains(v),
          orElse: () => fieldViews.first,
        );
      }
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
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              size: 34,
              color: Colors.white70,
            ),
            const SizedBox(height: 12),
            const FieldText(
              UiText("Camera unavailable"),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            const FieldText(
              UiText("Allow camera access in device settings, then try again."),
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            TextButton(
              onPressed: _openCamera,
              style: TextButton.styleFrom(foregroundColor: Colors.white),
              child: const FieldText(UiText("Retry camera")),
            ),
          ],
        ),
      );
    }
    if (_camera == null || !_camera!.initialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }
    return Center(
      child: AspectRatio(
        aspectRatio: _camera!.aspectRatio,
        child: _camera!.preview(),
      ),
    );
  }

  Widget _cameraCard() => ClipRRect(
    borderRadius: BorderRadius.circular(24),
    child: Container(
      color: const Color(0xff162c23),
      height: _photo == null ? 240 : 280,
      child: Stack(
        fit: StackFit.expand,
        children: [
          _preview(),
          if (_photo == null &&
              _cameraError == null &&
              _camera?.initialized == true) ...[
            IgnorePointer(child: CustomPaint(painter: MuzzleGuide())),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 76,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xcc000000)],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 14,
              left: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: .72),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.camera_alt_outlined,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 6),
                    FieldText(
                      UiText("CAMERA"),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned(
              bottom: 14,
              left: 16,
              right: 16,
              child: FieldText(
                UiText("Keep one muzzle fully inside the guide"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Future<void> _offlineOperator() async {
    if (_busy || _photo != null || _fieldStore == null) return;
    final id = await fieldOperatorDialog(context, _fieldStore!.operatorId);
    if (id == null) return;
    try {
      await _fieldStore!.saveOperator(id);
      if (mounted) {
        setState(() {
          if (_localAnimal != null) _operator.text = id;
        });
      }
      await _refreshQueue();
    } catch (e) {
      if (mounted) _showMessage(userError(e), error: true);
    }
  }

  Future<void> _newLocalAnimal() async {
    if (_busy || _photo != null || _fieldStore == null) return;
    if (_fieldStore!.operatorId.isEmpty) {
      await _offlineOperator();
    }
    if (!mounted || _fieldStore!.operatorId.isEmpty) return;
    final animal = await fieldAnimalDialog(
      context,
      _fieldStore!,
      _environment.now(),
    );
    if (animal != null && mounted) {
      setState(() {
        _localAnimal = animal;
        _animal.text = animal['label'] as String;
        _operator.text = _fieldStore!.operatorId;
        _tab = 0;
      });
      await _refreshQueue();
    }
  }

  Future<void> _openAr() async {
    if (_busy ||
        _photo != null ||
        _localAnimal == null ||
        _fieldStore == null) {
      return;
    }
    _measuringAr = true;
    ++_cameraGeneration;
    final camera = _camera;
    _camera = null;
    try {
      await camera?.dispose();
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ArScreen(store: _fieldStore!, animal: _localAnimal!),
        ),
      );
    } finally {
      _measuringAr = false;
      if (mounted && _active) await _openCamera();
    }
  }

  Widget _fieldPanel() => FieldCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FieldText(
          UiText(
            _bundledSettings ? 'Bundled offline rules' : 'Field collection',
          ),
        ),
        const SizedBox(height: 8),
        const FieldText(
          UiText(
            'Temporary label only. Not registered on the server; no automatic registration or sync.',
          ),
        ),
        if (_localAnimal != null) ...[
          OutlinedButton(
            onPressed: _busy || _photo != null ? null : _openAr,
            child: const FieldText(UiText('AR weight and valuation')),
          ),
          SelectableText(
            '${_localAnimal!['label']} · ${_localAnimal!['tag']}\n${_localAnimal!['notes']}',
          ),
          FieldText(
            UiText('Checklist: {0}/6 distinct views', [_completedViews.length]),
          ),
        ],
        OutlinedButton(
          onPressed: _busy || _photo != null ? null : _newLocalAnimal,
          child: const FieldText(UiText('New temporary animal')),
        ),
        if (_localAnimals.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey('local-${_localAnimal?['label']}'),
            initialValue: _localAnimal?['label'] as String?,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: const UiText('Choose local animal').resolve(context),
            ),
            items: [
              for (final a in _localAnimals)
                DropdownMenuItem(
                  value: a['label'] as String,
                  child: Text(
                    '${a['label']} · ${a['tag']}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: _busy || _photo != null
                ? null
                : (label) {
                    setState(() {
                      _localAnimal = _localAnimals.firstWhere(
                        (a) => a['label'] == label,
                      );
                      _animal.text = label!;
                      _operator.text = _fieldStore!.operatorId;
                    });
                    unawaited(_refreshQueue());
                  },
          ),
        if (_localAnimal != null)
          TextButton(
            onPressed: _busy || _photo != null
                ? null
                : () {
                    setState(() {
                      _localAnimal = null;
                      _animal.clear();
                      _operator.text = _environment.operatorId;
                    });
                    unawaited(_refreshQueue());
                  },
            child: const FieldText(UiText('Use existing server ID')),
          ),
        if (_photo == null) ...[
          const SizedBox(height: 8),
          TextFormField(
            initialValue: _session,
            key: const ValueKey('field-session'),
            enabled: !_busy,
            maxLength: 80,
            decoration: InputDecoration(
              labelText: const UiText(
                'Visit session (date-V1, V2...)',
              ).resolve(context),
            ),
            onChanged: (v) {
              _session = v;
              unawaited(_refreshQueue());
            },
          ),
          DropdownButtonFormField<String>(
            key: ValueKey('view-$_view'),
            initialValue: _view,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: const UiText('Capture view').resolve(context),
            ),
            items: [
              for (final v in fieldViews)
                DropdownMenuItem(value: v, child: FieldText(UiText(v))),
            ],
            onChanged: _busy ? null : (v) => setState(() => _view = v!),
          ),
        ],
        if (_localAnimal != null)
          const FieldText(
            UiText(
              'Local originals are retained. Permanent registration and upload require a later reviewed mapping.',
            ),
          ),
      ],
    ),
  );

  Widget _identityCard() {
    final editable = !_busy && _photo == null;
    return FieldCard(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.sell_outlined,
                  size: 18,
                  color: FieldColors.green,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FieldText(
                    UiText("Animal details"),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _animal,
              enabled: editable && _localAnimal == null,
              validator: (value) =>
                  animalValidation(context, validateAnimalId(value)),
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                label: FieldText(UiText("Animal ID")),
                hint: FieldText(UiText("Existing ID or issue a new one below")),
                prefixIcon: Icon(Icons.tag_rounded),
              ),
            ),
            const SizedBox(height: 12),
            if (_configs.isNotEmpty)
              DropdownButtonFormField<SpeciesConfig>(
                initialValue: _selected,
                isExpanded: true,
                decoration: const InputDecoration(
                  label: FieldText(UiText("Species")),
                  prefixIcon: Icon(Icons.grass_rounded),
                ),
                items: _configs
                    .map(
                      (config) => DropdownMenuItem(
                        value: config,
                        child: FieldText(speciesLabel(config.species.name)),
                      ),
                    )
                    .toList(),
                onChanged: editable
                    ? (value) => setState(() => _selected = value)
                    : null,
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.badge_outlined,
                  size: 14,
                  color: FieldColors.muted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: FieldText(
                    UiText("Operator · {0}", [_operator.text]),
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed:
                  editable &&
                      _localAnimal == null &&
                      !_loading &&
                      _queue != null &&
                      _selected?.numbering != null
                  ? _newAnimal
                  : null,
              icon: const Icon(Icons.add),
              label: const FieldText(UiText("New animal ID")),
            ),
            if (_operator.text.trim().isEmpty)
              const FieldText(
                UiText("Configure your operator credential before collecting."),
                style: TextStyle(color: FieldColors.red),
              ),
          ],
        ),
      ),
    );
  }

  Widget _qualityCard() {
    final quality = _quality!;
    return FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                quality.passed
                    ? Icons.check_circle_rounded
                    : Icons.error_outline_rounded,
                color: quality.passed ? FieldColors.green : FieldColors.red,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FieldText(
                  quality.passed
                      ? UiText("Local quality check passed")
                      : UiText("Please retake"),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final reason in quality.reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FieldText(
                qualityReason(reason),
                style: const TextStyle(color: FieldColors.red),
              ),
            ),
          FieldTag(
            _metadata?['gps'] == null
                ? UiText("GPS unavailable")
                : UiText("GPS recorded"),
            icon: _metadata?['gps'] == null
                ? Icons.location_off_outlined
                : Icons.location_on_outlined,
            caution: _metadata?['gps'] == null,
          ),
          const SizedBox(height: 10),
          const FieldText(
            UiText("The server makes the final quality and framing check."),
            style: TextStyle(fontSize: 12),
          ),
          ExpansionTile(
            key: const PageStorageKey('capture-quality-details'),
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            title: const FieldText(
              UiText("Capture details"),
              style: TextStyle(fontSize: 13),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: FieldSelectableText(
                  UiText('Sharpness: {0} · Brightness: {1}\n{2}', [
                    quality.blurVariance.toStringAsFixed(1),
                    quality.brightness.toStringAsFixed(1),
                    UiText('{0}\n{1}', [
                      _metadata?['timestamp'] ?? '',
                      _queued == null
                          ? ''
                          : UiText('Request: {0}', [_queued!.key]),
                    ]),
                  ]),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              if (_metadata?['gps'] == null)
                const Align(
                  alignment: Alignment.centerLeft,
                  child: FieldText(
                    UiText("Location is saved as empty; no GPS is invented."),
                    style: TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _messageCard() => FieldCard(
    color: _messageError
        ? const Color(0xffffefed)
        : _saved || _queued != null
        ? FieldColors.mint
        : FieldColors.cream,
    padding: const EdgeInsets.all(16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          _messageError
              ? Icons.error_outline_rounded
              : _saved
              ? Icons.cloud_done_outlined
              : Icons.info_outline,
          size: 20,
          color: _messageError ? FieldColors.red : FieldColors.forest,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: FieldSelectableText(
            _message!,
            style: const TextStyle(fontSize: 13, color: FieldColors.ink),
          ),
        ),
      ],
    ),
  );

  Widget _issuesCard() => FieldCard(
    color: FieldColors.cream,
    padding: const EdgeInsets.all(12),
    child: ExpansionTile(
      key: const PageStorageKey('capture-queue-issues'),
      leading: const Icon(
        Icons.warning_amber_rounded,
        color: FieldColors.amber,
      ),
      title: FieldText(
        UiText("{0} local items need review", [_queueIssues.length]),
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: const FieldText(
        UiText("Files retained on this phone"),
        style: TextStyle(fontSize: 12),
      ),
      children: [
        for (final issue in _queueIssues)
          Padding(
            padding: const EdgeInsets.all(8),
            child: FieldSelectableText(
              issue,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    ),
  );

  List<Widget> _captureContent() => [
    FieldHeading(
      eyebrow: UiText("Field collection"),
      title: _photo == null
          ? UiText("One muzzle at a time.")
          : UiText("Review your capture."),
      subtitle: _photo == null
          ? UiText("Get close. Hold steady. Use even light.")
          : UiText('{0} · {1}', [
              _metadata?['animal_id'] ?? '',
              speciesLabel(_metadata?['species'] as String? ?? ''),
            ]),
    ),
    const SizedBox(height: 16),
    _cameraCard(),
    if (_fieldStore != null) ...[const SizedBox(height: 12), _fieldPanel()],
    const SizedBox(height: 16),
    if (_photo == null) _identityCard(),
    if (_quality != null) _qualityCard(),
    if (_loading)
      const Padding(
        padding: EdgeInsets.only(top: 16),
        child: LinearProgressIndicator(),
      ),
    if (!_loading && _configs.isEmpty)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: OutlinedButton.icon(
          onPressed: _loadConfigs,
          icon: const Icon(Icons.refresh),
          label: const FieldText(UiText("Retry backend settings")),
        ),
      ),
    if (_message != null) ...[const SizedBox(height: 16), _messageCard()],
    if (_queueIssues.isNotEmpty) ...[const SizedBox(height: 16), _issuesCard()],
    const SizedBox(height: 16),
    Row(
      children: [
        const Icon(
          Icons.phone_android_outlined,
          size: 17,
          color: FieldColors.green,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: FieldText(
            UiText("{0} waiting to upload · originals stay on this phone", [
              _pending.length,
            ]),
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    ),
    TextButton(
      onPressed: _busy ? null : () => setState(() => _tab = 1),
      child: const FieldText(UiText("View saved captures")),
    ),
  ];

  Widget _queuedTile(QueuedCapture entry) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: FieldCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 42,
          height: 46,
          decoration: BoxDecoration(
            color: FieldColors.mint,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.photo_camera_outlined,
            color: FieldColors.green,
          ),
        ),
        title: FieldText(
          UiText('{0} · {1}', [
            entry.metadata['animal_id'],
            speciesLabel(entry.metadata['species'] as String),
          ]),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        subtitle: FieldText(
          '${entry.metadata["timestamp"]}',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: _busy ? null : () => _openQueued(entry),
      ),
    ),
  );

  Widget _receiptTile(Map<String, dynamic> item) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FieldCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldText(
            UiText('{0} · {1}', [
              item['animal_id'],
              speciesLabel(item['species'] as String),
            ]),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const FieldTag(
            UiText("Upload acknowledged"),
            icon: Icons.cloud_done_outlined,
          ),
          const SizedBox(height: 10),
          FieldSelectableText(
            UiText("Capture: {0}\nRequest: {1}\nFile: {2}", [
              item["id"],
              item["request_key"],
              item["file_path"],
            ]),
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
  );

  List<Widget> _savedContent() => [
    const FieldHeading(
      eyebrow: UiText("On this phone"),
      title: UiText("Saved captures."),
      subtitle: UiText("Review originals, then upload when you are ready."),
    ),
    const SizedBox(height: 20),
    FieldCard(
      color: FieldColors.forest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldText(
            '${_pending.length}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 42,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          const FieldText(
            UiText("captures waiting to upload"),
            style: TextStyle(color: Colors.white, fontSize: 14),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xffd4edbc),
              foregroundColor: FieldColors.forest,
              disabledBackgroundColor: Colors.white12,
              disabledForegroundColor: Colors.white70,
            ),
            onPressed: !_busy && _pending.isNotEmpty && _localAnimal == null
                ? _syncQueue
                : null,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const FieldText(UiText("Upload pending captures")),
          ),
        ],
      ),
    ),
    const SizedBox(height: 12),
    OutlinedButton.icon(
      onPressed: !_busy && _queue != null ? _showReceipts : null,
      icon: const Icon(Icons.receipt_long_outlined),
      label: const FieldText(UiText("Review saved upload receipts")),
    ),
    if (_message != null) ...[const SizedBox(height: 12), _messageCard()],
    if (_queueIssues.isNotEmpty) ...[const SizedBox(height: 12), _issuesCard()],
    const SizedBox(height: 20),
    if (_photo != null)
      FieldCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FieldText(
              UiText("A capture is open for review"),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const FieldText(
              UiText(
                "Finish or move to the next capture before opening another original.",
              ),
            ),
            TextButton(
              onPressed: () => setState(() => _tab = 0),
              child: const FieldText(UiText("Return to capture")),
            ),
          ],
        ),
      )
    else if (_pending.isEmpty)
      const FieldCard(
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 36,
              color: FieldColors.green,
            ),
            SizedBox(height: 12),
            FieldText(
              UiText("Nothing waiting to upload"),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: FieldColors.ink,
              ),
            ),
            SizedBox(height: 6),
            FieldText(
              UiText(
                "New captures appear here after passing local quality checks.",
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      )
    else ...[
      FieldText(
        UiText("Pending originals"),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 12),
      for (final entry in _pending.skip(_queuePage * _pageSize).take(_pageSize))
        _queuedTile(entry),
      if (_pending.length > _pageSize)
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextButton(
              onPressed: !_busy && _queuePage > 0
                  ? () => setState(() => _queuePage--)
                  : null,
              child: const FieldText(UiText("Previous captures")),
            ),
            FieldText(
              UiText("Page {0} of {1}", [
                _queuePage + 1,
                (_pending.length + _pageSize - 1) ~/ _pageSize,
              ]),
              style: const TextStyle(fontSize: 12),
            ),
            TextButton(
              onPressed:
                  !_busy && (_queuePage + 1) * _pageSize < _pending.length
                  ? () => setState(() => _queuePage++)
                  : null,
              child: const FieldText(UiText("Next captures")),
            ),
          ],
        ),
    ],
  ];

  List<Widget> _toolsContent() => [
    const FieldCard(child: LanguageSettings()),
    if (_fieldStore != null) ...[
      const SizedBox(height: 12),
      FieldCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldText(
              UiText('Offline operator: {0}', [_fieldStore!.operatorId]),
            ),
            OutlinedButton(
              onPressed: _busy || _photo != null ? null : _offlineOperator,
              child: const FieldText(UiText('Set offline operator')),
            ),
          ],
        ),
      ),
    ],
    const SizedBox(height: 16),
    const FieldHeading(
      eyebrow: UiText("Field essentials"),
      title: UiText("Keep your data safe."),
      subtitle: UiText("Back up your phone and check collection settings."),
    ),
    const SizedBox(height: 20),
    FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: FieldColors.mint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.save_alt_rounded, color: FieldColors.green),
          ),
          const SizedBox(height: 16),
          FieldText(
            UiText("Phone backup"),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const FieldText(
            UiText(
              "Export originals, capture details and upload receipts as a verified ZIP. Save a copy outside this app.",
            ),
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (buttonContext) => SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: !_busy && _queue != null
                    ? () {
                        final box =
                            buttonContext.findRenderObject() as RenderBox;
                        unawaited(
                          _exportBackup(
                            box.localToGlobal(Offset.zero) & box.size,
                          ),
                        );
                      }
                    : null,
                icon: const Icon(Icons.ios_share_rounded),
                label: const FieldText(UiText("Export phone backup")),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const FieldText(
            UiText(
              "Includes all local captures/operators. Originals stay on this phone. Credentials are excluded.",
            ),
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldText(
            UiText("Collection settings"),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          FieldTag(
            _loading
                ? UiText("Loading settings")
                : _configs.isEmpty
                ? UiText("Setup needed")
                : _cachedSettings
                ? UiText("Offline settings")
                : UiText("Settings loaded"),
            icon: _cachedSettings
                ? Icons.cloud_off_outlined
                : Icons.tune_rounded,
            caution: _cachedSettings || _configs.isEmpty,
          ),
          const SizedBox(height: 14),
          FieldSelectableText(
            UiText("Operator\n{0}", [_operator.text]),
            minLines: 3,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          FieldSelectableText(
            UiText("Backend\n{0}", [_backend]),
            minLines: 3,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: !_busy && !_loading && _photo == null
                ? _loadConfigs
                : null,
            icon: const Icon(Icons.refresh_rounded),
            label: const FieldText(UiText("Refresh settings")),
          ),
          const SizedBox(height: 10),
          const FieldText(
            UiText(
              "Connect once to load capture rules. Cached rules let you collect offline.",
            ),
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    ),
    const SizedBox(height: 16),
    const FieldCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldText(
            UiText("Before you head to the farm"),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: FieldColors.ink,
            ),
          ),
          SizedBox(height: 10),
          FieldText(
            UiText(
              "01  Check free space and battery.\n02  Keep one muzzle visible, close and sharp.\n03  Use even light; avoid glare and deep shade.\n04  Back up before clearing or uninstalling the app.",
            ),
          ),
        ],
      ),
    ),
    if (_message != null) ...[const SizedBox(height: 16), _messageCard()],
    if (_queueIssues.isNotEmpty) ...[const SizedBox(height: 16), _issuesCard()],
  ];

  Widget _captureActions() => Padding(
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 660),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_photo == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    !_busy &&
                        _camera?.initialized == true &&
                        _selected != null &&
                        _queue != null &&
                        !_loading &&
                        _captureOperator.trim().isNotEmpty &&
                        (_fieldStore == null || _session.trim().isNotEmpty)
                    ? _capture
                    : null,
                icon: const Icon(Icons.camera_alt_rounded),
                label: const FieldText(UiText("Capture")),
              ),
            )
          else ...[
            if (_quality?.passed ?? false)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed:
                      !_busy &&
                          !_saved &&
                          _queued?.backend != provisionalBackend
                      ? _upload
                      : null,
                  icon: Icon(
                    _saved
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_upload_outlined,
                  ),
                  label: FieldText(
                    _saved ? UiText("Uploaded") : UiText("Upload capture"),
                  ),
                ),
              ),
            if (_quality?.passed ?? false) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _retake,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: FieldText(
                  _queued != null
                      ? UiText("Next capture (saved locally)")
                      : UiText("Retake"),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      titleSpacing: 20,
      title: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: FieldColors.forest,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.center_focus_strong_rounded,
              color: Color(0xffd4edbc),
              size: 23,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: FieldText(
              'Chorvam',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -.5,
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (MediaQuery.sizeOf(context).width >= 360 &&
            MediaQuery.textScalerOf(context).scale(12) <= 16)
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: FieldTag(
              _cachedSettings ? UiText("Offline rules") : UiText("Local first"),
              icon: _cachedSettings
                  ? Icons.cloud_off_outlined
                  : Icons.phone_android_rounded,
              caution: _cachedSettings,
            ),
          ),
      ],
    ),
    body: SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              if (_busy) const LinearProgressIndicator(minHeight: 3),
              Expanded(
                child: _tab == 2
                    ? (_fieldStore != null &&
                              (_bundledSettings || _localAnimal != null)
                          ? SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: _fieldPanel(),
                            )
                          : _queue != null && _configs.isNotEmpty
                          ? AnimalRegistryScreen(
                              environment: _environment,
                              queueRoot: _queue!.root,
                              configs: _configs,
                              onCapture: _useRegisteredAnimal,
                            )
                          : const Center(
                              child: FieldText(
                                UiText(
                                  "Load species settings and phone storage in Tools first.",
                                ),
                              ),
                            ))
                    : _tab == 1
                    ? ListView(
                        key: PageStorageKey('field-tab-$_tab'),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        children: _savedContent(),
                      )
                    : SingleChildScrollView(
                        key: PageStorageKey('field-tab-$_tab'),
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: _tab == 0
                              ? _captureContent()
                              : _toolsContent(),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    ),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: FieldColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_tab == 0) Center(child: _captureActions()),
            NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (value) {
                FocusScope.of(context).unfocus();
                setState(() => _tab = value);
              },
              destinations: [
                const FieldDestination(
                  icon: Icon(Icons.camera_alt_outlined),
                  selectedIcon: Icon(Icons.camera_alt_rounded),
                  label: UiText("Capture"),
                ),
                FieldDestination(
                  icon: Badge(
                    isLabelVisible: _pending.isNotEmpty,
                    label: FieldText('${_pending.length}'),
                    child: const Icon(Icons.inventory_2_outlined),
                  ),
                  selectedIcon: const Icon(Icons.inventory_2_rounded),
                  label: UiText("Saved"),
                ),
                const FieldDestination(
                  icon: Icon(Icons.assignment_ind_outlined),
                  selectedIcon: Icon(Icons.assignment_ind_rounded),
                  label: UiText("Animals"),
                ),
                const FieldDestination(
                  icon: Icon(Icons.tune_outlined),
                  selectedIcon: Icon(Icons.tune_rounded),
                  label: UiText("Tools"),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
