import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jalide/theme/jalide_theme.dart';
import 'package:jalide/widgets/file_explorer.dart';

void main() {
  testWidgets('Dialogo de exclusao nao lança erro ao confirmar', (tester) async {
    bool deleted = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ThemeProvider(
          notifier: ValueNotifier<ThemeType>(ThemeType.dark),
          child: FileExplorerDrawer(
            projectPath: '/tmp/jalide-test',
            projectFiles: const [
              {
                'name': 'teste.txt',
                'path': '/tmp/jalide-test/teste.txt',
                'isDir': false,
                'isSaf': false,
                'isRemote': false,
              },
            ],
            onFileTap: (_) {},
            onNavigateFolder: (_) {},
            onPickFolder: () {},
            onOpenTermux: () {},
            onCreateFile: (_) {},
            onCreateFolder: (_) {},
            onDeleteItem: (path, isDir, isRemote, isSaf) {
              deleted = true;
            },
            termuxChannel: const MethodChannel('termux'),
          ),
        ),
      ),
    );

    tester.widget<ListTile>(find.byType(ListTile)).onLongPress?.call();
    await tester.pumpAndSettle();

    expect(find.text('Excluir'), findsOneWidget);
    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmar exclusão'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'teste.txt');
    await tester.pump();

    await tester.tap(find.text('Excluir'));
    await tester.pumpAndSettle();

    expect(deleted, isTrue);
    expect(tester.takeException(), isNull);
  });
}
