import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/core/services/discreet_mode_service.dart';
import 'package:rede_apoio/features/discreet_mode/presentation/pages/discreet_mode_page.dart';

void main() {
  const canal = MethodChannel('rede_apoio/modo_discreto');
  var atalho = 'AtalhoPadrao';

  setUp(() {
    atalho = 'AtalhoPadrao';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, (call) async {
      if (call.method == 'atual') return atalho;
      if (call.method == 'definir') {
        atalho = (call.arguments as Map)['atalho'] as String;
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, null);
  });

  test('todos os disfarces têm atalho, nome e imagem únicos', () {
    const todos = DiscreetModeService.todos;
    expect(todos.map((d) => d.atalho).toSet(), hasLength(todos.length));
    expect(todos.map((d) => d.nome).toSet(), hasLength(todos.length));
    expect(DiscreetModeService.porAtalho('desconhecido').ehPadrao, isTrue);
  });

  testWidgets('troca para a calculadora e volta ao ícone original', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DiscreetModePage()));
    await tester.pumpAndSettle();

    for (final d in DiscreetModeService.disfarces) {
      expect(find.text(d.nome), findsOneWidget);
    }

    await tester.tap(find.text('Calculadora'));
    await tester.pumpAndSettle();
    expect(atalho, 'AtalhoCalculadora');
    // Espera o aviso (SnackBar) sumir para não cobrir as opções.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // O ícone original fica no fim da lista, fora da tela no teste:
    // rolar a lista principal (a primeira Scrollable) até ele.
    final original = find.text('Sussurro');
    await tester.scrollUntilVisible(original, 300, scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(original);
    await tester.pumpAndSettle();
    expect(atalho, 'AtalhoPadrao');
  });
}
