import 'dart:async';
import 'dart:io';
import 'package:camera/camera.dart' show XFile;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'burst_capture.dart';
import 'quality_control.dart';
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
  bool videoMode = true;
  LocalQuality? streamQuality;
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
      setState(() {
        camera = next;
        if (next is! BurstCaptureCamera) videoMode = false;
      });
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
    if (videoMode) {
      await _burst();
      return;
    }
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

  Future<void> _burst() async {
    final current = camera;
    if (current == null || current is! BurstCaptureCamera || busy) return;
    final stream = current as BurstCaptureCamera;
    final rules = widget.workflow.config['burst_capture'] as Map;
    final collector = BurstCollector(rules, widget.species.quality);
    final g = generation, failed = Completer<void>();
    Directory? scratch;
    setState(() {
      busy = true;
      error = null;
      streamQuality = null;
    });
    try {
      await stream.startFrames((frame) {
        if (!mounted || !active || g != generation) return;
        final before = collector.analyzed;
        try {
          collector.receive(frame);
        } catch (_) {
          collector.fallback =
              'Burst frames are unsupported or too small. Use single photo mode.';
        }
        if (collector.fallback != null && !failed.isCompleted) {
          failed.complete();
        }
        if (before != collector.analyzed && mounted) {
          setState(() => streamQuality = collector.latest);
        }
      });
      await Future.any([
        Future<void>.delayed(
          Duration(milliseconds: rules['duration_ms'] as int),
        ),
        failed.future,
      ]);
      await stream.stopFrames();
      if (!mounted || !active || g != generation) return;
      if (collector.fallback != null) {
        setState(() {
          videoMode = false;
          error = UiText(collector.fallback!);
        });
        return;
      }
      if (collector.candidates.isEmpty) {
        setState(
          () => error = const UiText(
            'No sharp frames. Improve light and try again.',
          ),
        );
        return;
      }
      scratch = await Directory.systemTemp.createTemp('chorvam_burst_');
      final previews =
          <({BurstCandidate candidate, File photo, LocalQuality quality})>[];
      for (final candidate in collector.candidates) {
        final bytes = await compute(encodeBurstFrame, {
          'frame': candidate.frame,
          'jpeg_quality': rules['jpeg_quality'],
        });
        final photo = await File(
          '${scratch.path}/${candidate.index}.jpg',
        ).writeAsBytes(bytes, flush: true);
        final quality = await env.quality(XFile(photo.path), widget.species);
        if (quality.passed) {
          previews.add((candidate: candidate, photo: photo, quality: quality));
        }
      }
      if (previews.isEmpty) {
        if (mounted) {
          setState(
            () => error = const UiText(
              'No sharp frames. Improve light and try again.',
            ),
          );
        }
        return;
      }
      if (!mounted || !active || g != generation) return;
      final selected = await Navigator.of(context).push<List<int>>(
        MaterialPageRoute(
          builder: (_) => BurstFrameReview(
            photos: previews.map((p) => p.photo).toList(),
            scores: previews
                .map((p) => p.candidate.quality.blurVariance)
                .toList(),
          ),
        ),
      );
      if (selected == null ||
          selected.isEmpty ||
          !mounted ||
          !active ||
          g != generation) {
        return;
      }
      final gps = await env.gps(), signals = await env.deviceSignals();
      if (!mounted || !active || g != generation) return;
      final group = randomFieldKey();
      Map<String, dynamic>? first;
      for (final index in selected) {
        final item = previews[index], candidate = item.candidate;
        final draft = await widget.workflow.stage(
          item.photo.path,
          {
            'operator_id': widget.workflow.store.operatorId,
            'species': widget.species.species.name,
            'timestamp': candidate.frame.observedAt.toUtc().toIso8601String(),
            'gps': gps?['gps'],
            'gps_evidence': gps?['gps_evidence'],
            'device_signals': signals,
          },
          {
            'blur_variance': item.quality.blurVariance,
            'brightness': item.quality.brightness,
            'reasons': item.quality.reasons,
          },
          view,
          widget.species.toJson(),
          // Only the first photo inherits the explicitly opened profile context.
          profileId: first == null ? widget.profileId : null,
          captureGroup: group,
          provenance: {
            'capture_mode': 'burst_best_frame',
            'frame_index': candidate.index,
            'frame_timestamp': candidate.frame.observedAt
                .toUtc()
                .toIso8601String(),
            'luma_blur_variance': candidate.quality.blurVariance,
            'luma_brightness': candidate.quality.brightness,
            'frames_seen': collector.seen,
            'frames_analyzed': collector.analyzed,
            'raw_width': candidate.frame.width,
            'raw_height': candidate.frame.height,
            'rotation_degrees': candidate.frame.rotation,
            'rules': rules,
            'video_file_saved': false,
          },
        );
        first ??= draft;
      }
      if (mounted && first != null) Navigator.pop(context, first);
    } catch (e) {
      if (mounted) {
        setState(() {
          videoMode = false;
          error = const UiText(
            'Video capture is unavailable. Single photo mode is ready.',
          );
        });
      }
    } finally {
      try {
        await stream.stopFrames();
      } catch (_) {
        /* Camera may have been disposed by lifecycle. */
      }
      if (scratch != null) {
        try {
          await scratch.delete(recursive: true);
        } on FileSystemException {
          /* Temporary cache can be reclaimed by the OS. */
        }
      }
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
      appBar: AppBar(title: const FieldText(UiText('Scan animal'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<bool>(
            initialValue: videoMode,
            key: ValueKey(videoMode),
            isExpanded: true,
            itemHeight: null,
            items: const [
              DropdownMenuItem(
                value: true,
                child: FieldText(UiText('Video capture')),
              ),
              DropdownMenuItem(
                value: false,
                child: FieldText(UiText('Single photo')),
              ),
            ],
            onChanged: busy ? null : (v) => setState(() => videoMode = v!),
          ),
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
          if (videoMode) ...[
            const FieldText(
              UiText('Video is not stored. Review the sharpest frames.'),
            ),
            if (streamQuality != null) _sharpness(),
          ],
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
              child: FieldText(
                videoMode
                    ? const UiText('Capture best frames')
                    : const UiText('Take photo'),
              ),
            ),
            if (busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    ),
  );

  Widget _sharpness() {
    final q = streamQuality!,
        rules = widget.workflow.config['burst_capture'] as Map;
    final yellow =
        q.reasons.every((r) => r == 'blur') &&
        q.blurVariance >=
            (widget.species.quality['blur_min_variance'] as num) *
                (rules['soft_blur_ratio'] as num);
    final color = q.passed
        ? Colors.green
        : yellow
        ? Colors.orange
        : Colors.red;
    return Row(
      children: [
        Icon(Icons.circle, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: FieldText(
            q.passed
                ? const UiText('Sharp frame')
                : yellow
                ? const UiText('Hold still')
                : const UiText('Improve light or focus'),
          ),
        ),
      ],
    );
  }
}

class BurstFrameReview extends StatefulWidget {
  const BurstFrameReview({
    super.key,
    required this.photos,
    required this.scores,
  });
  final List<File> photos;
  final List<double> scores;
  @override
  State<BurstFrameReview> createState() => _BurstFrameReviewState();
}

class _BurstFrameReviewState extends State<BurstFrameReview> {
  final selected = <int>{0};
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const FieldText(UiText('Review best frames'))),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const FieldText(
          UiText('Confirm the animal separately for each selected photo.'),
        ),
        for (var i = 0; i < widget.photos.length; i++) ...[
          Image.file(
            widget.photos[i],
            cacheWidth: 480,
            height: 180,
            fit: BoxFit.contain,
          ),
          CheckboxListTile(
            value: selected.contains(i),
            title: FieldText(
              UiText('Frame {0} · sharpness {1}', [
                i + 1,
                widget.scores[i].toStringAsFixed(0),
              ]),
            ),
            onChanged: (v) => setState(
              () => v == true ? selected.add(i) : selected.remove(i),
            ),
          ),
        ],
      ],
    ),
    bottomNavigationBar: SafeArea(
      minimum: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => setState(
              () => selected.addAll(
                List.generate(widget.photos.length, (i) => i),
              ),
            ),
            child: const FieldText(UiText('Select all frames')),
          ),
          FilledButton(
            onPressed: selected.isEmpty
                ? null
                : () => Navigator.pop(context, selected.toList()..sort()),
            child: const FieldText(UiText('Use selected frames')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const FieldText(UiText('Retake')),
          ),
        ],
      ),
    ),
  );
}
