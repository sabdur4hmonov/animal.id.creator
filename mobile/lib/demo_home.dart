import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as image;
import 'package:path_provider/path_provider.dart';
import 'field_guide.dart';
import 'field_store.dart';
import 'local_profiles.dart';
import 'localization.dart';
import 'profile_views.dart';

/// Demonstration-only drawings, never camera photographs or upload queue entries.
class DemoSeed {
  DemoSeed(this.root);
  final Directory root;
  static Future<Directory> nativeRoot() async => Directory(
    '${(await getApplicationSupportDirectory()).path}/demo_capture_queue',
  );
  Future<ProfileCatalog> load() async {
    if (root.uri.pathSegments.where((s) => s.isNotEmpty).last !=
        'demo_capture_queue') {
      throw StateError('Demo requires its own data directory');
    }
    final store = FieldStore(root);
    await store.initialize();
    if (store.operatorId.isEmpty) await store.saveOperator('NAMUNA-OPERATOR');
    if (store.operatorId != 'NAMUNA-OPERATOR') {
      throw StateError('Not a demo store');
    }
    if ((await store.records('animal')).any(
      (a) => a['notes'] != 'NAMUNA' || a['operator_id'] != 'NAMUNA-OPERATOR',
    )) {
      throw StateError('Non-demo evidence must not be used');
    }
    for (var i = 0; i < 6; i++) {
      final key = sha256
          .convert(utf8.encode('chorvam-original-demo-v1-$i'))
          .toString()
          .substring(0, 32);
      final animal = await store.newAnimal(
        'NAMUNA-${i + 1}',
        'NAMUNA',
        DateTime.utc(2026, 1, i + 1),
        registrationScanKey: key,
      );
      final scan = File('${root.path}/field-scan-$key.json');
      if (await scan.exists()) {
        final prior = jsonDecode(await scan.readAsString()) as Map;
        final retained = File('${root.path}/$key.jpg');
        if (prior['synthetic_demo'] != true ||
            prior['label'] != animal['label'] ||
            prior['file_path'] != '$key.jpg' ||
            !await retained.exists() ||
            sha256.convert(await retained.readAsBytes()).toString() !=
                prior['sha256']) {
          throw StateError('Keep changed demo evidence for review');
        }
        continue;
      }
      final bytes = await drawDemoMuzzle(i);
      final photo = File('${root.path}/$key.jpg');
      if (await photo.exists()) {
        if (sha256.convert(await photo.readAsBytes()) !=
            sha256.convert(bytes)) {
          throw StateError('Keep changed demo evidence for review');
        }
      } else {
        await photo.create(exclusive: true);
        await photo.writeAsBytes(bytes, flush: true);
      }
      await store.append('field-scan-$key.json', {
        'version': 1,
        'synthetic_demo': true,
        'request_key': key,
        'label': animal['label'],
        'species': 'cattle',
        'provisional': true,
        'session': 'NAMUNA',
        'view': 'front1',
        'file_path': '$key.jpg',
        'sha256': sha256.convert(bytes).toString(),
        'metadata': {
          'timestamp': animal['created_at'],
          'operator_id': store.operatorId,
          'animal_id': animal['label'],
          'species': 'cattle',
          'gps': null,
        },
      });
    }
    final catalog = ProfileCatalog(store);
    await catalog.refresh();
    return catalog;
  }
}

/// Original geometric illustration; no third-party or real-animal source images.
Future<List<int>> drawDemoMuzzle(int index) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final palette = [
    0xffb07c54,
    0xff7c8c79,
    0xffd3a977,
    0xff89817f,
    0xffab985d,
    0xff729da0,
  ];
  final coat = Paint()..color = Color(palette[index % palette.length]);
  canvas.drawColor(const Color(0xffe9f1e9), BlendMode.src);
  canvas.drawOval(const Rect.fromLTWH(24, 66, 125, 72), coat);
  canvas.drawOval(const Rect.fromLTWH(235, 66, 125, 72), coat);
  canvas.drawOval(const Rect.fromLTWH(91, 42, 202, 270), coat);
  final ink = Paint()..color = const Color(0xff203f32);
  for (final x in [145.0, 239.0]) {
    canvas.drawCircle(Offset(x, 148), 10, ink);
  }
  canvas.drawOval(
    const Rect.fromLTWH(104, 221, 176, 103),
    Paint()..color = const Color(0xffe6c7b6),
  );
  for (final x in [153.0, 231.0]) {
    canvas.drawOval(
      Rect.fromCenter(center: Offset(x, 264), width: 24, height: 13),
      ink,
    );
  }
  for (var i = 0; i < 8; i++) {
    canvas.drawCircle(
      Offset(
        131 + ((i * 23 + index * 13) % 122).toDouble(),
        285 + ((i * 7) % 22).toDouble(),
      ),
      2.5,
      ink,
    );
  }
  final picture = recorder.endRecording();
  final rendered = await picture.toImage(384, 384);
  try {
    final png = await rendered.toByteData(format: ui.ImageByteFormat.png);
    return image.encodeJpg(
      image.decodePng(png!.buffer.asUint8List())!,
      quality: 90,
    );
  } finally {
    rendered.dispose();
    picture.dispose();
  }
}

/// Stays above the Navigator so every demo route retains the disclosure.
class DemoDisclosure extends StatelessWidget {
  const DemoDisclosure({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Material(
        color: const Color(0xffffe3a3),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: FieldText(
              const UiText(
                'NAMUNA — synthetic drawings. Server upload is disabled.',
              ),
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ),
      Expanded(child: child),
    ],
  );
}

class DemoHome extends StatefulWidget {
  const DemoHome({super.key, this.root});
  final Directory? root;
  @override
  State<DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<DemoHome> {
  late final catalog = _load();
  Future<ProfileCatalog> _load() async =>
      DemoSeed(widget.root ?? await DemoSeed.nativeRoot()).load();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chorvam NAMUNA'), toolbarHeight: 96),
    body: FutureBuilder<ProfileCatalog>(
      future: catalog,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: FieldText(
              UiText('Demo could not open. Real animal records are not used.'),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!, cache = ProfileThumbnails(data, 144);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const FieldText(
              UiText(
                'These six animals are drawn examples. No real weight, health or recognition result is claimed.',
              ),
            ),
            OutlinedButton(
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      FieldGuideScreen(preferences: FieldGuidePreferences()),
                ),
              ),
              child: const FieldText(UiText('Field guide')),
            ),
            for (final profile in data.profiles)
              ProfileCard(
                profile: profile,
                cache: cache,
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        DemoProfile(profile: profile, catalog: data),
                  ),
                ),
              ),
          ],
        );
      },
    ),
  );
}

class DemoProfile extends StatelessWidget {
  const DemoProfile({super.key, required this.profile, required this.catalog});
  final LocalProfile profile;
  final ProfileCatalog catalog;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const FieldText(UiText('Animal profile')),
      toolbarHeight: 96,
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (profile.latestPhoto != null)
          Image.file(
            catalog.photo(profile.latestPhoto!),
            height: 240,
            cacheWidth: 480,
          ),
        Text(profile.tag, style: Theme.of(context).textTheme.headlineSmall),
        Text(profile.id),
        const FieldText(
          UiText(
            'These six animals are drawn examples. No real weight, health or recognition result is claimed.',
          ),
        ),
        const FieldText(UiText('No saved weight yet')),
        FieldText(
          UiText('Offline operator: {0}', [profile.animal['operator_id']]),
        ),
        Text(fieldDay(profile.animal['created_at'])),
        const FieldText(
          UiText(
            'Use the regular Chorvam app for real collection. This demo cannot capture, measure or send records.',
          ),
        ),
      ],
    ),
  );
}
