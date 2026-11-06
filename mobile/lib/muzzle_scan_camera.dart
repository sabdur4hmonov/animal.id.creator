import 'dart:async';
import 'package:flutter/material.dart';
import 'advisory_scan.dart';
import 'capture_environment.dart';
import 'field_store.dart';
import 'localization.dart';
import 'species.dart';

class MuzzleScanCamera extends StatefulWidget {
  const MuzzleScanCamera({
    super.key,
    required this.workflow,
    required this.species,
    this.profileId,
  });
  final FieldScanWorkflow workflow;
  final SpeciesConfig species;
  final String? profileId;
  @override
  State<MuzzleScanCamera> createState() => _MuzzleScanCameraState();
}

class _MuzzleScanCameraState extends State<MuzzleScanCamera>
    with WidgetsBindingObserver {
  CaptureCamera? camera;
  bool busy = false, active = true;
  int generation = 0;
  String view = fieldViews.first;
  UiText? error;
  CaptureEnvironment get env => widget.workflow.environment;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_open());
  }

  Future<void> _open() async {
    final g = ++generation;
    try {
      final next = await env.openCamera();
      if (!mounted || !active || g != generation) {
        await next.dispose();
        return;
      }
      setState(() => camera = next);
    } catch (e) {
      if (mounted && g == generation) {
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
    final current = camera;
    if (current == null || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    var completed = false;
    try {
      final when = env.now().toUtc(),
          operator = widget.workflow.store.operatorId;
      final photo = await current.takePicture(),
          quality = await env.quality(photo, widget.species);
      if (!quality.passed) {
        if (mounted) {
          setState(
            () => error = const UiText(
              'Photo quality is too low. Use even light, hold still, and retake.',
            ),
          );
        }
        return;
      }
      final gps = await env.gps(), signals = await env.deviceSignals();
      final draft = await widget.workflow.stage(
        photo.path,
        {
          'operator_id': operator,
          'species': widget.species.species.name,
          'timestamp': when.toIso8601String(),
          'gps': gps?['gps'],
          'gps_evidence': gps?['gps_evidence'],
          'device_signals': signals,
        },
        {
          'blur_variance': quality.blurVariance,
          'brightness': quality.brightness,
          'reasons': quality.reasons,
        },
        view,
        widget.species.toJson(),
        profileId: widget.profileId,
      );
      if (camera == current) {
        camera = null;
        await current.dispose();
      }
      if (mounted) {
        completed = true;
        Navigator.pop(context, draft);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = UiText('Capture failed: {0}', [userError(e)]));
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        if (!completed && active && camera == null) unawaited(_open());
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const FieldText(UiText('Scan animal'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const FieldText(
            UiText('Keep one muzzle centered and fill the frame.'),
          ),
          const SizedBox(height: 12),
          if (camera?.initialized == true)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: camera!.aspectRatio,
                child: camera!.preview(),
              ),
            )
          else if (error == null)
            const LinearProgressIndicator(),
          if (error != null) FieldText(error!),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: view,
            isExpanded: true,
            itemHeight: null,
            decoration: InputDecoration(
              labelText: const UiText('Photo view').resolve(context),
            ),
            items: [
              for (var i = 0; i < fieldViews.length; i++)
                DropdownMenuItem(
                  value: fieldViews[i],
                  child: FieldText(
                    UiText(
                      [
                        'Front 1/2',
                        'Front 2/2',
                        'Left 15° 1/2',
                        'Left 15° 2/2',
                        'Right 15° 1/2',
                        'Right 15° 2/2',
                      ][i],
                    ),
                  ),
                ),
            ],
            onChanged: busy ? null : (v) => setState(() => view = v!),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: busy || camera?.initialized != true ? null : _take,
              child: const FieldText(UiText('Take photo')),
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
  );
}
