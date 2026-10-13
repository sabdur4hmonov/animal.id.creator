import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:biolivestock_capture/animal_registry.dart';
import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/app_design.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/registry_journal.dart';
import 'package:biolivestock_capture/species.dart';
import 'helpers/design_capture.dart';

final config = SpeciesConfig.fromJson({
  'species': 'cattle',
  'enabled': true,
  'quality': <String, dynamic>{},
  'numbering': {'prefix': 'M', 'digits': 8, 'series_letters': 2},
});

class RegistryWidgetApi extends ApiClient {
  Map<String, dynamic> animal = {
    'animal_id': 'MAA00000001',
    'numbered_id': 'MAA00000001',
    'species': 'cattle',
    'version': 1,
    'lifecycle': 'active',
    'status': 'open',
    'can_manage': true,
    'owner': {'owner_id': 'OWNER-1', 'name': 'Synthetic Farmer'},
    'created_at': '2026-10-13T00:00:00Z',
    'terminal_record': null,
  };
  bool loseResponse = false, offline = false;
  List<Map<String, dynamic>> events = [];
  int? reject;
  final requests = <Map<String, dynamic>>[];
  final receipts = <String, Map<String, dynamic>>{};
  @override
  Future<dynamic> registryGet(String path) async {
    if (offline) throw const SocketException('offline');
    if (path.contains('history')) {
      final offset =
          int.tryParse(Uri.parse(path).queryParameters['offset'] ?? '0') ?? 0;
      return events.skip(offset).take(50).toList();
    }
    if (path.endsWith('slaughter-check')) {
      return {
        'animal': animal,
        'recorded_slaughter': animal['lifecycle'] == 'slaughtered',
      };
    }
    if (path.contains('?')) {
      return path.contains('lifecycle=all') || animal['lifecycle'] == 'active'
          ? [animal]
          : [];
    }
    return animal;
  }

  @override
  Future<Map<String, dynamic>> registryPost(
    String path,
    Map<String, dynamic> body,
    String key,
  ) async {
    requests.add({
      'key': key,
      'body': jsonDecode(jsonEncode(body)),
      'path': path,
    });
    if (reject != null) throw RegistryApiError(reject!, 'Animal changed');
    final result = receipts.putIfAbsent(key, () {
      if (path == registryRoot) {
        animal = {...animal, 'owner': body['owner']};
      } else if (path.endsWith('/owner')) {
        animal = {
          ...animal,
          'owner': body['owner'],
          'version': body['expected_version'] + 1,
        };
      } else {
        animal = {
          ...animal,
          'lifecycle': body['lifecycle'],
          'version': body['expected_version'] + 1,
          'terminal_record': {
            ...body,
            'actor_id': 'operator-1',
            'received_at': '2026-10-13T00:01:00Z',
            if (body['capture_id'] != null) 'capture_stored_sha256': 'a' * 64,
          },
        };
      }
      return Map<String, dynamic>.from(animal);
    });
    if (loseResponse) {
      loseResponse = false;
      throw const SocketException('Reply lost');
    }
    return result;
  }
}

Future<void> settleIO(WidgetTester tester) async {
  for (var i = 0; i < 200; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 15)),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (i > 20 && find.byType(LinearProgressIndicator).evaluate().isEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, String label) async {
  final finder = find.text(label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  if (label == 'Register new animal') {
    for (
      var i = 0;
      i < 200 && find.byType(AlertDialog).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }
  await settleIO(tester);
}

Finder field(String label) => find.widgetWithText(TextFormField, label);

void main() {
  setUpAll(loadDesignFonts);
  late Directory root;
  late GlobalKey frame;
  late RegistryWidgetApi api;
  late CaptureEnvironment env;
  setUp(() async {
    root = await Directory.systemTemp.createTemp('registry_widget');
    api = RegistryWidgetApi();
    frame = GlobalKey();
    env = CaptureEnvironment(
      api: api,
      backend: 'http://canonical',
      operatorId: 'operator-1',
      openQueue: () async => OfflineQueue(root),
      openCamera: () async => throw UnimplementedError(),
      gps: () async => {
        'gps': {'latitude': 41.3, 'longitude': 69.2},
      },
      deviceSignals: () async => {},
      quality: (_, _) async => throw UnimplementedError(),
      exportDirectory: () async => root,
      share: (_, _) async {},
      now: () => DateTime.utc(2026, 10, 13),
    );
  });
  tearDown(() async => root.delete(recursive: true));
  Future<void> screen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: frame,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldTheme(),
          home: Scaffold(
            body: AnimalRegistryScreen(
              environment: env,
              queueRoot: root,
              configs: [config],
              onCapture: (_) {},
            ),
          ),
        ),
      ),
    );
    await settleIO(tester);
  }

  testWidgets(
    'issued ID stays visible and restart reuses it before explicit acknowledgement',
    (tester) async {
      await screen(tester);
      await saveDesignFrame(tester, frame, 'registry-list');
      await tapVisible(tester, 'Register new animal');
      await tester.enterText(field('Owner reference'), 'OWNER-1');
      await tester.enterText(field('Owner name'), 'Synthetic Farmer');
      await tapVisible(tester, 'Issue unique ID');
      expect(find.text('Your permanent animal ID'), findsOneWidget);
      expect(api.requests.length, 1);
      await saveDesignFrame(tester, frame, 'registry-issued');
      await tapVisible(tester, 'Cancel');
      await tester.pumpWidget(const SizedBox());
      await screen(tester);
      await tapVisible(tester, 'Register new animal');
      expect(
        find.text('Your permanent animal ID'),
        findsOneWidget,
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data)
            .join('\n'),
      );
      await tapVisible(tester, 'Use this ID');
      expect(find.text('Capture with this ID'), findsOneWidget);
      expect(api.requests.length, 1);
      expect(
        (await tester.runAsync(
          () => RegistryJournal(root, env.backend, env.operatorId).issued(),
        ))!.single['_delivered'],
        true,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'owner change and slaughter require notes/facility then archive keeps readable report',
    (tester) async {
      await screen(tester);
      await tapVisible(tester, 'MAA00000001');
      await tapVisible(tester, 'Change owner');
      await tester.enterText(field('New owner reference'), 'OWNER-2');
      await tester.enterText(field('New owner name'), 'Synthetic Buyer');
      await tester.enterText(
        field('Reason / report notes'),
        'Owner transfer report',
      );
      await tapVisible(tester, 'Confirm owner change');
      expect(api.animal['owner']['owner_id'], 'OWNER-2');
      await tapVisible(tester, 'Record slaughter');
      await tapVisible(tester, 'Confirm slaughter report');
      expect(api.requests.length, 1);
      await tester.enterText(field('Slaughter facility ID'), 'FACILITY-1');
      await tester.enterText(
        field('Reason / report notes'),
        'Synthetic slaughter report',
      );
      await tapVisible(tester, 'Confirm slaughter report');
      expect(api.animal['lifecycle'], 'slaughtered');
      expect(find.text('Slaughter report on file'), findsOneWidget);
      expect(find.text('Change owner'), findsNothing);
      expect(find.text('Record death'), findsNothing);
      expect(find.textContaining('not independently verified'), findsOneWidget);
      await tester.ensureVisible(find.text('Slaughter report on file'));
      await saveDesignFrame(tester, frame, 'registry-slaughter');
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'lost death reply retries immutable body/key and known conflict remains cancellable',
    (tester) async {
      await screen(tester);
      await tapVisible(tester, 'MAA00000001');
      await tapVisible(tester, 'Record death');
      await tester.enterText(
        field('Reason / report notes'),
        'Synthetic death report',
      );
      api.loseResponse = true;
      await tapVisible(tester, 'Confirm death report');
      expect(find.text('Retry same request'), findsOneWidget);
      await tapVisible(tester, 'Retry same request');
      expect(api.requests[0], api.requests[1]);
      expect(api.animal['lifecycle'], 'deceased');
      // A separate active record rejects a stale version without trapping the dialog.
      await tester.pumpWidget(const SizedBox());
      api.animal = {
        ...api.animal,
        'animal_id': 'MAA00000002',
        'numbered_id': 'MAA00000002',
        'lifecycle': 'active',
      };
      await screen(tester);
      await tapVisible(tester, 'MAA00000002');
      await tapVisible(tester, 'Record death');
      await tester.enterText(field('Reason / report notes'), 'Stale report');
      api.reject = 409;
      await tapVisible(tester, 'Confirm death report');
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Confirm death report'),
            )
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Cancel'))
            .onPressed,
        isNotNull,
      );
      await tapVisible(tester, 'Cancel');
      expect(find.byType(AlertDialog), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'registry fits narrow screen with 200 percent text and archived filter',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: fieldTheme(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: AnimalRegistryScreen(
              environment: env,
              queueRoot: root,
              configs: [config],
              onCapture: (_) {},
            ),
          ),
        ),
      );
      await settleIO(tester);
      await tapVisible(tester, 'Include archived animals');
      await tapVisible(tester, 'MAA00000001');
      await tapVisible(tester, 'Record death');
      expect(tester.takeException(), isNull);
      await tapVisible(tester, 'Cancel');
    },
  );
  testWidgets('failed lookup clears old identity and slaughter result', (
    tester,
  ) async {
    api.animal = {
      ...api.animal,
      'lifecycle': 'slaughtered',
      'terminal_record': {
        'actor_id': 'operator-1',
        'observed_at': '2026-10-13T00:00:00Z',
        'received_at': '2026-10-13T00:01:00Z',
        'reason': 'Synthetic',
        'facility_id': 'SITE-1',
      },
    };
    await screen(tester);
    await tester.enterText(find.byType(TextField).first, 'MAA00000001');
    await tapVisible(tester, 'Check animal / slaughter record');
    expect(find.text('Slaughter report on file'), findsOneWidget);
    api.offline = true;
    await tester.enterText(find.byType(TextField).first, 'MAA00000002');
    await tapVisible(tester, 'Check animal / slaughter record');
    expect(find.text('Slaughter report on file'), findsNothing);
    expect(find.text('Capture with this ID'), findsNothing);
    expect(find.textContaining('SocketException'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'terminal report validates UUID, retains it on retry and shows linked hash',
    (tester) async {
      await screen(tester);
      await tapVisible(tester, 'MAA00000001');
      await tapVisible(tester, 'Record slaughter');
      await tester.enterText(field('Slaughter facility ID'), 'SITE-1');
      await tester.enterText(
        field('Reason / report notes'),
        'Synthetic report',
      );
      await tester.enterText(
        field('Uploaded capture UUID (optional)'),
        'local-request-key',
      );
      await tapVisible(tester, 'Confirm slaughter report');
      expect(api.requests, isEmpty);
      const capture = '12345678-1234-1234-1234-123456789abc';
      await tester.enterText(
        field('Uploaded capture UUID (optional)'),
        capture.toUpperCase(),
      );
      api.loseResponse = true;
      await tapVisible(tester, 'Confirm slaughter report');
      expect(api.requests.single['body']['capture_id'], capture);
      expect(
        tester
            .widget<TextFormField>(field('Uploaded capture UUID (optional)'))
            .enabled,
        false,
      );
      await tapVisible(tester, 'Retry same request');
      expect(api.requests[0], api.requests[1]);
      expect(find.text('Capture evidence: $capture'), findsOneWidget);
      expect(find.text('Stored image SHA-256: ${'a' * 64}'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'history pages beyond the first fifty and preserves the page on failure',
    (tester) async {
      api.events = List.generate(
        51,
        (n) => {
          'action': 'event-$n',
          'actor_id': 'operator-1',
          'received_at': '2026-10-13T00:00:00Z',
          'details': {'index': n},
        },
      );
      await screen(tester);
      await tapVisible(tester, 'MAA00000001');
      await tapVisible(tester, 'Ownership & event history');
      expect(find.text('event-49'), findsOneWidget);
      expect(find.text('event-50'), findsNothing);
      await tapVisible(tester, 'Next history');
      expect(find.text('History page 2'), findsOneWidget);
      expect(find.text('event-50'), findsOneWidget);
      expect(find.text('event-0'), findsNothing);
      api.offline = true;
      await tapVisible(tester, 'Previous history');
      expect(find.text('History page 2'), findsOneWidget);
      expect(find.text('event-50'), findsOneWidget);
      api.offline = false;
      await tapVisible(tester, 'Previous history');
      expect(find.text('History page 1'), findsOneWidget);
      expect(find.text('event-0'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
