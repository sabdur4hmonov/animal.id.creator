import 'package:flutter/material.dart';
import 'capture_screen.dart';
import 'app_design.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'capture_environment.dart';
import 'localization.dart';
import 'uzbek_cyrillic_material.dart';
import 'field_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final language = LanguageController();
  await language.load();
  runApp(BioLivestockApp(language: language));
}

class BioLivestockApp extends StatefulWidget {
  const BioLivestockApp({super.key, this.language, this.environment});
  final LanguageController? language;
  final CaptureEnvironment? environment;
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
        title: 'BioLivestock Capture',
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
        home: widget.environment == null
            ? Builder(
                builder: (context) => FieldHome(
                  environment: CaptureEnvironment.native(
                    backupShareText: () => FieldLocalizations.of(context).resolve(
                      const UiText(
                        'BioLivestock phone backup — save a copy outside this app.',
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
