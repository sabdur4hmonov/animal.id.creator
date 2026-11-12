import 'package:flutter/material.dart';
import 'capture_screen.dart';
import 'app_design.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'capture_environment.dart';
import 'localization.dart';
import 'uzbek_cyrillic_material.dart';
import 'field_home.dart';
import 'app_mode.dart';
import 'demo_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xff1e3a2b),
        body: Center(
          child: Text(
            'Chorvam',
            style: TextStyle(
              color: Color(0xfffff2d4),
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    ),
  );
  final language = LanguageController();
  await language.load();
  bool modeFailed = false;
  try {
    runtimeMode = await AppRuntimeMode.detect();
  } catch (_) {
    // Fail closed: never open a production workflow when native mode is unknown.
    modeFailed = true;
  }
  runApp(BioLivestockApp(language: language, modeFailed: modeFailed));
}

class BioLivestockApp extends StatefulWidget {
  const BioLivestockApp({
    super.key,
    this.language,
    this.environment,
    this.modeFailed = false,
  });
  final LanguageController? language;
  final CaptureEnvironment? environment;
  final bool modeFailed;
  @override
  State<BioLivestockApp> createState() => _BioLivestockAppState();
}

class _BioLivestockAppState extends State<BioLivestockApp> {
  late final language = widget.language ?? LanguageController();
  @override
  void dispose() {
    if (widget.language == null) language.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LanguageScope(
    controller: language,
    child: ListenableBuilder(
      listenable: language,
      builder: (context, _) => MaterialApp(
        title: 'Chorvam',
        debugShowCheckedModeBanner: false,
        theme: fieldTheme(),
        locale: language.language.locale,
        supportedLocales: [for (final item in AppLanguage.values) item.locale],
        localizationsDelegates: const [
          FieldLocalizations.delegate,
          UzbekCyrillicMaterialDelegate(),
          UzbekCyrillicCupertinoDelegate(),
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) =>
            runtimeMode.demo ? DemoDisclosure(child: child!) : child!,
        home: widget.modeFailed
            ? const Scaffold(
                body: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: FieldText(
                      UiText(
                        'Application mode could not be checked. Close and reopen the app.',
                      ),
                    ),
                  ),
                ),
              )
            : runtimeMode.demo
            ? const DemoHome()
            : widget.environment == null
            ? Builder(
                builder: (context) => FieldHome(
                  environment: CaptureEnvironment.native(
                    backupShareText: () => FieldLocalizations.of(context).resolve(
                      const UiText(
                        'Chorvam phone backup — save a copy outside this app.',
                      ),
                    ),
                  ),
                ),
              )
            : CaptureScreen(environment: widget.environment),
      ),
    ),
  );
}
