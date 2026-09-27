import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/app/app.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('mostra acesso à configuração e à ajuda imediata', (tester) async {
    await tester.pumpWidget(const RedeApoioApp());

    expect(find.text('Configurar aplicativo'), findsOneWidget);
    expect(find.text('Acessar ajuda agora'), findsOneWidget);
    expect(find.text('Em emergência imediata, ligue para 190.'), findsOneWidget);
  });

  testWidgets('abre o cadastro de pessoa de confiança', (tester) async {
    await tester.pumpWidget(const RedeApoioApp());

    await tester.tap(find.text('Configurar aplicativo'));
    await tester.pumpAndSettle();

    expect(find.text('Pessoas de confiança'), findsOneWidget);
    expect(find.text('Digitar número'), findsOneWidget);
  });

  testWidgets('formata nome e telefone no cadastro', (tester) async {
    await tester.pumpWidget(const RedeApoioApp());
    await tester.tap(find.text('Configurar aplicativo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Digitar número'));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Nome da pessoa'), 'maria silva');
    await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), '41999998888');

    expect(find.text('Maria silva'), findsOneWidget);
    expect(find.text('(41) 99999-8888'), findsOneWidget);
  });
}
