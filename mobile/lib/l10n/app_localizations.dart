import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt')
  ];

  /// No description provided for @newFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get newFile;

  /// No description provided for @saveAs.
  ///
  /// In en, this message translates to:
  /// **'Save as…'**
  String get saveAs;

  /// No description provided for @increaseFont.
  ///
  /// In en, this message translates to:
  /// **'Increase font'**
  String get increaseFont;

  /// No description provided for @decreaseFont.
  ///
  /// In en, this message translates to:
  /// **'Decrease font'**
  String get decreaseFont;

  /// No description provided for @formatCode.
  ///
  /// In en, this message translates to:
  /// **'Format Code'**
  String get formatCode;

  /// No description provided for @autoSaveOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-Save • ON'**
  String get autoSaveOn;

  /// No description provided for @autoSaveOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-Save • OFF'**
  String get autoSaveOff;

  /// No description provided for @autoFormatOn.
  ///
  /// In en, this message translates to:
  /// **'Auto-Format • ON'**
  String get autoFormatOn;

  /// No description provided for @autoFormatOff.
  ///
  /// In en, this message translates to:
  /// **'Auto-Format • OFF'**
  String get autoFormatOff;

  /// No description provided for @aiSettings.
  ///
  /// In en, this message translates to:
  /// **'Gemma AI Config'**
  String get aiSettings;

  /// No description provided for @ghostSuggestionsOn.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestions • ON'**
  String get ghostSuggestionsOn;

  /// No description provided for @ghostSuggestionsOff.
  ///
  /// In en, this message translates to:
  /// **'AI Suggestions • OFF'**
  String get ghostSuggestionsOff;

  /// No description provided for @sshRemote.
  ///
  /// In en, this message translates to:
  /// **'SSH Remote'**
  String get sshRemote;

  /// No description provided for @changeTheme.
  ///
  /// In en, this message translates to:
  /// **'Change Theme'**
  String get changeTheme;

  /// No description provided for @exitApp.
  ///
  /// In en, this message translates to:
  /// **'Exit application'**
  String get exitApp;

  /// No description provided for @runFile.
  ///
  /// In en, this message translates to:
  /// **'Run file'**
  String get runFile;

  /// No description provided for @openFileToRun.
  ///
  /// In en, this message translates to:
  /// **'Open a file to run'**
  String get openFileToRun;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aiAssistant.
  ///
  /// In en, this message translates to:
  /// **'AI Assistant'**
  String get aiAssistant;

  /// No description provided for @unsavedChanges.
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get unsavedChanges;

  /// No description provided for @closeTabConfirm.
  ///
  /// In en, this message translates to:
  /// **'Do you want to close \"{tabName}\"?'**
  String closeTabConfirm(String tabName);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @saveAndClose.
  ///
  /// In en, this message translates to:
  /// **'Save and Close'**
  String get saveAndClose;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @exitConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exitConfirmTitle;

  /// No description provided for @exitConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to exit the application?'**
  String get exitConfirmMessage;

  /// No description provided for @exit.
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get exit;

  /// No description provided for @selectTheme.
  ///
  /// In en, this message translates to:
  /// **'Select Theme'**
  String get selectTheme;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @fileExplorerEmptyState.
  ///
  /// In en, this message translates to:
  /// **'No project open'**
  String get fileExplorerEmptyState;

  /// No description provided for @openFolder.
  ///
  /// In en, this message translates to:
  /// **'OPEN FOLDER'**
  String get openFolder;

  /// No description provided for @openFromTermux.
  ///
  /// In en, this message translates to:
  /// **'OPEN FROM TERMUX'**
  String get openFromTermux;

  /// No description provided for @sshActive.
  ///
  /// In en, this message translates to:
  /// **'SSH ACTIVE: {label}'**
  String sshActive(String label);

  /// No description provided for @explorerRename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get explorerRename;

  /// No description provided for @explorerNewFile.
  ///
  /// In en, this message translates to:
  /// **'New file'**
  String get explorerNewFile;

  /// No description provided for @explorerNewFileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new file in this folder'**
  String get explorerNewFileSubtitle;

  /// No description provided for @explorerNewFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get explorerNewFolder;

  /// No description provided for @explorerNewFolderSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a new subfolder in this folder'**
  String get explorerNewFolderSubtitle;

  /// No description provided for @explorerNavigate.
  ///
  /// In en, this message translates to:
  /// **'Navigate'**
  String get explorerNavigate;

  /// No description provided for @explorerNavigateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Set this folder as the explorer root'**
  String get explorerNavigateSubtitle;

  /// No description provided for @aiGenerating.
  ///
  /// In en, this message translates to:
  /// **'AI generating suggestion...'**
  String get aiGenerating;

  /// No description provided for @toastCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get toastCanceled;

  /// No description provided for @toastNoExtension.
  ///
  /// In en, this message translates to:
  /// **'⚠️ File with no extension — syntax highlighting may not work.'**
  String get toastNoExtension;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {


  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en': return AppLocalizationsEn();
    case 'pt': return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}
