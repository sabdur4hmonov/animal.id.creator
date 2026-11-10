import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'ar_records.dart';
import 'capture_environment.dart';
import 'field_store.dart';
import 'localization.dart';
import 'quality_control.dart';
import 'snapshot_annotation.dart';
import 'species.dart';

class SidePhotoStore {
  SidePhotoStore(this.store);
  final FieldStore store;

  Future<Map<String, dynamic>> save({
    required Map animal,
    required String side,
    required File original,
    required DateTime captured,
    required LocalQuality quality,
    required Map<String, dynamic> config,
  }) async {
    if (!{'left', 'right'}.contains(side) ||
        !quality.passed ||
        config['enabled'] != true ||
        config['species'] != animal['species']) {
      throw const FormatException('Invalid side photo');
    }
    final exists = (await store.records('animal')).any(
      (a) => a['label'] == animal['label'] && a['species'] == animal['species'],
    );
    if (!exists) throw const FormatException('Animal is not in this phone');
    final bytes = await original.readAsBytes();
    final key = randomFieldKey(), filename = '$key.jpg';
    final destination = File('${store.root.path}/$filename');
    await destination.create(exclusive: true);
    await destination.writeAsBytes(bytes, flush: true);
    // Separate event type: never a muzzle scan, checklist item or upload journal.
    return ArRecords(store).save('side_photo', {
      'label': animal['label'],
      'species': animal['species'],
      'side': side,
      'captured_at': captured.toUtc().toIso8601String(),
      'file_path': filename,
      'sha256': sha256.convert(bytes).toString(),
      'max_scale_age_days': config['side_photos']['max_scale_age_days'],
      'config_sha256': configDigest(config),
      'quality': {
        'blur_variance': quality.blurVariance,
        'brightness': quality.brightness,
        'reasons': quality.reasons,
      },
      'purpose': 'future_weight_training_no_prediction',
    });
  }
}

class SidePhotoCamera extends StatefulWidget {
  const SidePhotoCamera({
    super.key,
    required this.store,
    required this.animal,
    required this.side,
    required this.config,
    required this.species,
    required this.environment,
  });
  final FieldStore store;
  final Map<String, dynamic> animal, config;
  final String side;
  final SpeciesConfig species;
  final CaptureEnvironment environment;
  @override
  State<SidePhotoCamera> createState() => _SidePhotoCameraState();
}

class _SidePhotoCameraState extends State<SidePhotoCamera>
    with WidgetsBindingObserver {
  CaptureCamera? camera;
  bool busy = false, active = true;
  int generation = 0;
  UiText? error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final g = ++generation;
    try {
      final next = await widget.environment.openCamera();
      if (!mounted || !active || g != generation) {
        await next.dispose();
        return;
      }
      setState(() => camera = next);
    } catch (e) {
      if (mounted) {
        setState(() => error = UiText('Capture failed: {0}', [userError(e)]));
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    active = state == AppLifecycleState.resumed;
    if (!active) {
      ++generation;
      final old = camera;
      camera = null;
      unawaited(old?.dispose());
      if (mounted) setState(() {});
    } else if (camera == null && !busy) {
      unawaited(_open());
    }
  }

  @override
  void dispose() {
    ++generation;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(camera?.dispose());
    super.dispose();
  }

  Future<void> _take() async {
    final current = camera, g = generation;
    if (current == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final captured = widget.environment.now();
      final photo = await current.takePicture();
      final quality = await widget.environment.quality(photo, widget.species);
      if (!mounted || !active || g != generation) return;
      if (!quality.passed) {
        setState(
          () => error = const UiText(
            'Photo quality is too low. Use even light, hold still, and retake.',
          ),
        );
        return;
      }
      await SidePhotoStore(widget.store).save(
        animal: widget.animal,
        side: widget.side,
        original: File(photo.path),
        captured: captured,
        quality: quality,
        config: widget.config,
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => error = UiText('Capture failed: {0}', [userError(e)]));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (active && camera == null) unawaited(_open());
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: FieldText(
          UiText(
            widget.side == 'left' ? 'Left body photo' : 'Right body photo',
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SidePhotoGuide(
            side: widget.side,
            rules: widget.config['side_photos'] as Map,
          ),
          if (camera?.initialized == true)
            AspectRatio(
              aspectRatio: camera!.aspectRatio,
              child: camera!.preview(),
            )
          else if (error == null)
            const LinearProgressIndicator(),
          if (error != null) FieldText(error!),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: busy || camera?.initialized != true ? null : _take,
          child: FieldText(UiText(busy ? 'Saving photo…' : 'Take photo')),
        ),
      ),
    ),
  );
}

class SidePhotoGuide extends StatelessWidget {
  const SidePhotoGuide({super.key, required this.side, required this.rules});
  final String side;
  final Map rules;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: 130,
        child: CustomPaint(
          painter: CowPointPainter(
            step: -1,
            right: side == 'right',
            showPoints: false,
          ),
        ),
      ),
      FieldText(
        UiText(
          'Fit the whole body, including feet. Start about {0}–{1} m away.',
          [
            rules['suggested_distance_min_m'],
            rules['suggested_distance_max_m'],
          ],
        ),
      ),
      const FieldText(
        UiText(
          'Collected for a future weight model. No weight is calculated from this photo.',
        ),
      ),
    ],
  );
}
