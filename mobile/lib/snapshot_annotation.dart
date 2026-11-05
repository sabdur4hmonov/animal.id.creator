import 'dart:convert';
import 'package:flutter/material.dart';
import 'depth_snapshot.dart';
import 'localization.dart';

const sidePointLabels = [
  '1 — Front end (the frontmost part of the chest)',
  '2 — Back end (under the tail)',
  '3 — Top of the back (highest point above the front legs)',
  '4 — Bottom of the chest (directly below point 3, behind the front legs)',
];
const snapshotViewLabels = {
  'left': '1/3 Left side',
  'right': '2/3 Right side',
  'front': '3/3 Front (optional)',
};

class SnapshotAnnotation extends StatefulWidget {
  const SnapshotAnnotation({
    super.key,
    required this.frame,
    required this.view,
    required this.rules,
  });
  final Map<String, dynamic> frame;
  final String view;
  final Map rules;
  @override
  State<SnapshotAnnotation> createState() => _SnapshotAnnotationState();
}

class _SnapshotAnnotationState extends State<SnapshotAnnotation> {
  final points = <Map<String, dynamic>>[];
  String? error;
  int get requiredPoints => widget.view == 'front' ? 2 : 4;
  String t(String key) => UiText(key).resolve(context);
  void finish(String action) => Navigator.pop(context, {
    '...': 'snapshot_annotation',
    'action': action,
    'points': points,
  });
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) finish('cancel');
    },
    child: Scaffold(
      appBar: AppBar(title: Text(t(snapshotViewLabels[widget.view]!))),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            t(
              'Frozen frame: take your time. Points use only this saved depth and camera pose.',
            ),
          ),
          SizedBox(
            key: const Key('snapshot-guide'),
            height: 110,
            child: CustomPaint(
              painter: CowPointPainter(
                step: points.length,
                right: widget.view == 'right',
                front: widget.view == 'front',
              ),
            ),
          ),
          Text(
            t(
              points.length >= requiredPoints
                  ? 'Points ready. Save this frame.'
                  : widget.view == 'front'
                  ? (points.isEmpty
                        ? 'Left edge of the chest (behind the front legs)'
                        : 'Right edge of the same chest section')
                  : sidePointLabels[points.length],
            ),
          ),
          if (error != null)
            Text(
              '${t('Point rejected: this pixel has no reliable depth. Retake the frame if needed.')}\n$error',
              key: const Key('snapshot-point-error'),
            ),
          LayoutBuilder(
            builder: (context, size) {
              final width = size.maxWidth,
                  height =
                      width *
                      finiteNumber(widget.frame['view_height']) /
                      finiteNumber(widget.frame['view_width']);
              return GestureDetector(
                key: const Key('frozen-depth-image'),
                onTapUp: points.length >= requiredPoints
                    ? null
                    : (tap) {
                        try {
                          final x =
                                  tap.localPosition.dx /
                                  width *
                                  finiteNumber(widget.frame['view_width']),
                              y =
                                  tap.localPosition.dy /
                                  height *
                                  finiteNumber(widget.frame['view_height']);
                          final point = unprojectSnapshot(
                            widget.frame,
                            x,
                            y,
                            widget.rules,
                          );
                          if (points.any(
                            (p) =>
                                p['depth_pixel_x'] == point['depth_pixel_x'] &&
                                p['depth_pixel_y'] == point['depth_pixel_y'],
                          )) {
                            throw const FormatException('Repeated pixel');
                          }
                          setState(() {
                            points.add(point);
                            error = null;
                          });
                        } catch (e) {
                          setState(() => error = e.toString());
                        }
                      },
                child: SizedBox(
                  width: width,
                  height: height,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.memory(
                        base64Decode(widget.frame['jpeg_base64'] as String),
                        fit: BoxFit.fill,
                      ),
                      IgnorePointer(
                        child: CustomPaint(
                          painter: FrozenPointPainter(
                            points,
                            finiteNumber(widget.frame['view_width']),
                            finiteNumber(widget.frame['view_height']),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: points.isEmpty
                    ? null
                    : () => setState(() => points.removeLast()),
                child: Text(t('Undo last point')),
              ),
              OutlinedButton(
                onPressed: () => finish('retake'),
                child: Text(t('Retake frame')),
              ),
              FilledButton(
                onPressed: points.length == requiredPoints
                    ? () => finish('save')
                    : null,
                child: Text(t('Save frozen frame')),
              ),
              TextButton(
                onPressed: () => finish('cancel'),
                child: Text(t('Cancel')),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

/// Original vector inspired by the user's diagram; no third-party asset/code.
class CowPointPainter extends CustomPainter {
  CowPointPainter({required this.step, this.right = false, this.front = false});
  final int step;
  final bool right, front;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 120);
    final p = Paint()..color = const Color(0xffa77956);
    double x(double v) => right ? 300 - v : v;
    if (front) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(105, 20, 90, 90),
          const Radius.circular(30),
        ),
        p,
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(right ? 40 : 65, 20, right ? 235 : 260, 90),
          const Radius.circular(22),
        ),
        p,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x(35), 58), width: 55, height: 42),
        p,
      );
      canvas.drawPath(
        Path()
          ..moveTo(x(30), 40)
          ..lineTo(x(80), 30)
          ..lineTo(x(95), 75)
          ..lineTo(x(25), 77)
          ..close(),
        p,
      );
      for (final px in [100.0, 120.0, 225.0, 245.0]) {
        canvas.drawRect(Rect.fromLTRB(x(px) - 4, 80, x(px) + 4, 115), p);
      }
    }
    final positions = front
        ? [const Offset(105, 60), const Offset(195, 60)]
        : [
            Offset(x(70), 55),
            Offset(x(255), 48),
            Offset(x(105), 20),
            Offset(x(105), 88),
          ];
    for (var i = 0; i < positions.length; i++) {
      final at = positions[i];
      p.color = i == step ? const Color(0xffffce40) : const Color(0xffc6d5ce);
      canvas.drawCircle(at, i == step ? 12 : 9, p);
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(fontSize: 13, color: Color(0xff142d24)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(CowPointPainter old) =>
      old.step != step || old.right != right || old.front != front;
}

class FrozenPointPainter extends CustomPainter {
  FrozenPointPainter(this.points, this.width, this.height);
  final List<Map<String, dynamic>> points;
  final double width, height;
  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < points.length; i++) {
      final p = points[i],
          at = Offset(
            finiteNumber(p['screen_x']) / width * size.width,
            finiteNumber(p['screen_y']) / height * size.height,
          );
      canvas.drawCircle(at, 10, Paint()..color = const Color(0xffffce40));
      final text = TextPainter(
        text: TextSpan(
          text: '${i + 1}',
          style: const TextStyle(fontSize: 13, color: Colors.black),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
    }
  }

  @override
  bool shouldRepaint(FrozenPointPainter old) => true;
}
