import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';

// Load the SDK's actual platform fonts instead of test-only Ahem block glyphs.
Future<void> loadDesignFonts() async {
  final config = File('.dart_tool/package_config.json').absolute;
  final packages =
      (jsonDecode(await config.readAsString()) as Map)['packages'] as List;
  final flutter = packages.cast<Map>().firstWhere(
    (package) => package['name'] == 'flutter',
  );
  final sdk = Directory.fromUri(
    config.uri.resolve(flutter['rootUri'] as String),
  ).parent.parent.uri;
  final fonts = Directory.fromUri(
    sdk.resolve('bin/cache/artifacts/material_fonts/'),
  );
  final roboto = FontLoader('Roboto');
  for (final weight in ['regular', 'medium', 'bold']) {
    roboto.addFont(
      File(
        '${fonts.path}/roboto-$weight.ttf',
      ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
    );
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(
        File(
          '${fonts.path}/materialicons-regular.otf',
        ).readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      ))
      .load();
}

Future<void> saveDesignFrame(
  WidgetTester tester,
  GlobalKey key,
  String name,
) async {
  if (Platform.environment['DESIGN_SCREENSHOTS'] != '1') return;
  // Complete input/button/navigation transitions before recording the visible state.
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  void repaint(RenderObject node) {
    node.markNeedsPaint();
    node.visitChildren(repaint);
  }

  repaint(boundary);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final rendered = await boundary.toImage(pixelRatio: 2);
    final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
    final directory = await Directory(
      '../data/design/20261013',
    ).create(recursive: true);
    await File(
      '${directory.path}/$name.png',
    ).writeAsBytes(png!.buffer.asUint8List());
    rendered.dispose();
  });
}
