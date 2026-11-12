import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'localization.dart';
import 'snapshot_annotation.dart';

/// A UI preference, deliberately outside immutable animal/capture journals.
class FieldGuidePreferences {
  FieldGuidePreferences({Future<File> Function()? preferenceFile})
    : file = preferenceFile ?? _nativeFile;
  final Future<File> Function() file;
  static Future<File> _nativeFile() async => File(
    '${(await getApplicationSupportDirectory()).path}/preferences/field_guide.json',
  );
  Future<bool> completed() async {
    try {
      final path = await file();
      if (await FileSystemEntity.type(path.path, followLinks: false) !=
          FileSystemEntityType.file) {
        return false;
      }
      final value = jsonDecode(await path.readAsString());
      return value is Map &&
          value['version'] == 1 &&
          value['completed'] == true;
    } on FileSystemException {
      return false;
    } on FormatException {
      return false;
    }
  }

  Future<void> complete() async {
    final destination = await file();
    final temporary = File('${destination.path}.next');
    await destination.parent.create(recursive: true);
    for (final path in [destination, temporary]) {
      final kind = await FileSystemEntity.type(path.path, followLinks: false);
      if (kind != FileSystemEntityType.notFound &&
          kind != FileSystemEntityType.file) {
        throw const FileSystemException('Unsafe field guide preference path');
      }
    }
    await temporary.writeAsString(
      jsonEncode({'version': 1, 'completed': true}),
      flush: true,
    );
    await temporary.rename(destination.path);
  }
}

const guideTitles = [
  'Take clear muzzle frames',
  'Confirm the animal yourself',
  'Keep both side views',
  'Keep a separate backup',
];
const guideBodies = [
  'Use Video capture. Hold one muzzle in the frame for four seconds. Keep steady and choose the clear frames. Only JPEG photos are saved.',
  'Review the suggested profile and both photos. Choose Yes only when it is the same animal. The experimental signal is not proof of identity.',
  'Take the whole animal from the left and right, including its feet. Side photos do not calculate weight. Use a real scale or optional AR on a supported phone.',
  'Open Tools, then Collection, language and ZIP backup. Save the ZIP outside this app. Keep your offline operator ID. Upload is a separate manual action when connected.',
];

class FieldGuideScreen extends StatefulWidget {
  const FieldGuideScreen({super.key, required this.preferences});
  final FieldGuidePreferences preferences;
  @override
  State<FieldGuideScreen> createState() => _FieldGuideScreenState();
}

class _FieldGuideScreenState extends State<FieldGuideScreen> {
  final controller = PageController();
  int page = 0;
  bool saving = false;
  UiText? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  Future<void> finish() async {
    if (saving) return;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.preferences.complete();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        setState(() {
          saving = false;
          error = const UiText('Guide progress could not be saved. Try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      toolbarHeight: 96,
      title: const FieldText(UiText('Field guide')),
    ),
    body: Column(
      children: [
        if (saving) const LinearProgressIndicator(),
        if (error != null)
          Padding(padding: const EdgeInsets.all(12), child: FieldText(error!)),
        Expanded(
          child: PageView.builder(
            controller: controller,
            itemCount: guideTitles.length,
            onPageChanged: (value) => setState(() => page = value),
            itemBuilder: (context, index) => SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 160,
                    child: ExcludeSemantics(
                      child: CustomPaint(painter: FieldGuidePainter(index)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  FieldText(
                    UiText(guideTitles[index]),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  FieldText(UiText(guideBodies[index])),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.center,
              children: [
                Text('${page + 1}/${guideTitles.length}'),
                if (page < guideTitles.length - 1)
                  OutlinedButton(
                    onPressed: saving ? null : finish,
                    child: const FieldText(UiText('Skip guide')),
                  ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () {
                          if (page == guideTitles.length - 1) {
                            finish();
                          } else {
                            controller.nextPage(
                              duration: const Duration(milliseconds: 250),
                              curve: Curves.easeOut,
                            );
                          }
                        },
                  child: FieldText(
                    UiText(
                      page == guideTitles.length - 1
                          ? 'Start collecting'
                          : 'Next guide page',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

/// Original vector illustrations, reusing this project's cattle outline.
class FieldGuidePainter extends CustomPainter {
  FieldGuidePainter(this.step);
  final int step;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 300, size.height / 160);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 300, 160),
        const Radius.circular(18),
      ),
      Paint()..color = const Color(0xffe6f1e8),
    );
    void cow(Rect area, {bool front = false, bool right = false}) {
      canvas.save();
      canvas.translate(area.left, area.top);
      CowPointPainter(
        step: 0,
        front: front,
        right: right,
        showPoints: false,
      ).paint(canvas, area.size);
      canvas.restore();
    }

    final stroke = Paint()
      ..color = const Color(0xff183f32)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    void arrow(double x, double y, double end) {
      canvas.drawLine(Offset(x, y), Offset(end, y), stroke);
      canvas.drawPath(
        Path()
          ..moveTo(end - 9, y - 8)
          ..lineTo(end, y)
          ..lineTo(end - 9, y + 8),
        stroke,
      );
    }

    if (step == 0) {
      cow(const Rect.fromLTWH(25, 5, 250, 145), front: true);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(118, 90, 64, 38),
          const Radius.circular(6),
        ),
        stroke..color = const Color(0xffb27922),
      );
    } else if (step == 1) {
      cow(const Rect.fromLTWH(5, 15, 125, 120), front: true);
      cow(const Rect.fromLTWH(170, 15, 125, 120), front: true);
      arrow(132, 80, 167);
    } else if (step == 2) {
      cow(const Rect.fromLTWH(0, 8, 155, 74));
      cow(const Rect.fromLTWH(145, 78, 155, 74), right: true);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(35, 15, 65, 130),
          const Radius.circular(10),
        ),
        stroke,
      );
      canvas.drawLine(const Offset(55, 131), const Offset(80, 131), stroke);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(168, 30, 105, 100),
          const Radius.circular(8),
        ),
        stroke,
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(185, (55 + i * 22).toDouble()),
          Offset(254, (55 + i * 22).toDouble()),
          stroke,
        );
      }
      arrow(112, 80, 156);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(FieldGuidePainter oldDelegate) => oldDelegate.step != step;
}
