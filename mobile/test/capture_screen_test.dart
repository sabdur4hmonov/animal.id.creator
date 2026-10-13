import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as image;
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/capture_screen.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:biolivestock_capture/queue_backup.dart';
import 'package:biolivestock_capture/species.dart';
import 'package:biolivestock_capture/app_design.dart';
import 'helpers/design_capture.dart';

class FakeApi extends ApiClient {
  bool offline = false;
  int? failOn;
  int calls = 0;
  final Map<String, Map<String, dynamic>> saved = {};
  final configs = [
    SpeciesConfig.fromJson({
      'species': 'cattle',
      'enabled': true,
      'quality': <String, dynamic>{},
      'numbering': {'prefix': 'M', 'digits': 8, 'series_letters': 2},
    }),
  ];
  final registryAnimal = <String, dynamic>{
    'species': 'cattle',
    'animal_id': 'MAA00000001',
    'numbered_id': 'MAA00000001',
    'version': 1,
    'lifecycle': 'active',
    'status': 'open',
    'can_manage': true,
    'owner': {'owner_id': 'OWNER-1', 'name': 'Synthetic Farmer'},
    'created_at': '2026-10-13T00:00:00Z',
    'terminal_record': null,
  };
  @override
  Future<dynamic> registryGet(String path) async {
    if (path.contains('history')) return [];
    if (path.endsWith('slaughter-check')) return {'recorded_slaughter': false};
    return path.contains('?') ? [registryAnimal] : registryAnimal;
  }

  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async => {...registryAnimal, 'owner': body['owner']};
  @override
  Future<List<SpeciesConfig>> loadSpecies() async {
    if (offline) throw const SocketException('offline');
    return configs;
  }

  @override
  Future<Map<String, dynamic>> upload(
    String path,
    Map<String, dynamic> metadata,
    String key,
  ) async {
    calls++;
    if (offline || calls == failOn) throw const SocketException('offline');
    return saved.putIfAbsent(
      key,
      () => {
        'id': 'saved-$key',
        'animal_id': metadata['animal_id'],
        'species': metadata['species'],
        'operator_id': metadata['operator_id'],
        'crop_status': 'pending_model',
        'file_path':
            'cattle/${metadata['animal_id']}/2026-10-13/synthetic-original.jpg',
      },
    );
  }
}

class FakeCamera implements CaptureCamera {
  final Directory root;
  bool disposed = false;
  int shots = 0;
  FakeCamera(this.root);
  @override
  bool get initialized => !disposed;
  @override
  double get aspectRatio => 4 / 3;
  @override
  Widget preview() => Container(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xff748c78), Color(0xff283f34)],
      ),
    ),
    child: const Center(
      child: Text(
        'Mock camera preview',
        style: TextStyle(color: Colors.white70),
      ),
    ),
  );
  @override
  Future<void> dispose() async {
    disposed = true;
  }

  @override
  Future<XFile> takePicture() async {
    if (disposed) throw StateError('Camera disposed');
    final file = File(
      '${root.path}/camera-${DateTime.now().microsecondsSinceEpoch}-${shots++}.png',
    );
    await file.writeAsBytes(
      image.encodePng(image.Image(width: 16, height: 16)),
    );
    return XFile(file.path);
  }
}

class DeniedLocation implements LocationAccess {
  int requests = 0;
  @override
  Future<bool> enabled() async => true;
  @override
  Future<LocationPermission> check() async => LocationPermission.denied;
  @override
  Future<LocationPermission> request() async {
    requests++;
    return LocationPermission.deniedForever;
  }

  @override
  Future<Position> position() async =>
      throw StateError('Must not read denied location');
}

class FullQueue extends OfflineQueue {
  FullQueue(super.root);
  @override
  Future<QueuedCapture> enqueue(
    String source,
    Map<String, dynamic> metadata,
    Map<String, dynamic> quality,
    String backend,
  ) async {
    throw FileSystemException(
      'No space left',
      source,
      const OSError('disk full', 28),
    );
  }
}

Future<void> waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump();
    if (finder.evaluate().isNotEmpty) return;
  }
  throw TestFailure('Widget not found: $finder');
}

Future<void> waitIdle(WidgetTester tester) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    if (find.byType(LinearProgressIndicator).evaluate().isEmpty) return;
  }
  throw TestFailure('Screen operation did not finish');
}

void main() {
  setUpAll(loadDesignFonts);
  late Directory root;
  late OfflineQueue queue;
  late FakeApi api;
  late List<FakeCamera> cameras;
  late DeniedLocation location;
  late File? shared;
  late GlobalKey frame;
  late LocalQuality fixtureQuality;
  var deniedCamera = false;
  const backend = 'http://screen-test.invalid';
  setUp(() async {
    root = await Directory.systemTemp.createTemp('capture_screen_test');
    queue = OfflineQueue(Directory('${root.path}/queue'));
    api = FakeApi();
    cameras = [];
    location = DeniedLocation();
    shared = null;
    deniedCamera = false;
    frame = GlobalKey();
    fixtureQuality = const LocalQuality(200, 128, []);
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });
  CaptureEnvironment environment() => CaptureEnvironment(
    api: api,
    backend: backend,
    operatorId: 'operator-1',
    openQueue: () async => queue,
    openCamera: () async {
      if (deniedCamera) throw CameraException('CameraAccessDenied', 'denied');
      final camera = FakeCamera(root);
      cameras.add(camera);
      return camera;
    },
    gps: () => captureLocation(location, 'android_location'),
    deviceSignals: () async => {'source': 'unsupported'},
    quality: (_, _) async => fixtureQuality,
    exportDirectory: () async => Directory('${root.path}/exports'),
    backup: createPhoneBackup,
    share: (file, origin) async {
      shared = file;
      expect(origin.width, greaterThan(0));
    },
    now: () => DateTime.utc(2026, 10, 13),
  );
  Future<void> mount(
    WidgetTester tester, {
    Size size = const Size(900, 1800),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: MaterialApp(
          theme: fieldTheme(),
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: CaptureScreen(environment: environment()),
        ),
      ),
    );
    await waitFor(tester, find.text('Mock camera preview'));
    await waitFor(tester, find.byType(DropdownButtonFormField<SpeciesConfig>));
    await waitIdle(tester);
  }

  Future<void> capture(WidgetTester tester, String id) async {
    await tester.enterText(find.byType(TextFormField).first, id);
    await tester.tap(find.widgetWithText(FilledButton, 'Capture'));
    await waitFor(tester, find.textContaining('Saved on this phone.'));
    await waitIdle(tester);
  }

  testWidgets(
    'new permanent ID flows into the immutable capture and open review cannot be relabeled',
    (tester) async {
      await mount(tester);
      await tester.ensureVisible(find.text('New animal ID'));
      await tester.tap(find.text('New animal ID'));
      await waitFor(tester, find.text('Register a new animal'));
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner reference'),
        'OWNER-1',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Owner name'),
        'Synthetic Farmer',
      );
      await tester.tap(find.text('Issue unique ID'));
      await waitFor(tester, find.text('Your permanent animal ID'));
      await tester.tap(find.text('Use this ID'));
      await waitFor(tester, find.textContaining('is registered.'));
      await waitIdle(tester);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'MAA00000001',
      );
      await capture(tester, 'LEGACY-001');
      await tester.tap(find.text('Animals'));
      await waitFor(tester, find.text('MAA00000001'));
      await tester.ensureVisible(find.text('MAA00000001'));
      await tester.tap(find.text('MAA00000001'));
      await waitFor(tester, find.text('Capture with this ID'));
      await tester.ensureVisible(find.text('Capture with this ID'));
      await tester.tap(find.text('Capture with this ID'));
      await waitFor(tester, find.textContaining('Finish the open capture'));
      await tester.runAsync(() async {
        expect(
          (await queue.pending(
            backend,
            'operator-1',
          )).single.metadata['animal_id'],
          'LEGACY-001',
        );
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('camera permission denial shows retry and no capture starts', (
    tester,
  ) async {
    deniedCamera = true;
    await tester.pumpWidget(
      MaterialApp(home: CaptureScreen(environment: environment())),
    );
    await waitFor(tester, find.textContaining('Camera unavailable'));
    expect(cameras, isEmpty);
    expect(find.text('Retry camera'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('GPS denial persists null location and safely uploads', (
    tester,
  ) async {
    await mount(tester);
    await capture(tester, 'F01-C001');
    expect(location.requests, 1);
    await tester.runAsync(() async {
      expect(
        (await queue.pending(backend, 'operator-1')).single.metadata['gps'],
        isNull,
      );
    });
    expect(find.textContaining('GPS unavailable'), findsOneWidget);
    await tester.tap(find.text('Upload capture'));
    await waitFor(tester, find.text('Uploaded'));
    expect(api.saved.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('background disposes camera and resume opens a new preview', (
    tester,
  ) async {
    await mount(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(cameras.first.disposed, isTrue);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await waitFor(tester, find.text('Mock camera preview'));
    expect(cameras.length, 2);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'restart offline recovers labels and original without camera temp file',
    (tester) async {
      await mount(tester);
      await capture(tester, 'F01-C002');
      await tester.pumpWidget(const SizedBox());
      api = FakeApi()..offline = true;
      await mount(tester);
      await tester.tap(find.text('Saved'));
      await tester.pump();
      await waitFor(tester, find.text('F01-C002 · cattle'));
      await tester.tap(find.text('F01-C002 · cattle'));
      await tester.pump();
      expect(find.textContaining('Recovered F01-C002'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('full storage never reports a durable save', (tester) async {
    queue = FullQueue(queue.root);
    await mount(tester);
    await tester.enterText(find.byType(TextFormField).first, 'F01-C003');
    await tester.tap(find.widgetWithText(FilledButton, 'Capture'));
    await waitFor(tester, find.textContaining('Capture failed:'));
    expect(find.textContaining('Saved on this phone.'), findsNothing);
    expect(api.saved, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('export shares a verified ZIP and keeps queued original', (
    tester,
  ) async {
    await mount(tester);
    await capture(tester, 'F01-C004');
    await tester.tap(find.text('Tools'));
    await tester.pump();
    await tester.tap(find.text('Export phone backup'));
    await waitFor(tester, find.textContaining('Verified backup of'));
    expect(shared, isNotNull);
    await tester.runAsync(() async {
      expect((await verifyPhoneBackup(shared!.path))['files'], isNotEmpty);
      expect((await queue.pending(backend, 'operator-1')).length, 1);
    });
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('partial batch failure retains the later pending capture', (
    tester,
  ) async {
    await mount(tester);
    await capture(tester, 'F01-C005');
    await tester.tap(find.text('Next capture (saved locally)'));
    await tester.pump();
    await capture(tester, 'F01-C006');
    api.failOn = 2;
    await tester.tap(find.text('Saved'));
    await tester.pump();
    await tester.tap(find.text('Upload pending captures'));
    await waitFor(tester, find.textContaining('Queue paused:'));
    await tester.runAsync(() async {
      expect((await queue.pending(backend, 'operator-1')).length, 1);
    });
    expect(api.saved.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('pending captures paginate without losing the next animal', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final source = File('${root.path}/page.png');
      await source.writeAsBytes(
        image.encodePng(image.Image(width: 16, height: 16)),
      );
      for (var i = 0; i < 51; i++) {
        await queue.enqueue(
          source.path,
          {
            'animal_id': 'PAGE-${i.toString().padLeft(3, '0')}',
            'species': 'cattle',
            'operator_id': 'operator-1',
            'timestamp': DateTime.utc(
              2026,
              10,
              13,
            ).add(Duration(seconds: i)).toIso8601String(),
            'gps': null,
          },
          {'blur_variance': 200, 'brightness': 128, 'reasons': <String>[]},
          backend,
        );
      }
    });
    await mount(tester);
    await tester.tap(find.text('Saved'));
    await tester.pump();
    await waitFor(tester, find.text('PAGE-000 · cattle'));
    await tester.scrollUntilVisible(
      find.text('Next captures'),
      600,
      maxScrolls: 100,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Page 1 of 2'), findsOneWidget);
    await tester.tap(find.text('Next captures'));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.text('PAGE-050 · cattle'),
      -600,
      maxScrolls: 100,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('PAGE-050 · cattle'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('small phone and large text keep navigation and capture usable', (
    tester,
  ) async {
    await mount(tester, size: const Size(320, 720), textScale: 2);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.widgetWithText(FilledButton, 'Capture')).height,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Capture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    final invalid = find.text(
      'Use 1–64 letters, digits, underscores or hyphens',
    );
    expect(invalid, findsOneWidget);
    expect(cameras.single.shots, 0);
    expect(
      tester.getRect(invalid).center.dy,
      lessThan(
        tester.getRect(find.widgetWithText(FilledButton, 'Capture')).top,
      ),
    );
    for (final tab in ['Saved', 'Tools']) {
      await tester.tap(find.text(tab));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
    await saveDesignFrame(tester, frame, 'tools-large-text');
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'design screens render and failed upload keeps a recoverable original',
    (tester) async {
      await mount(tester, size: const Size(390, 844));
      await tester.enterText(find.byType(TextFormField).first, 'F01-C017');
      await saveDesignFrame(tester, frame, 'capture');
      await capture(tester, 'F01-C017');
      await saveDesignFrame(tester, frame, 'review');
      api.offline = true;
      await tester.tap(find.text('Upload capture'));
      await waitFor(tester, find.textContaining('Upload failed:'));
      await waitIdle(tester);
      expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
      await tester.runAsync(() async {
        expect((await queue.pending(backend, 'operator-1')).length, 1);
      });
      await tester.tap(find.text('Next capture (saved locally)'));
      await tester.pump();
      await tester.tap(find.text('Saved'));
      await tester.pump();
      await saveDesignFrame(tester, frame, 'saved');
      api.offline = false;
      await tester.tap(find.text('Upload pending captures'));
      await waitFor(tester, find.textContaining('Uploaded 1 queued captures.'));
      await waitIdle(tester);
      await tester.tap(find.text('Review saved upload receipts'));
      await waitFor(tester, find.text('Saved upload receipts'));
      await saveDesignFrame(tester, frame, 'receipts');
      await tester.tap(find.text('Close'));
      await tester.pump();
      await tester.tap(find.text('Tools'));
      await tester.pump();
      await saveDesignFrame(tester, frame, 'tools');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('quality rejection presents retake and never queues the frame', (
    tester,
  ) async {
    fixtureQuality = const LocalQuality(1, 32, [
      'Too blurry. Hold still and retake.',
    ]);
    await mount(tester, size: const Size(390, 844));
    await tester.enterText(find.byType(TextFormField).first, 'F01-C018');
    await tester.tap(find.widgetWithText(FilledButton, 'Capture'));
    await waitFor(tester, find.text('Please retake'));
    await waitIdle(tester);
    expect(find.text('Upload capture'), findsNothing);
    await tester.runAsync(() async {
      expect(await queue.pending(backend, 'operator-1'), isEmpty);
    });
    await saveDesignFrame(tester, frame, 'quality-retake');
    await tester.tap(find.text('Retake'));
    await tester.pump();
    expect(find.widgetWithText(FilledButton, 'Capture'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('field controls meet Android touch target guidance', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await mount(tester, size: const Size(390, 844));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tap(find.text('Tools'));
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
  });
}
