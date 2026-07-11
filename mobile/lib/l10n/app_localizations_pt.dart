// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get newFile => 'Novo arquivo';

  @override
  String get saveAs => 'Salvar como…';

  @override
  String get increaseFont => 'Aumentar fonte';

  @override
  String get decreaseFont => 'Diminuir fonte';

  @override
  String get formatCode => 'Formatar Código';

  @override
  String get autoSaveOn => 'Auto-Save • ON';

  @override
  String get autoSaveOff => 'Auto-Save • OFF';

  @override
  String get autoFormatOn => 'Auto-Format • ON';

  @override
  String get autoFormatOff => 'Auto-Format • OFF';

  @override
  String get aiSettings => 'Config. Gemma IA';

  @override
  String get ghostSuggestionsOn => 'Sugestões IA • ON';

  @override
  String get ghostSuggestionsOff => 'Sugestões IA • OFF';

  @override
  String get sshRemote => 'SSH Remote';

  @override
  String get changeTheme => 'Mudar Tema';

  @override
  String get exitApp => 'Sair da aplicação';

  @override
  String get runFile => 'Executar arquivo';

  @override
  String get openFileToRun => 'Abra um arquivo para executar';

  @override
  String get save => 'Salvar';

  @override
  String get about => 'Sobre';

  @override
  String get aiAssistant => 'Assistente IA';

  @override
  String get unsavedChanges => 'Alterações não salvas';

  @override
  String closeTabConfirm(String tabName) {
    return 'Deseja fechar \"$tabName\"?';
  }

  @override
  String get cancel => 'Cancelar';

  @override
  String get discard => 'Descartar';

  @override
  String get saveAndClose => 'Salvar e Fechar';

  @override
  String get close => 'Fechar';

  @override
  String get exitConfirmTitle => 'Sair';

  @override
  String get exitConfirmMessage => 'Tem certeza que deseja sair da aplicação?';

  @override
  String get exit => 'Sair';

  @override
  String get selectTheme => 'Selecionar Tema';

  @override
  String get disconnect => 'Desconectar';

  @override
  String get fileExplorerEmptyState => 'Nenhum projeto aberto';

  @override
  String get openFolder => 'ABRIR PASTA';

  @override
  String get openFromTermux => 'ABRIR DO TERMUX';

  @override
  String sshActive(String label) {
    return 'SSH ATIVO: $label';
  }

  @override
  String get explorerRename => 'Renomear';

  @override
  String get explorerNewFile => 'Novo arquivo';

  @override
  String get explorerNewFileSubtitle => 'Criar um novo arquivo dentro desta pasta';

  @override
  String get explorerNewFolder => 'Nova pasta';

  @override
  String get explorerNewFolderSubtitle => 'Criar uma nova subpasta dentro desta pasta';

  @override
  String get explorerNavigate => 'Navegar';

  @override
  String get explorerNavigateSubtitle => 'Definir esta pasta como raiz do explorador';

  @override
  String get aiGenerating => 'IA gerando sugestão...';

  @override
  String get toastCanceled => 'Cancelado';

  @override
  String get toastNoExtension => '⚠️ Arquivo sem extensão — o realce de sintaxe pode não funcionar.';
}
