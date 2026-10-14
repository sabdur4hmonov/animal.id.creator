// Script adaptation of the installed SDK's Uzbek translations, without changing user arguments.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

String uzbekCyrillic(String value) {
  const letters = {
    'a': 'а',
    'b': 'б',
    'd': 'д',
    'e': 'е',
    'f': 'ф',
    'g': 'г',
    'h': 'ҳ',
    'i': 'и',
    'j': 'ж',
    'k': 'к',
    'l': 'л',
    'm': 'м',
    'n': 'н',
    'o': 'о',
    'p': 'п',
    'q': 'қ',
    'r': 'р',
    's': 'с',
    't': 'т',
    'u': 'у',
    'v': 'в',
    'x': 'х',
    'y': 'й',
    'z': 'з',
  };
  const pairs = {
    'o‘': 'ў',
    "o'": 'ў',
    'oʻ': 'ў',
    'o’': 'ў',
    'g‘': 'ғ',
    "g'": 'ғ',
    'gʻ': 'ғ',
    'g’': 'ғ',
    'sh': 'ш',
    'ch': 'ч',
    'yo': 'ё',
    'yu': 'ю',
    'ya': 'я',
    'ye': 'е',
  };
  // Raw SDK substitution names remain Latin so inherited methods insert untouched user values.
  return value.splitMapJoin(
    RegExp(r'\$[A-Za-z][A-Za-z0-9]*'),
    onMatch: (m) => m[0]!,
    onNonMatch: (text) {
      final result = StringBuffer();
      for (var i = 0; i < text.length; i++) {
        final character = text[i];
        final pair = i + 1 < text.length
            ? text.substring(i, i + 2).toLowerCase()
            : '';
        var mapped = pairs[pair];
        if (pair == 'yo' &&
            i + 2 < text.length &&
            "‘’ʻ'".contains(text[i + 2])) {
          mapped = null;
        }
        if (mapped != null) {
          i++;
        } else {
          mapped = letters[character.toLowerCase()] ?? character;
          if ("‘’ʻ'".contains(character) &&
              i > 0 &&
              i + 1 < text.length &&
              RegExp(r'[A-Za-z]').hasMatch(text[i - 1]) &&
              RegExp(r'[A-Za-z]').hasMatch(text[i + 1])) {
            mapped = 'ъ';
          }
          if (character.toLowerCase() == 'e' &&
              (i == 0 || !RegExp(r'[A-Za-z‘’ʻ]').hasMatch(text[i - 1]))) {
            mapped = 'э';
          }
        }
        result.write(
          character != character.toLowerCase() ? mapped.toUpperCase() : mapped,
        );
      }
      return result.toString();
    },
  );
}

class UzbekCyrillicMaterialDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const UzbekCyrillicMaterialDelegate();
  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'uz' && locale.scriptCode == 'Cyrl';
  @override
  Future<MaterialLocalizations> load(Locale locale) async {
    await GlobalMaterialLocalizations.delegate.load(const Locale('uz'));
    return UzbekCyrillicMaterial(
      fullYearFormat: intl.DateFormat.y('uz'),
      compactDateFormat: intl.DateFormat.yMd('uz'),
      shortDateFormat: intl.DateFormat.yMMMd('uz'),
      mediumDateFormat: intl.DateFormat.MMMEd('uz'),
      longDateFormat: intl.DateFormat.yMMMMEEEEd('uz'),
      yearMonthFormat: intl.DateFormat.yMMMM('uz'),
      shortMonthDayFormat: intl.DateFormat.MMMd('uz'),
      decimalFormat: intl.NumberFormat.decimalPattern('uz'),
      twoDigitZeroPaddedFormat: intl.NumberFormat('00', 'uz'),
    );
  }

  @override
  bool shouldReload(UzbekCyrillicMaterialDelegate old) => false;
}

class UzbekCyrillicMaterial extends MaterialLocalizationUz {
  const UzbekCyrillicMaterial({
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });
  @override
  String get aboutListTileTitleRaw =>
      uzbekCyrillic(super.aboutListTileTitleRaw);
  @override
  String get alertDialogLabel => uzbekCyrillic(super.alertDialogLabel);
  @override
  String get anteMeridiemAbbreviation =>
      uzbekCyrillic(super.anteMeridiemAbbreviation);
  @override
  String get backButtonTooltip => uzbekCyrillic(super.backButtonTooltip);
  @override
  String get bottomSheetLabel => uzbekCyrillic(super.bottomSheetLabel);
  @override
  String get calendarModeButtonLabel =>
      uzbekCyrillic(super.calendarModeButtonLabel);
  @override
  String get cancelButtonLabel => uzbekCyrillic(super.cancelButtonLabel);
  @override
  String get clearButtonTooltip => uzbekCyrillic(super.clearButtonTooltip);
  @override
  String get closeButtonLabel => uzbekCyrillic(super.closeButtonLabel);
  @override
  String get closeButtonTooltip => uzbekCyrillic(super.closeButtonTooltip);
  @override
  String get collapsedHint => uzbekCyrillic(super.collapsedHint);
  @override
  String get collapsedIconTapHint => uzbekCyrillic(super.collapsedIconTapHint);
  @override
  String get continueButtonLabel => uzbekCyrillic(super.continueButtonLabel);
  @override
  String get copyButtonLabel => uzbekCyrillic(super.copyButtonLabel);
  @override
  String get currentDateLabel => uzbekCyrillic(super.currentDateLabel);
  @override
  String get cutButtonLabel => uzbekCyrillic(super.cutButtonLabel);
  @override
  String get dateHelpText => uzbekCyrillic(super.dateHelpText);
  @override
  String get dateInputLabel => uzbekCyrillic(super.dateInputLabel);
  @override
  String get dateOutOfRangeLabel => uzbekCyrillic(super.dateOutOfRangeLabel);
  @override
  String get datePickerHelpText => uzbekCyrillic(super.datePickerHelpText);
  @override
  String get dateRangeEndDateSemanticLabelRaw =>
      uzbekCyrillic(super.dateRangeEndDateSemanticLabelRaw);
  @override
  String get dateRangeEndLabel => uzbekCyrillic(super.dateRangeEndLabel);
  @override
  String get dateRangePickerHelpText =>
      uzbekCyrillic(super.dateRangePickerHelpText);
  @override
  String get dateRangeStartDateSemanticLabelRaw =>
      uzbekCyrillic(super.dateRangeStartDateSemanticLabelRaw);
  @override
  String get dateRangeStartLabel => uzbekCyrillic(super.dateRangeStartLabel);
  @override
  String get dateSeparator => uzbekCyrillic(super.dateSeparator);
  @override
  String get deleteButtonTooltip => uzbekCyrillic(super.deleteButtonTooltip);
  @override
  String get dialModeButtonLabel => uzbekCyrillic(super.dialModeButtonLabel);
  @override
  String get dialogLabel => uzbekCyrillic(super.dialogLabel);
  @override
  String get drawerLabel => uzbekCyrillic(super.drawerLabel);
  @override
  String get expandedHint => uzbekCyrillic(super.expandedHint);
  @override
  String get expandedIconTapHint => uzbekCyrillic(super.expandedIconTapHint);
  @override
  String get expansionTileCollapsedHint =>
      uzbekCyrillic(super.expansionTileCollapsedHint);
  @override
  String get expansionTileCollapsedTapHint =>
      uzbekCyrillic(super.expansionTileCollapsedTapHint);
  @override
  String get expansionTileExpandedHint =>
      uzbekCyrillic(super.expansionTileExpandedHint);
  @override
  String get expansionTileExpandedTapHint =>
      uzbekCyrillic(super.expansionTileExpandedTapHint);
  @override
  String get firstPageTooltip => uzbekCyrillic(super.firstPageTooltip);
  @override
  String get hideAccountsLabel => uzbekCyrillic(super.hideAccountsLabel);
  @override
  String get inputDateModeButtonLabel =>
      uzbekCyrillic(super.inputDateModeButtonLabel);
  @override
  String get inputTimeModeButtonLabel =>
      uzbekCyrillic(super.inputTimeModeButtonLabel);
  @override
  String get invalidDateFormatLabel =>
      uzbekCyrillic(super.invalidDateFormatLabel);
  @override
  String get invalidDateRangeLabel =>
      uzbekCyrillic(super.invalidDateRangeLabel);
  @override
  String get invalidTimeLabel => uzbekCyrillic(super.invalidTimeLabel);
  @override
  String get keyboardKeyAlt => uzbekCyrillic(super.keyboardKeyAlt);
  @override
  String get keyboardKeyAltGraph => uzbekCyrillic(super.keyboardKeyAltGraph);
  @override
  String get keyboardKeyBackspace => uzbekCyrillic(super.keyboardKeyBackspace);
  @override
  String get keyboardKeyCapsLock => uzbekCyrillic(super.keyboardKeyCapsLock);
  @override
  String get keyboardKeyChannelDown =>
      uzbekCyrillic(super.keyboardKeyChannelDown);
  @override
  String get keyboardKeyChannelUp => uzbekCyrillic(super.keyboardKeyChannelUp);
  @override
  String get keyboardKeyControl => uzbekCyrillic(super.keyboardKeyControl);
  @override
  String get keyboardKeyDelete => uzbekCyrillic(super.keyboardKeyDelete);
  @override
  String get keyboardKeyEject => uzbekCyrillic(super.keyboardKeyEject);
  @override
  String get keyboardKeyEnd => uzbekCyrillic(super.keyboardKeyEnd);
  @override
  String get keyboardKeyEscape => uzbekCyrillic(super.keyboardKeyEscape);
  @override
  String get keyboardKeyFn => uzbekCyrillic(super.keyboardKeyFn);
  @override
  String get keyboardKeyHome => uzbekCyrillic(super.keyboardKeyHome);
  @override
  String get keyboardKeyInsert => uzbekCyrillic(super.keyboardKeyInsert);
  @override
  String get keyboardKeyMeta => uzbekCyrillic(super.keyboardKeyMeta);
  @override
  String get keyboardKeyMetaMacOs => uzbekCyrillic(super.keyboardKeyMetaMacOs);
  @override
  String get keyboardKeyMetaWindows =>
      uzbekCyrillic(super.keyboardKeyMetaWindows);
  @override
  String get keyboardKeyNumLock => uzbekCyrillic(super.keyboardKeyNumLock);
  @override
  String get keyboardKeyNumpad0 => uzbekCyrillic(super.keyboardKeyNumpad0);
  @override
  String get keyboardKeyNumpad1 => uzbekCyrillic(super.keyboardKeyNumpad1);
  @override
  String get keyboardKeyNumpad2 => uzbekCyrillic(super.keyboardKeyNumpad2);
  @override
  String get keyboardKeyNumpad3 => uzbekCyrillic(super.keyboardKeyNumpad3);
  @override
  String get keyboardKeyNumpad4 => uzbekCyrillic(super.keyboardKeyNumpad4);
  @override
  String get keyboardKeyNumpad5 => uzbekCyrillic(super.keyboardKeyNumpad5);
  @override
  String get keyboardKeyNumpad6 => uzbekCyrillic(super.keyboardKeyNumpad6);
  @override
  String get keyboardKeyNumpad7 => uzbekCyrillic(super.keyboardKeyNumpad7);
  @override
  String get keyboardKeyNumpad8 => uzbekCyrillic(super.keyboardKeyNumpad8);
  @override
  String get keyboardKeyNumpad9 => uzbekCyrillic(super.keyboardKeyNumpad9);
  @override
  String get keyboardKeyNumpadAdd => uzbekCyrillic(super.keyboardKeyNumpadAdd);
  @override
  String get keyboardKeyNumpadComma =>
      uzbekCyrillic(super.keyboardKeyNumpadComma);
  @override
  String get keyboardKeyNumpadDecimal =>
      uzbekCyrillic(super.keyboardKeyNumpadDecimal);
  @override
  String get keyboardKeyNumpadDivide =>
      uzbekCyrillic(super.keyboardKeyNumpadDivide);
  @override
  String get keyboardKeyNumpadEnter =>
      uzbekCyrillic(super.keyboardKeyNumpadEnter);
  @override
  String get keyboardKeyNumpadEqual =>
      uzbekCyrillic(super.keyboardKeyNumpadEqual);
  @override
  String get keyboardKeyNumpadMultiply =>
      uzbekCyrillic(super.keyboardKeyNumpadMultiply);
  @override
  String get keyboardKeyNumpadParenLeft =>
      uzbekCyrillic(super.keyboardKeyNumpadParenLeft);
  @override
  String get keyboardKeyNumpadParenRight =>
      uzbekCyrillic(super.keyboardKeyNumpadParenRight);
  @override
  String get keyboardKeyNumpadSubtract =>
      uzbekCyrillic(super.keyboardKeyNumpadSubtract);
  @override
  String get keyboardKeyPageDown => uzbekCyrillic(super.keyboardKeyPageDown);
  @override
  String get keyboardKeyPageUp => uzbekCyrillic(super.keyboardKeyPageUp);
  @override
  String get keyboardKeyPower => uzbekCyrillic(super.keyboardKeyPower);
  @override
  String get keyboardKeyPowerOff => uzbekCyrillic(super.keyboardKeyPowerOff);
  @override
  String get keyboardKeyPrintScreen =>
      uzbekCyrillic(super.keyboardKeyPrintScreen);
  @override
  String get keyboardKeyScrollLock =>
      uzbekCyrillic(super.keyboardKeyScrollLock);
  @override
  String get keyboardKeySelect => uzbekCyrillic(super.keyboardKeySelect);
  @override
  String get keyboardKeyShift => uzbekCyrillic(super.keyboardKeyShift);
  @override
  String get keyboardKeySpace => uzbekCyrillic(super.keyboardKeySpace);
  @override
  String get lastPageTooltip => uzbekCyrillic(super.lastPageTooltip);
  @override
  String get licensesPackageDetailTextOther =>
      uzbekCyrillic(super.licensesPackageDetailTextOther);
  @override
  String get licensesPageTitle => uzbekCyrillic(super.licensesPageTitle);
  @override
  String get lookUpButtonLabel => uzbekCyrillic(super.lookUpButtonLabel);
  @override
  String get menuBarMenuLabel => uzbekCyrillic(super.menuBarMenuLabel);
  @override
  String get menuDismissLabel => uzbekCyrillic(super.menuDismissLabel);
  @override
  String get modalBarrierDismissLabel =>
      uzbekCyrillic(super.modalBarrierDismissLabel);
  @override
  String get moreButtonTooltip => uzbekCyrillic(super.moreButtonTooltip);
  @override
  String get nextMonthTooltip => uzbekCyrillic(super.nextMonthTooltip);
  @override
  String get nextPageTooltip => uzbekCyrillic(super.nextPageTooltip);
  @override
  String get okButtonLabel => uzbekCyrillic(super.okButtonLabel);
  @override
  String get openAppDrawerTooltip => uzbekCyrillic(super.openAppDrawerTooltip);
  @override
  String get pageRowsInfoTitleRaw => uzbekCyrillic(super.pageRowsInfoTitleRaw);
  @override
  String get pageRowsInfoTitleApproximateRaw =>
      uzbekCyrillic(super.pageRowsInfoTitleApproximateRaw);
  @override
  String get pasteButtonLabel => uzbekCyrillic(super.pasteButtonLabel);
  @override
  String get popupMenuLabel => uzbekCyrillic(super.popupMenuLabel);
  @override
  String get postMeridiemAbbreviation =>
      uzbekCyrillic(super.postMeridiemAbbreviation);
  @override
  String get previousMonthTooltip => uzbekCyrillic(super.previousMonthTooltip);
  @override
  String get previousPageTooltip => uzbekCyrillic(super.previousPageTooltip);
  @override
  String get refreshIndicatorSemanticLabel =>
      uzbekCyrillic(super.refreshIndicatorSemanticLabel);
  @override
  String get remainingTextFieldCharacterCountOther =>
      uzbekCyrillic(super.remainingTextFieldCharacterCountOther);
  @override
  String get reorderItemDown => uzbekCyrillic(super.reorderItemDown);
  @override
  String get reorderItemLeft => uzbekCyrillic(super.reorderItemLeft);
  @override
  String get reorderItemRight => uzbekCyrillic(super.reorderItemRight);
  @override
  String get reorderItemToEnd => uzbekCyrillic(super.reorderItemToEnd);
  @override
  String get reorderItemToStart => uzbekCyrillic(super.reorderItemToStart);
  @override
  String get reorderItemUp => uzbekCyrillic(super.reorderItemUp);
  @override
  String get rowsPerPageTitle => uzbekCyrillic(super.rowsPerPageTitle);
  @override
  String get saveButtonLabel => uzbekCyrillic(super.saveButtonLabel);
  @override
  String get scanTextButtonLabel => uzbekCyrillic(super.scanTextButtonLabel);
  @override
  String get scrimLabel => uzbekCyrillic(super.scrimLabel);
  @override
  String get scrimOnTapHintRaw => uzbekCyrillic(super.scrimOnTapHintRaw);
  @override
  String get searchFieldLabel => uzbekCyrillic(super.searchFieldLabel);
  @override
  String get searchWebButtonLabel => uzbekCyrillic(super.searchWebButtonLabel);
  @override
  String get selectAllButtonLabel => uzbekCyrillic(super.selectAllButtonLabel);
  @override
  String get selectYearSemanticsLabel =>
      uzbekCyrillic(super.selectYearSemanticsLabel);
  @override
  String get selectedDateLabel => uzbekCyrillic(super.selectedDateLabel);
  @override
  String get selectedRowCountTitleOther =>
      uzbekCyrillic(super.selectedRowCountTitleOther);
  @override
  String get shareButtonLabel => uzbekCyrillic(super.shareButtonLabel);
  @override
  String get showAccountsLabel => uzbekCyrillic(super.showAccountsLabel);
  @override
  String get showMenuTooltip => uzbekCyrillic(super.showMenuTooltip);
  @override
  String get signedInLabel => uzbekCyrillic(super.signedInLabel);
  @override
  String get tabLabelRaw => uzbekCyrillic(super.tabLabelRaw);
  @override
  String get timePickerDialHelpText =>
      uzbekCyrillic(super.timePickerDialHelpText);
  @override
  String get timePickerHourLabel => uzbekCyrillic(super.timePickerHourLabel);
  @override
  String get timePickerHourModeAnnouncement =>
      uzbekCyrillic(super.timePickerHourModeAnnouncement);
  @override
  String get timePickerInputHelpText =>
      uzbekCyrillic(super.timePickerInputHelpText);
  @override
  String get timePickerMinuteLabel =>
      uzbekCyrillic(super.timePickerMinuteLabel);
  @override
  String get timePickerMinuteModeAnnouncement =>
      uzbekCyrillic(super.timePickerMinuteModeAnnouncement);
  @override
  String get unspecifiedDate => uzbekCyrillic(super.unspecifiedDate);
  @override
  String get unspecifiedDateRange => uzbekCyrillic(super.unspecifiedDateRange);
  @override
  String get viewLicensesButtonLabel =>
      uzbekCyrillic(super.viewLicensesButtonLabel);
  @override
  String formatShortDate(DateTime date) =>
      uzbekCyrillic(super.formatShortDate(date));
  @override
  String formatMediumDate(DateTime date) =>
      uzbekCyrillic(super.formatMediumDate(date));
  @override
  String formatFullDate(DateTime date) =>
      uzbekCyrillic(super.formatFullDate(date));
  @override
  String formatMonthYear(DateTime date) =>
      uzbekCyrillic(super.formatMonthYear(date));
  @override
  String formatShortMonthDay(DateTime date) =>
      uzbekCyrillic(super.formatShortMonthDay(date));
  @override
  List<String> get narrowWeekdays =>
      super.narrowWeekdays.map(uzbekCyrillic).toList();
  @override
  String? get licensesPackageDetailTextOne =>
      _nullableCyrillic(super.licensesPackageDetailTextOne);
  @override
  String? get licensesPackageDetailTextZero =>
      _nullableCyrillic(super.licensesPackageDetailTextZero);
  @override
  String? get remainingTextFieldCharacterCountOne =>
      _nullableCyrillic(super.remainingTextFieldCharacterCountOne);
  @override
  String? get selectedRowCountTitleOne =>
      _nullableCyrillic(super.selectedRowCountTitleOne);
}

class UzbekCyrillicCupertinoDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const UzbekCyrillicCupertinoDelegate();
  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'uz' && locale.scriptCode == 'Cyrl';
  @override
  Future<CupertinoLocalizations> load(Locale locale) async {
    await GlobalCupertinoLocalizations.delegate.load(const Locale('uz'));
    return UzbekCyrillicCupertino(
      fullYearFormat: intl.DateFormat.y('uz'),
      dayFormat: intl.DateFormat.d('uz'),
      weekdayFormat: intl.DateFormat.EEEE('uz'),
      mediumDateFormat: intl.DateFormat.MMMEd('uz'),
      singleDigitHourFormat: intl.DateFormat.H('uz'),
      singleDigitMinuteFormat: intl.DateFormat.m('uz'),
      doubleDigitMinuteFormat: intl.DateFormat('mm', 'uz'),
      singleDigitSecondFormat: intl.DateFormat.s('uz'),
      decimalFormat: intl.NumberFormat.decimalPattern('uz'),
    );
  }

  @override
  bool shouldReload(UzbekCyrillicCupertinoDelegate old) => false;
}

class UzbekCyrillicCupertino extends CupertinoLocalizationUz {
  const UzbekCyrillicCupertino({
    required super.fullYearFormat,
    required super.dayFormat,
    required super.weekdayFormat,
    required super.mediumDateFormat,
    required super.singleDigitHourFormat,
    required super.singleDigitMinuteFormat,
    required super.doubleDigitMinuteFormat,
    required super.singleDigitSecondFormat,
    required super.decimalFormat,
  });
  @override
  String datePickerMonth(int monthIndex) =>
      uzbekCyrillic(super.datePickerMonth(monthIndex));
  @override
  String datePickerStandaloneMonth(int monthIndex) =>
      uzbekCyrillic(super.datePickerStandaloneMonth(monthIndex));
  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) =>
      uzbekCyrillic(super.datePickerDayOfMonth(dayIndex, weekDay));
  @override
  String datePickerMediumDate(DateTime date) =>
      uzbekCyrillic(super.datePickerMediumDate(date));
  @override
  String get alertDialogLabel => uzbekCyrillic(super.alertDialogLabel);
  @override
  String get anteMeridiemAbbreviation =>
      uzbekCyrillic(super.anteMeridiemAbbreviation);
  @override
  String get backButtonLabel => uzbekCyrillic(super.backButtonLabel);
  @override
  String get cancelButtonLabel => uzbekCyrillic(super.cancelButtonLabel);
  @override
  String get clearButtonLabel => uzbekCyrillic(super.clearButtonLabel);
  @override
  String get collapsedHint => uzbekCyrillic(super.collapsedHint);
  @override
  String get copyButtonLabel => uzbekCyrillic(super.copyButtonLabel);
  @override
  String get cutButtonLabel => uzbekCyrillic(super.cutButtonLabel);
  @override
  String get datePickerHourSemanticsLabelOther =>
      uzbekCyrillic(super.datePickerHourSemanticsLabelOther);
  @override
  String get datePickerMinuteSemanticsLabelOther =>
      uzbekCyrillic(super.datePickerMinuteSemanticsLabelOther);
  @override
  String get expandedHint => uzbekCyrillic(super.expandedHint);
  @override
  String get expansionTileCollapsedHint =>
      uzbekCyrillic(super.expansionTileCollapsedHint);
  @override
  String get expansionTileCollapsedTapHint =>
      uzbekCyrillic(super.expansionTileCollapsedTapHint);
  @override
  String get expansionTileExpandedHint =>
      uzbekCyrillic(super.expansionTileExpandedHint);
  @override
  String get expansionTileExpandedTapHint =>
      uzbekCyrillic(super.expansionTileExpandedTapHint);
  @override
  String get lookUpButtonLabel => uzbekCyrillic(super.lookUpButtonLabel);
  @override
  String get menuDismissLabel => uzbekCyrillic(super.menuDismissLabel);
  @override
  String get modalBarrierDismissLabel =>
      uzbekCyrillic(super.modalBarrierDismissLabel);
  @override
  String get noSpellCheckReplacementsLabel =>
      uzbekCyrillic(super.noSpellCheckReplacementsLabel);
  @override
  String get pasteButtonLabel => uzbekCyrillic(super.pasteButtonLabel);
  @override
  String get postMeridiemAbbreviation =>
      uzbekCyrillic(super.postMeridiemAbbreviation);
  @override
  String get searchTextFieldPlaceholderLabel =>
      uzbekCyrillic(super.searchTextFieldPlaceholderLabel);
  @override
  String get searchWebButtonLabel => uzbekCyrillic(super.searchWebButtonLabel);
  @override
  String get selectAllButtonLabel => uzbekCyrillic(super.selectAllButtonLabel);
  @override
  String get shareButtonLabel => uzbekCyrillic(super.shareButtonLabel);
  @override
  String get tabSemanticsLabelRaw => uzbekCyrillic(super.tabSemanticsLabelRaw);
  @override
  String get timerPickerHourLabelOther =>
      uzbekCyrillic(super.timerPickerHourLabelOther);
  @override
  String get timerPickerMinuteLabelOther =>
      uzbekCyrillic(super.timerPickerMinuteLabelOther);
  @override
  String get timerPickerSecondLabelOther =>
      uzbekCyrillic(super.timerPickerSecondLabelOther);
  @override
  String get todayLabel => uzbekCyrillic(super.todayLabel);
  @override
  String? get datePickerHourSemanticsLabelOne =>
      _nullableCyrillic(super.datePickerHourSemanticsLabelOne);
  @override
  String? get datePickerMinuteSemanticsLabelOne =>
      _nullableCyrillic(super.datePickerMinuteSemanticsLabelOne);
  @override
  String? get timerPickerHourLabelOne =>
      _nullableCyrillic(super.timerPickerHourLabelOne);
  @override
  String? get timerPickerMinuteLabelOne =>
      _nullableCyrillic(super.timerPickerMinuteLabelOne);
  @override
  String? get timerPickerSecondLabelOne =>
      _nullableCyrillic(super.timerPickerSecondLabelOne);
}

String? _nullableCyrillic(String? value) =>
    value == null ? null : uzbekCyrillic(value);
