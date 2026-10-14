import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'api_client.dart';

enum AppLanguage {
  uzLatin(
    'uz_Latn',
    Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Latn'),
    'O‘zbekcha (lotin)',
  ),
  uzCyrillic(
    'uz_Cyrl',
    Locale.fromSubtags(languageCode: 'uz', scriptCode: 'Cyrl'),
    'Ўзбекча (кирилл)',
  ),
  russian('ru', Locale('ru'), 'Русский'),
  english('en', Locale('en'), 'English');

  const AppLanguage(this.code, this.locale, this.label);
  final String code;
  final Locale locale;
  final String label;
  static AppLanguage forLocale(Locale locale) => switch (locale.languageCode) {
    'uz' => locale.scriptCode == 'Cyrl' ? uzCyrillic : uzLatin,
    'ru' => russian,
    _ => english,
  };
}

/// Explicit templates translate UI only. IDs, names and persisted evidence are raw arguments.
class UiText {
  const UiText(this.key, [this.arguments = const []]);
  final String key;
  final List<Object?> arguments;
  String resolve(BuildContext context) =>
      FieldLocalizations.of(context).resolve(this);
  @override
  String toString() => FieldLocalizations.english.resolve(this);
}

class FieldLocalizations {
  const FieldLocalizations(this.messages);
  final Map<String, String> messages;
  static const english = FieldLocalizations({});
  static const delegate = _FieldLocalizationsDelegate();
  static FieldLocalizations of(BuildContext context) =>
      Localizations.of<FieldLocalizations>(context, FieldLocalizations) ??
      english;

  String resolve(Object? value) {
    if (value is! UiText) return value?.toString() ?? '';
    final template = messages[value.key] ?? value.key;
    // One pass prevents braces in user names/notes from becoming new placeholders.
    return template.replaceAllMapped(RegExp(r'\{(\d+)\}'), (match) {
      final index = int.parse(match[1]!);
      return index < value.arguments.length
          ? resolve(value.arguments[index])
          : match[0]!;
    });
  }
}

class _FieldLocalizationsDelegate
    extends LocalizationsDelegate<FieldLocalizations> {
  const _FieldLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) =>
      {'uz', 'ru', 'en'}.contains(locale.languageCode);
  @override
  Future<FieldLocalizations> load(Locale locale) async {
    final code = AppLanguage.forLocale(locale).code;
    final decoded =
        jsonDecode(await rootBundle.loadString('assets/l10n/$code.json'))
            as Map;
    return FieldLocalizations(Map<String, String>.from(decoded));
  }

  @override
  bool shouldReload(_FieldLocalizationsDelegate old) => false;
}

UiText speciesLabel(String value) => UiText(
  value == 'cattle'
      ? 'Cattle'
      : value == 'sheep'
      ? 'Sheep'
      : value,
);
UiText statusLabel(String value) => UiText(value);
UiText qualityReason(String value) => UiText(value);
UiText? serverQualityReason(String code) {
  final key = switch (code) {
    'resolution_too_low' => 'Resolution too low',
    'blurry' => 'Blurry — hold steady and refocus',
    'too_dark' => 'Too dark — improve lighting',
    'too_bright' => 'Too bright — avoid direct glare',
    'muzzle_too_small' => 'Move closer so the muzzle is large and sharp.',
    'muzzle_cut_off' => 'Keep the whole muzzle inside the frame.',
    'no_muzzle_detected' => 'No muzzle detected. Retake a clear, close view.',
    'multiple_muzzles_detected' =>
      'Only one muzzle may be visible in the frame.',
    'invalid_box' =>
      'Detection framing is invalid. Retake or report the technical details.',
    _ => null,
  };
  return key == null ? null : UiText(key);
}

String? animalValidation(BuildContext context, String? error) =>
    error == null ? null : UiText(error).resolve(context);

UiText userError(Object error) {
  final raw = error.toString();
  final status = error is RegistryApiError
      ? error.status
      : error is ApiError
      ? error.status
      : null;
  final message = switch (status) {
    401 => 'Sign-in key is missing or invalid; check operator configuration.',
    403 => 'Your operator cannot perform this action.',
    404 => 'Record not found; check the ID and refresh.',
    409 =>
      'The record changed or conflicts with this request; refresh and review.',
    400 || 413 || 415 || 422 =>
      'The server rejected the input; review the fields and quality checks.',
    int code when code >= 500 =>
      'The server is unavailable; retry your saved request later.',
    _ =>
      error is SocketException
          ? 'Connection unavailable. Check the server and network.'
          : error is TimeoutException
          ? 'Request timed out. Retry with the same saved request.'
          : raw.contains('API_TOKEN')
          ? 'Sign-in key is missing or invalid; check operator configuration.'
          : null,
  };
  UiText? guidance = message == null ? null : UiText(message);
  if (status == 422) {
    try {
      final text = error is RegistryApiError
          ? error.message
          : raw.substring(raw.indexOf('{'));
      final decoded = jsonDecode(text);
      final detail = decoded is Map ? decoded['detail'] : null;
      if (detail is Map) {
        final reasons = detail['quality'] is Map
            ? detail['quality']['reasons']
            : null;
        final codes = reasons is List ? reasons : [detail['reason']];
        for (final code in codes.whereType<String>()) {
          final reason = serverQualityReason(code);
          if (reason != null) guidance = UiText('{0}\n{1}', [guidance, reason]);
        }
      }
    } catch (_) {
      // Unknown server errors remain visible as diagnostic evidence.
    }
  }
  return guidance == null
      ? UiText('Request failed. Technical details: {0}', [raw])
      : UiText('{0}\nTechnical details: {1}', [guidance, raw]);
}

/// UI preferences are separate from immutable capture and registry journals.
class LanguageController extends ChangeNotifier {
  LanguageController({
    Future<File> Function()? preferenceFile,
    AppLanguage initial = AppLanguage.uzLatin,
  }) : _preferenceFile = preferenceFile ?? _nativeFile,
       language = initial;
  final Future<File> Function() _preferenceFile;
  AppLanguage language;
  bool saving = false;
  UiText? notice;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static Future<File> _nativeFile() async => File(
    '${(await getApplicationSupportDirectory()).path}/preferences/language.json',
  );

  Future<void> load() async {
    try {
      final file = await _preferenceFile();
      if (!await file.exists()) return;
      if (await FileSystemEntity.type(file.path, followLinks: false) !=
          FileSystemEntityType.file) {
        throw const FormatException(
          'Language preference is not a regular file',
        );
      }
      final value = jsonDecode(await file.readAsString());
      if (value is! Map || value['version'] != 1) {
        throw const FormatException('Invalid language preference');
      }
      language = AppLanguage.values.firstWhere(
        (item) => item.code == value['language'],
      );
    } catch (_) {
      notice = const UiText(
        'Language preference could not be read. Choose your language again.',
      );
    }
    _notify();
  }

  Future<void> select(AppLanguage next) async {
    if (saving || _disposed) return;
    saving = true;
    notice = null;
    _notify();
    try {
      final file = await _preferenceFile();
      await file.parent.create(recursive: true);
      final kind = await FileSystemEntity.type(file.path, followLinks: false);
      final temporary = File('${file.path}.next');
      final partialKind = await FileSystemEntity.type(
        temporary.path,
        followLinks: false,
      );
      if (kind != FileSystemEntityType.notFound &&
              kind != FileSystemEntityType.file ||
          partialKind != FileSystemEntityType.notFound &&
              partialKind != FileSystemEntityType.file) {
        throw const FileSystemException('Unsafe language preference path');
      }
      await temporary.writeAsString(
        jsonEncode({'version': 1, 'language': next.code}),
        flush: true,
      );
      await temporary.rename(file.path);
      language = next;
      notice = const UiText('Language saved on this phone.');
    } catch (_) {
      notice = const UiText(
        'Could not save language. Try again; your captures are retained.',
      );
    } finally {
      saving = false;
      _notify();
    }
  }
}

class LanguageScope extends InheritedNotifier<LanguageController> {
  const LanguageScope({
    super.key,
    required LanguageController controller,
    required super.child,
  }) : super(notifier: controller);
  static LanguageController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LanguageScope>()?.notifier;
}

class LanguageSettings extends StatelessWidget {
  const LanguageSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = LanguageScope.of(context);
    if (controller == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InputDecorator(
          decoration: InputDecoration(
            labelText: const UiText('Language').resolve(context),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AppLanguage>(
              value: controller.language,
              isExpanded: true,
              items: [
                for (final item in AppLanguage.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: controller.saving
                  ? null
                  : (value) {
                      if (value != null) unawaited(controller.select(value));
                    },
            ),
          ),
        ),
        if (controller.saving) const LinearProgressIndicator(),
        if (controller.notice != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: FieldText(controller.notice!),
          ),
      ],
    );
  }
}

class FieldText extends StatelessWidget {
  const FieldText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });
  final Object data;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  @override
  Widget build(BuildContext context) => Text(
    FieldLocalizations.of(context).resolve(data),
    style: style,
    textAlign: textAlign,
    maxLines: maxLines,
    overflow: overflow,
  );
}

class FieldSelectableText extends StatelessWidget {
  const FieldSelectableText(this.data, {super.key, this.style, this.minLines});
  final Object data;
  final TextStyle? style;
  final int? minLines;
  @override
  Widget build(BuildContext context) => SelectableText(
    FieldLocalizations.of(context).resolve(data),
    style: style,
    minLines: minLines,
  );
}

class FieldDestination extends StatelessWidget {
  const FieldDestination({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
  final Widget icon, selectedIcon;
  final UiText label;
  @override
  Widget build(BuildContext context) => NavigationDestination(
    icon: icon,
    selectedIcon: selectedIcon,
    label: label.resolve(context),
  );
}
