import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:biolivestock_capture/api_client.dart';
import 'package:biolivestock_capture/capture_environment.dart';
import 'package:biolivestock_capture/localization.dart';
import 'package:biolivestock_capture/main.dart';
import 'package:biolivestock_capture/offline_queue.dart';
import 'package:biolivestock_capture/quality_control.dart';
import 'package:biolivestock_capture/species.dart';
import 'package:biolivestock_capture/uzbek_cyrillic_material.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'capture_screen_test.dart' show FakeApi, FakeCamera, waitFor, waitIdle;
import 'helpers/design_capture.dart';

void main() {
  setUpAll(loadDesignFonts);
  late Directory root;
  setUp(
    () async =>
        root = await Directory.systemTemp.createTemp('biolivestock_language'),
  );
  tearDown(() async => root.delete(recursive: true));
  File preference() => File('${root.path}/preferences/language.json');
  LanguageController controller({AppLanguage initial = AppLanguage.uzLatin}) =>
      LanguageController(
        preferenceFile: () async => preference(),
        initial: initial,
      );

  test(
    'every locale has complete templates, matching placeholders and valid Unicode',
    () async {
      final catalogs = <String, Map<String, String>>{};
      for (final item in AppLanguage.values) {
        catalogs[item.code] = Map<String, String>.from(
          jsonDecode(
                await rootBundle.loadString('assets/l10n/${item.code}.json'),
              )
              as Map,
        );
      }
      final english = catalogs['en']!;
      expect(english.length, greaterThan(200));
      for (final catalog in catalogs.values) {
        expect(catalog.keys.toSet(), english.keys.toSet());
        for (final key in english.keys) {
          expect(catalog[key]!.trim(), isNotEmpty, reason: key);
          expect(catalog[key], isNot(contains('\uFFFD')));
          Set<String> parameters(String value) =>
              RegExp(r'\{\d+\}').allMatches(value).map((m) => m[0]!).toSet();
          expect(
            parameters(catalog[key]!),
            parameters(english[key]!),
            reason: key,
          );
        }
      }
      final russian = FieldLocalizations(catalogs['ru']!);
      final cupertino = await const UzbekCyrillicCupertinoDelegate().load(
        AppLanguage.uzCyrillic.locale,
      );
      expect(cupertino.datePickerDateOrder.name, 'mdy');
      expect(cupertino.datePickerDateTimeOrder.name, 'date_time_dayPeriod');
      expect(cupertino.datePickerHourSemanticsLabel(1), contains('соат'));
      final material = await const UzbekCyrillicMaterialDelegate().load(
        AppLanguage.uzCyrillic.locale,
      );
      expect(
        material.selectedRowCountTitle(1),
        isNot(matches(RegExp(r'[A-Za-z]'))),
      );
      expect(
        material.remainingTextFieldCharacterCount(1),
        isNot(matches(RegExp(r'[A-Za-z]'))),
      );
      expect(
        catalogs['uz_Cyrl']!['No slaughter report on file'],
        'Сўйиш хабари йўқ',
      );
      expect(catalogs['uz_Cyrl']!['Animal details'], 'Ҳайвон маълумотлари');
      expect(
        uzbekCyrillic("Yo‘q, ma’lumot, e’lon, yer, g‘isht, o‘yin"),
        'Йўқ, маълумот, эълон, ер, ғишт, ўйин',
      );
      const name = 'Ғулом Ўктамов / Иван {1}';
      expect(
        russian.resolve(
          const UiText('Owner at registration: {0} · {1}', [name, 'OWNER-001']),
        ),
        'Владелец при регистрации: $name · OWNER-001',
      );
      expect(russian.resolve(name), name);
      // Every explicit source template must exist; a newly added English label cannot silently fall back.
      for (final file in Directory(
        'lib',
      ).listSync().whereType<File>().where((f) => f.path.endsWith('.dart'))) {
        final source = await file.readAsString();
        for (final match in RegExp(
          r'''UiText\(\s*(['"])(.*?)\1''',
          dotAll: true,
        ).allMatches(source)) {
          final key = match[2]!.replaceAll(r'\n', '\n');
          expect(
            english.containsKey(key),
            isTrue,
            reason: '${file.path}: $key',
          );
        }
      }
    },
  );

  test(
    'language persists all four scripts across restart without touching evidence',
    () async {
      final evidence = File('${root.path}/entry-original.json');
      await evidence.writeAsString(
        '{"animal_id":"MAA00000001","name":"Ғулом / Иван"}',
      );
      final original = await evidence.readAsBytes();
      for (final language in AppLanguage.values) {
        final first = controller();
        await first.select(language);
        expect(first.language, language);
        expect(first.notice!.key, 'Language saved on this phone.');
        first.dispose();
        final reopened = controller();
        await reopened.load();
        expect(reopened.language, language);
        reopened.dispose();
      }
      expect(await evidence.readAsBytes(), original);
      expect(await File('${preference().path}.next').exists(), isFalse);
    },
  );

  test(
    'corrupt or unsupported language keeps fallback and can be repaired explicitly',
    () async {
      await preference().parent.create(recursive: true);
      for (final value in [
        'broken',
        '{"version":2,"language":"ru"}',
        '{"version":1,"language":"unknown"}',
      ]) {
        await preference().writeAsString(value);
        final language = controller();
        await language.load();
        expect(language.language, AppLanguage.uzLatin);
        expect(language.notice!.key, contains('could not be read'));
        expect(await preference().readAsString(), value);
        await language.select(AppLanguage.uzCyrillic);
        expect(language.language, AppLanguage.uzCyrillic);
        language.dispose();
      }
    },
  );

  test('failed preference write does not claim a saved language', () async {
    await preference().parent.create(recursive: true);
    await Directory(preference().path).create();
    final language = controller(initial: AppLanguage.english);
    await language.select(AppLanguage.russian);
    expect(language.language, AppLanguage.english);
    expect(language.saving, isFalse);
    expect(language.notice!.key, startsWith('Could not save'));
    language.dispose();
  });

  test('rapid changes serialize and disposal during a save is safe', () async {
    final ready = Completer<File>();
    final language = LanguageController(preferenceFile: () => ready.future);
    final save = language.select(AppLanguage.russian);
    await language.select(AppLanguage.english);
    language.dispose();
    ready.complete(preference());
    await save;
    expect(
      (jsonDecode(await preference().readAsString()) as Map)['language'],
      'ru',
    );
  });

  test(
    'JSON HTTP requests and responses preserve Russian and Uzbek Unicode without charset',
    () async {
      const owner = {
        'owner_id': 'OWNER-001',
        'name': 'Ғулом Ўктамов / Иван / O‘ktam',
      };
      final api = ApiClient(
        token: 'synthetic',
        client: MockClient((request) async {
          if (request.method == 'POST') {
            expect(jsonDecode(utf8.decode(request.bodyBytes))['owner'], owner);
          }
          return http.Response.bytes(
            utf8.encode(
              jsonEncode({
                'owner': owner,
                'reason': 'So‘yildi / Сўйилди / Убой',
              }),
            ),
            request.method == 'POST' ? 201 : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect(
        (await api.registryPost('/api/v1/registry/animals', {
          'species': 'cattle',
          'owner': owner,
        }, 'a' * 32))['owner'],
        owner,
      );
      expect(
        (await api.registryGet(
          '/api/v1/registry/animals/cattle/MAA00000001',
        ))['reason'],
        'So‘yildi / Сўйилди / Убой',
      );
      api.close();
    },
  );

  test(
    'server QC guidance localizes reason codes and retains raw rejection evidence',
    () async {
      final strings = await FieldLocalizations.delegate.load(
        AppLanguage.russian.locale,
      );
      const error = ApiError(
        422,
        'Upload rejected (422): {"detail":{"stage":"original","quality":{"reasons":["too_dark","blurry"]}}}',
      );
      final message = strings.resolve(userError(error));
      expect(message, contains('Слишком темно'));
      expect(message, contains('Размыто'));
      expect(message, contains('too_dark'));
      expect(
        strings.resolve(
          userError(
            const RegistryApiError(409, '{"detail":"version changed"}'),
          ),
        ),
        contains('обновите'),
      );
    },
  );

  for (final language in AppLanguage.values) {
    testWidgets(
      '${language.code}: camera, saved and tools localize while open original and request survive switching',
      (tester) async {
        final api = FakeApi();
        final queue = OfflineQueue(Directory('${root.path}/queue'));
        final camera = FakeCamera(root);
        final settings = controller(initial: language);
        final environment = CaptureEnvironment(
          api: api,
          backend: 'http://language-test.invalid',
          operatorId: 'operator-1',
          openQueue: () async => queue,
          openCamera: () async => camera,
          gps: () async => null,
          deviceSignals: () async => {'source': 'unsupported'},
          quality: (_, _) async => const LocalQuality(200, 128, []),
          exportDirectory: () async => root,
          share: (_, _) async {},
          now: () => DateTime.utc(2026, 10, 14),
        );
        final frame = GlobalKey();
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          RepaintBoundary(
            key: frame,
            child: BioLivestockApp(
              language: settings,
              environment: environment,
            ),
          ),
        );
        await waitFor(
          tester,
          find.byType(DropdownButtonFormField<SpeciesConfig>),
        );
        await waitIdle(tester);
        String label(String key) => FieldLocalizations.of(
          tester.element(find.byType(Scaffold).first),
        ).resolve(UiText(key));
        expect(find.text(label('Animal ID')), findsOneWidget);
        expect(find.text(label('Cattle')), findsOneWidget);
        await tester.enterText(find.byType(TextFormField).first, 'MAA00000001');
        await tester.tap(find.widgetWithText(FilledButton, label('Capture')));
        await waitFor(
          tester,
          find.textContaining(
            label(
              'Saved on this phone. Upload now or collect the next capture.',
            ),
          ),
        );
        await waitIdle(tester);
        final original = (await tester.runAsync(
          () => queue.pending(environment.backend, 'operator-1'),
        ))!.single;
        final bytes = await tester.runAsync(
          () => File(original.imagePath).readAsBytes(),
        );
        final metadata = jsonEncode(original.metadata);
        await saveDesignFrame(
          tester,
          frame,
          'language-${language.code}-capture',
        );
        await tester.tap(find.byType(NavigationDestination).at(3));
        await tester.pumpAndSettle();
        expect(find.byType(DropdownButton<AppLanguage>), findsOneWidget);
        expect(find.text(language.label), findsOneWidget);
        await saveDesignFrame(tester, frame, 'language-${language.code}-tools');
        final next = language == AppLanguage.english
            ? AppLanguage.uzCyrillic
            : AppLanguage.english;
        await tester.tap(find.byType(DropdownButton<AppLanguage>));
        await tester.pumpAndSettle();
        await tester.tap(find.text(next.label).last);
        await waitIdle(tester);
        await tester.pumpAndSettle();
        expect(find.text(next.label), findsOneWidget);
        await tester.tap(find.byType(NavigationDestination).at(0));
        await tester.pumpAndSettle();
        expect(find.text(label('Local quality check passed')), findsOneWidget);
        expect(find.textContaining('MAA00000001'), findsWidgets);
        expect(find.byType(Image), findsOneWidget);
        final after = (await tester.runAsync(
          () => queue.pending(environment.backend, 'operator-1'),
        ))!.single;
        expect(after.key, original.key);
        expect(jsonEncode(after.metadata), metadata);
        expect(
          await tester.runAsync(() => File(after.imagePath).readAsBytes()),
          bytes,
        );
        expect(camera.shots, 1);
        expect(camera.disposed, isFalse);
        await tester.tap(find.byType(NavigationDestination).at(1));
        await tester.pumpAndSettle();
        expect(find.text(label('Upload pending captures')), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
      },
    );

    testWidgets(
      '${language.code}: native menus, registry and large-text tools use the selected script',
      (tester) async {
        final api = FakeApi();
        api.registryAnimal['owner'] = {
          'owner_id': 'OWNER-001',
          'name': 'Ғулом / Иван / O‘ktam',
        };
        final settings = controller(initial: language);
        final environment = CaptureEnvironment(
          api: api,
          backend: 'http://language-test.invalid',
          operatorId: 'operator-1',
          openQueue: () async => OfflineQueue(Directory('${root.path}/queue')),
          openCamera: () async => FakeCamera(root),
          gps: () async => null,
          deviceSignals: () async => {},
          quality: (_, _) async =>
              const LocalQuality(10, 0, ['Too dark — improve lighting']),
          exportDirectory: () async => root,
          share: (_, _) async {},
        );
        tester.view.physicalSize = const Size(320, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(
          BioLivestockApp(language: settings, environment: environment),
        );
        await waitFor(
          tester,
          find.byType(DropdownButtonFormField<SpeciesConfig>),
        );
        await waitIdle(tester);
        final context = tester.element(find.byType(Scaffold).first);
        final strings = FieldLocalizations.of(context);
        final material = MaterialLocalizations.of(context);
        if (language == AppLanguage.uzCyrillic) {
          expect(material.copyButtonLabel, 'Нусха олиш');
          expect(
            material.aboutListTileTitle('MAA00000001 Иван'),
            contains('MAA00000001 Иван'),
          );
          expect(material.tabLabel(tabIndex: 1, tabCount: 2), contains('1'));
        }
        expect(
          strings.resolve(qualityReason('Too dark — improve lighting')),
          isNotEmpty,
        );
        await tester.tap(find.byType(NavigationDestination).at(2));
        await waitIdle(tester);
        expect(find.textContaining('Ғулом / Иван / O‘ktam'), findsOneWidget);
        expect(
          find.text(strings.resolve(const UiText('An ID for life.'))),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(NavigationDestination).at(3));
        await tester.pumpAndSettle();
        expect(find.text(language.label), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        settings.dispose();
      },
    );
  }
}
