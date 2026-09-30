import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/features/home/presentation/widgets/enviar_localizacao_sheet.dart';
import 'package:rede_apoio/features/trusted_contact/domain/trusted_contact.dart';

void main() {
  const mae = TrustedContact(name: 'Mãe', phone: '5541999998888');
  const irma = TrustedContact(name: 'Irmã', phone: '5541988887777');

  Future<DestinoLocalizacao?> abrirETocar(WidgetTester tester, String texto) async {
    DestinoLocalizacao? escolha;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => escolha = await escolherDestinoLocalizacao(context, const [mae, irma]),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(texto));
    await tester.pumpAndSettle();
    return escolha;
  }

  testWidgets('lista as pessoas de confiança e devolve a escolhida', (tester) async {
    final escolha = await abrirETocar(tester, 'Irmã');
    expect(escolha, isA<ParaContato>().having((d) => d.contato.name, 'nome', 'Irmã'));
  });

  testWidgets('oferece avisar todas por SMS', (tester) async {
    final escolha = await abrirETocar(tester, 'Avisar todas as pessoas (2)');
    expect(escolha, isA<ParaTodosPorSms>().having((d) => d.contatos.length, 'quantidade', 2));
  });
}
