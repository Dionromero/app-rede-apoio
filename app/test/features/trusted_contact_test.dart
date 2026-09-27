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

/// Abre a tela como no onboarding (sem tela anterior) ou [pelaHome].
Future<void> _abrir(WidgetTester tester, {bool pelaHome = false}) async {
  // Tela alta: o ListView só constrói o que cabe na tela, e a padrão (800x600) é baixa.
  tester.view.physicalSize = const Size(440, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  Widget pagina() => TrustedContactPage(repository: TrustedContactRepository());
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    home: pelaHome
        ? Builder(
            builder: (context) => Scaffold(
              body: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => pagina())),
                child: const Text('Abrir pela Home'),
              ),
            ),
          )
        : pagina(),
  ));
  if (pelaHome) await tester.tap(find.text('Abrir pela Home'));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder alvo) async {
  await tester.ensureVisible(alvo);
  await tester.tap(alvo);
  await tester.pumpAndSettle();
}

/// Abre o painel "Digitar número", preenche e toca em "Adicionar".
Future<void> _digitar(WidgetTester tester, String nome, String telefone) async {
  await _tocar(tester, find.text('Digitar número'));
  await tester.enterText(find.widgetWithText(TextFormField, 'Nome da pessoa'), nome);
  await tester.enterText(find.widgetWithText(TextFormField, 'Telefone'), telefone);
  await _tocar(tester, find.text('Adicionar'));
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
    testWidgets('lista vazia orienta e permite pular no onboarding', (tester) async {
      await _abrir(tester);

      expect(find.text('Ninguém na lista ainda'), findsOneWidget);
      expect(find.text('Passo 1 de 2'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back_rounded), findsNothing);
      expect(find.text('Pular por agora'), findsOneWidget);
    });

    testWidgets('adiciona uma pessoa digitada e mostra na lista', (tester) async {
      await _abrir(tester);
      await _digitar(tester, 'maria silva', '41999998888');

      expect(find.text('Nova pessoa de confiança'), findsNothing);
      expect(find.text('Maria silva'), findsOneWidget);
      expect(find.text('(41) 99999-8888'), findsOneWidget);
      expect(find.text('1 de 5'), findsOneWidget);
      expect(find.text('Maria silva está na sua lista. Nada foi enviado.'), findsOneWidget);
      expect(find.text('Continuar'), findsOneWidget);
    });

    testWidgets('nome não aceita números e para em 30 caracteres', (tester) async {
      await _abrir(tester);
      await _tocar(tester, find.text('Digitar número'));
      final campoNome = find.widgetWithText(TextFormField, 'Nome da pessoa');

      await tester.enterText(campoNome, 'ana2');
      expect(find.text('Ana'), findsOneWidget);

      await tester.enterText(campoNome, 'b' * 40);
      await tester.pump(); // redesenha a tela para o contador atualizar
      expect(find.text('B${'b' * 29}'), findsOneWidget);
      expect(find.text('30/30'), findsOneWidget);
    });

    testWidgets('nome vindo da agenda chega sem números e com até 30 caracteres', (tester) async {
      _simularAgenda({
        'fullName': 'João   Trabalho 2 ${'x' * 40}',
        'selectedPhoneNumber': '(41) 98888-7777',
      });
      await _abrir(tester);
      await _tocar(tester, find.text('Escolher da agenda'));

      // Sem o "2", espaços repetidos viram um só, e corta em 30 caracteres.
      expect(find.text('João Trabalho ${'x' * 16}'), findsOneWidget);
    });

    testWidgets('número repetido: o erro aparece no painel, que continua aberto', (tester) async {
      _salvos(const [TrustedContact(name: 'Ana', phone: '5541999998888')]);
      await _abrir(tester);
      await _digitar(tester, 'Outra', '41999998888');

      expect(find.text('Nova pessoa de confiança'), findsOneWidget);
      expect(find.text('Esse número já está na sua lista.'), findsOneWidget);
      expect(find.text('1 de 5'), findsOneWidget);
    });

    testWidgets('mostra as pessoas salvas e remove com confirmação', (tester) async {
      _salvos(const [
        TrustedContact(name: 'Ana', phone: '5541999998888'),
        TrustedContact(name: 'Bia', phone: '5541988887777'),
      ]);
      await _abrir(tester);
      expect(find.text('2 de 5'), findsOneWidget);

      await _tocar(tester, find.byTooltip('Remover Ana'));
      expect(find.text('Remover Ana?'), findsOneWidget);
      await _tocar(tester, find.widgetWithText(FilledButton, 'Remover'));

      expect(find.text('Ana'), findsNothing);
      expect(find.text('1 de 5'), findsOneWidget);
    });

    testWidgets('com a lista completa, esconde os botões de adicionar', (tester) async {
      _salvos([
        for (var i = 0; i < 5; i++) TrustedContact(name: 'Pessoa $i', phone: '554199999000$i'),
      ]);
      await _abrir(tester);

      expect(find.textContaining('Sua lista está completa'), findsOneWidget);
      expect(find.text('Digitar número'), findsNothing);
      expect(find.text('Escolher da agenda'), findsNothing);
    });

    testWidgets('contato da agenda abre o painel já preenchido', (tester) async {
      _simularAgenda({
        'fullName': 'Joana Souza',
        'phoneNumbers': ['+55 41 98888-7777'],
        'selectedPhoneNumber': '+55 41 98888-7777',
      });
      await _abrir(tester);
      await _tocar(tester, find.text('Escolher da agenda'));

      expect(find.textContaining('Confira os dados'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Joana Souza'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '(41) 98888-7777'), findsOneWidget);
      // Só entra na lista depois que a usuária confirma.
      expect(find.text('1 de 5'), findsNothing);

      await _tocar(tester, find.text('Adicionar'));
      expect(find.text('Joana Souza'), findsOneWidget);
      expect(find.text('1 de 5'), findsOneWidget);
    });

    testWidgets('avisa quando o número da agenda não é brasileiro', (tester) async {
      _simularAgenda({'fullName': 'John', 'selectedPhoneNumber': '+44 20 7946 0958'});
      await _abrir(tester);
      await _tocar(tester, find.text('Escolher da agenda'));

      expect(find.text('Esse número não parece um telefone brasileiro com DDD.'), findsOneWidget);
      expect(find.text('Nova pessoa de confiança'), findsNothing);
    });

    testWidgets('se ela cancelar a agenda, nada muda', (tester) async {
      _simularAgenda(null);
      await _abrir(tester);
      await _tocar(tester, find.text('Escolher da agenda'));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Nova pessoa de confiança'), findsNothing);
    });

    testWidgets('aberta pela Home: botão voltar, sem progresso', (tester) async {
      await _abrir(tester, pelaHome: true);

      expect(find.text('Passo 1 de 2'), findsNothing);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

      await _tocar(tester, find.text('Voltar'));
      expect(find.text('Abrir pela Home'), findsOneWidget);
    });
  });
}
