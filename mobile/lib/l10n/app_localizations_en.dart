// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get newFile => 'New file';

  @override
  String get saveAs => 'Save as…';

  @override
  String get increaseFont => 'Increase font';

  @override
  String get decreaseFont => 'Decrease font';

  @override
  String get formatCode => 'Format Code';

  @override
  String get autoSaveOn => 'Auto-Save • ON';

  @override
  String get autoSaveOff => 'Auto-Save • OFF';

  @override
  String get autoFormatOn => 'Auto-Format • ON';

  @override
  String get autoFormatOff => 'Auto-Format • OFF';

  @override
  String get aiSettings => 'Gemma AI Config';

  @override
  String get ghostSuggestionsOn => 'AI Suggestions • ON';

  @override
  String get ghostSuggestionsOff => 'AI Suggestions • OFF';

  @override
  String get sshRemote => 'SSH Remote';

  @override
  String get changeTheme => 'Change Theme';

  @override
  String get exitApp => 'Exit application';

  @override
  String get runFile => 'Run file';

  @override
  String get openFileToRun => 'Open a file to run';

  @override
  String get save => 'Save';

  @override
  String get about => 'About';

  @override
  String get aiAssistant => 'AI Assistant';

  @override
  String get unsavedChanges => 'Unsaved changes';

  @override
  String closeTabConfirm(String tabName) {
    return 'Do you want to close \"$tabName\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get discard => 'Discard';

  @override
  String get saveAndClose => 'Save and Close';

  @override
  String get close => 'Close';

  @override
  String get exitConfirmTitle => 'Exit';

  @override
  String get exitConfirmMessage => 'Are you sure you want to exit the application?';

  @override
  String get exit => 'Exit';

  @override
  String get selectTheme => 'Select Theme';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get fileExplorerEmptyState => 'No project open';

  @override
  String get openFolder => 'OPEN FOLDER';

  @override
  String get openFromTermux => 'OPEN FROM TERMUX';

  @override
  String sshActive(String label) {
    return 'SSH ACTIVE: $label';
  }

  @override
  String get explorerRename => 'Rename';

  @override
  String get explorerNewFile => 'New file';

  @override
  String get explorerNewFileSubtitle => 'Create a new file in this folder';

  @override
  String get explorerNewFolder => 'New folder';

  @override
  String get explorerNewFolderSubtitle => 'Create a new subfolder in this folder';

  @override
  String get explorerNavigate => 'Navigate';

  @override
  String get explorerNavigateSubtitle => 'Set this folder as the explorer root';

  @override
  String get aiGenerating => 'AI generating suggestion...';

  @override
  String get toastCanceled => 'Canceled';

  @override
  String get toastNoExtension => '⚠️ File with no extension — syntax highlighting may not work.';
}
