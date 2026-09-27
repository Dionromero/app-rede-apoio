import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/core/widgets/category_tabs.dart';
import 'package:rede_apoio/core/widgets/simple_markdown.dart';
import 'package:rede_apoio/features/guidance/presentation/pages/guidance_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('SimpleMarkdown.parse', () {
    test('reconhece títulos, listas, citações e parágrafos', () {
      final blocos = SimpleMarkdown.parse('''
# Título
## Seção
### Sub

Linha um
linha dois.

- item **forte**
1. primeiro
2. segundo
> Atenção: ligue 190.
''');
      expect(blocos.map((b) => b.tipo).toList(), [
        MdTipo.titulo1,
        MdTipo.titulo2,
        MdTipo.titulo3,
        MdTipo.paragrafo,
        MdTipo.itemLista,
        MdTipo.itemNumerado,
        MdTipo.itemNumerado,
        MdTipo.citacao,
      ]);
      expect(blocos[3].texto, 'Linha um linha dois.');
      expect(blocos[6].numero, 2);
      expect(blocos[7].texto, 'Atenção: ligue 190.');
    });

    test('negrito vira span separado', () {
      final spans = SimpleMarkdown.negritoSpans('Ligue **190** agora');
      expect(spans.map((s) => s.text), ['Ligue ', '190', ' agora']);
      expect(spans[1].style?.fontWeight, FontWeight.w800);
    });
  });

  group('GuidancePage', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    testWidgets('sem servidor, lista os guias embutidos e abre um guia', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GuidancePage()));
      await tester.pumpAndSettle();

      expect(find.text('Direitos e orientações'), findsOneWidget);
      expect(find.textContaining('Sem conexão'), findsOneWidget);
      expect(find.textContaining('Conteúdo em revisão'), findsOneWidget);
      expect(find.text('Em caso de emergência'), findsOneWidget);

      await tester.tap(find.text('Em caso de emergência'));
      await tester.pumpAndSettle();

      expect(find.text('Risco imediato? Ligue 190.'), findsOneWidget);
      // O aviso de revisão fica no fim do texto: rolar até ele.
      final aviso = find.textContaining('Aguardando revisão');
      await tester.scrollUntilVisible(aviso, 300, scrollable: find.byType(Scrollable).last);
      expect(aviso, findsOneWidget);
      expect(find.text('Emergência 190'), findsOneWidget);
    });

    testWidgets('filtra por tema', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: GuidancePage()));
      await tester.pumpAndSettle();

      await tester.tap(find.descendant(of: find.byType(CategoryTabs), matching: find.text('Segurança')));
      await tester.pumpAndSettle();

      expect(find.text('Plano de segurança'), findsOneWidget);
      expect(find.text('Em caso de emergência'), findsNothing);
    });
  });
}
