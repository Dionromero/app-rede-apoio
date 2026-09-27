import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/api.dart';
import 'package:rede_apoio/core/theme/app_theme.dart';
import 'package:rede_apoio/features/trusted_contact/presentation/pages/trusted_contact_page.dart';

void _salvos(List<TrustedContact> contatos) => FlutterSecureStorage.setMockInitialValues({
      'trusted_contacts_v2': jsonEncode(contatos.map((c) => c.toJson()).toList()),
    });

/// Finge ser o seletor de contatos do Android respondendo com [resposta].
void _simularAgenda(Map<String, Object?>? resposta) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter_native_contact_picker'),
    (call) async => call.method == 'selectPhoneNumber' ? resposta : null,
  );
}

Future<void> _abrir(WidgetTester tester) async {
  // Tela alta: o ListView só constrói o que cabe na tela, e a padrão (800x600) é baixa.
  tester.view.physicalSize = const Size(440, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: TrustedContactPage(repository: TrustedContactRepository()),
  ));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  tearDown(() => _simularAgenda(null));

  group('TrustedContactRepository', () {
    test('adiciona, recusa número repetido e respeita o limite', () async {
      final repo = TrustedContactRepository();
      expect(await repo.carregarTodos(), isEmpty);

      for (var i = 0; i < TrustedContactRepository.limite; i++) {
        final r = await repo.adicionar(TrustedContact(name: 'Pessoa $i', phone: '554199999000$i'));
        expect(r, ResultadoAdicao.adicionado);
      }
      expect(await repo.adicionar(const TrustedContact(name: 'Outra', phone: '5541999990000')),
          ResultadoAdicao.duplicado);
      expect(await repo.adicionar(const TrustedContact(name: 'Sexta', phone: '5541988887777')),
          ResultadoAdicao.limiteAtingido);
      expect((await repo.carregarTodos()).length, TrustedContactRepository.limite);
    });

    test('remove pelo telefone', () async {
      _salvos(const [
        TrustedContact(name: 'Ana', phone: '5541999998888'),
        TrustedContact(name: 'Bia', phone: '5541988887777'),
      ]);
      final repo = TrustedContactRepository();
      await repo.remover('5541999998888');
      expect((await repo.carregarTodos()).map((c) => c.name), ['Bia']);
    });

    test('dado salvo corrompido vira lista vazia', () async {
      FlutterSecureStorage.setMockInitialValues({'trusted_contacts_v2': 'não é json'});
      expect(await TrustedContactRepository().carregarTodos(), isEmpty);
    });
  });

  group('TrustedContactPage', () {
    testWidgets('adiciona uma pessoa digitada e mostra na lista', (tester) async {
      await _abrir(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da pessoa'), 'maria silva');
      await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), '41999998888');
      await _tocar(tester, find.text('Adicionar à lista'));

      expect(find.text('Cadastradas (1 de 5)'), findsOneWidget);
      expect(find.text('Maria silva'), findsOneWidget);
      expect(find.text('(41) 99999-8888'), findsOneWidget);
      expect(find.text('Maria silva está na sua lista. Nada foi enviado.'), findsOneWidget);
    });

    testWidgets('mostra as pessoas salvas e remove com confirmação', (tester) async {
      _salvos(const [
        TrustedContact(name: 'Ana', phone: '5541999998888'),
        TrustedContact(name: 'Bia', phone: '5541988887777'),
      ]);
      await _abrir(tester);
      expect(find.text('Cadastradas (2 de 5)'), findsOneWidget);

      await _tocar(tester, find.byTooltip('Remover Ana'));
      expect(find.text('Remover Ana?'), findsOneWidget);
      await _tocar(tester, find.widgetWithText(FilledButton, 'Remover'));

      expect(find.text('Ana'), findsNothing);
      expect(find.text('Cadastradas (1 de 5)'), findsOneWidget);
    });

    testWidgets('com a lista completa, esconde o formulário', (tester) async {
      _salvos([
        for (var i = 0; i < 5; i++) TrustedContact(name: 'Pessoa $i', phone: '554199999000$i'),
      ]);
      await _abrir(tester);

      expect(find.textContaining('Sua lista está completa'), findsOneWidget);
      expect(find.text('Adicionar à lista'), findsNothing);
      expect(find.text('Escolher da agenda'), findsNothing);
    });

    testWidgets('não adiciona número repetido', (tester) async {
      _salvos(const [TrustedContact(name: 'Ana', phone: '5541999998888')]);
      await _abrir(tester);

      await tester.enterText(find.widgetWithText(TextFormField, 'Nome da pessoa'), 'Outra');
      await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), '41999998888');
      await _tocar(tester, find.text('Adicionar à lista'));

      expect(find.text('Esse número já está na sua lista.'), findsOneWidget);
      expect(find.text('Cadastradas (1 de 5)'), findsOneWidget);
    });

    testWidgets('preenche o formulário com o contato escolhido na agenda', (tester) async {
      _simularAgenda({
        'fullName': 'Joana Souza',
        'phoneNumbers': ['+55 41 98888-7777'],
        'selectedPhoneNumber': '+55 41 98888-7777',
      });
      await _abrir(tester);
      await _tocar(tester, find.text('Escolher da agenda'));

      expect(find.widgetWithText(TextFormField, 'Joana Souza'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '(41) 98888-7777'), findsOneWidget);
      // Só entra na lista depois que a usuária confirma.
      expect(find.textContaining('Cadastradas'), findsNothing);
    });

    testWidgets('avisa quando o número da agenda não é brasileiro', (tester) async {
      _simularAgenda({'fullName': 'John', 'selectedPhoneNumber': '+44 20 7946 0958'});
      await _abrir(tester);
      await _tocar(tester, find.text('Escolher da agenda'));

      expect(find.text('Esse número não parece um telefone brasileiro com DDD.'), findsOneWidget);
    });

    testWidgets('se ela cancelar a agenda, nada muda', (tester) async {
      _simularAgenda(null);
      await _abrir(tester);
      await _tocar(tester, find.text('Escolher da agenda'));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Joana Souza'), findsNothing);
    });
  });
}
