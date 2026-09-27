import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/features/discreet_mode/presentation/pages/discreet_mode_page.dart';

void main() {
  const canal = MethodChannel('rede_apoio/modo_discreto');
  final chamadas = <MethodCall>[];
  var ativo = false;

  setUp(() {
    chamadas.clear();
    ativo = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, (call) async {
      chamadas.add(call);
      if (call.method == 'ativo') return ativo;
      if (call.method == 'definir') {
        ativo = (call.arguments as Map)['ativo'] as bool;
        return true;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(canal, null);
  });

  testWidgets('troca para o ícone disfarçado e volta', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: DiscreetModePage()));
    await tester.pumpAndSettle();

    expect(find.text('Anotações'), findsOneWidget);
    expect(find.text('Em uso'), findsOneWidget); // ícone padrão selecionado

    await tester.tap(find.text('Anotações'));
    await tester.pumpAndSettle();
    expect(ativo, isTrue);
    expect(chamadas.last.method, 'definir');

    await tester.tap(find.text('Rede de Apoio'));
    await tester.pumpAndSettle();
    expect(ativo, isFalse);
  });
}
