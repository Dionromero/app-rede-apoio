import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rede_apoio/features/home/presentation/widgets/filtros_mapa.dart';
import 'package:rede_apoio/features/support_network/domain/models/support_institution.dart';

SupportInstitution inst(String id, String categoria, double lat, double lng, {bool h24 = false}) =>
    SupportInstitution(
      id: id,
      name: 'Local $id',
      category: categoria,
      address: 'Rua $id',
      city: 'Curitiba',
      state: 'PR',
      latitude: lat,
      longitude: lng,
      openingHours: h24 ? const {'seg': '24h', 'dom': '24h'} : null,
    );

Position posicao(double lat, double lng) => Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime(2026),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );

void main() {
  // Centro de Curitiba e locais a distâncias crescentes para o norte.
  final todas = [
    inst('longe', 'creas', -25.30, -49.27),
    inst('perto', 'delegacia_mulher', -25.428, -49.273),
    inst('medio', 'upa', -25.40, -49.27, h24: true),
    inst('medio2', 'cras', -25.38, -49.27),
  ];
  final centro = posicao(-25.4284, -49.2733);

  test('"Mais próximos" ordena por distância e limita a quantidade', () {
    final r = const FiltroMapa(quantidade: 2).aplicar(todas, posicao: centro);
    expect(r.map((i) => i.id), ['perto', 'medio']);
  });

  test('sem posição, "Mais próximos" não corta a lista', () {
    expect(const FiltroMapa(quantidade: 2).aplicar(todas), hasLength(4));
  });

  test('filtra por tipo de atendimento e por 24 horas', () {
    final acolhimento = const FiltroMapa(categoria: 'acolhimento', soProximos: false).aplicar(todas);
    expect(acolhimento.map((i) => i.id).toSet(), {'longe', 'medio2'});
    final h24 = const FiltroMapa(so24h: true, soProximos: false).aplicar(todas);
    expect(h24.map((i) => i.id), ['medio']);
  });

  test('conta filtros extras ativos', () {
    expect(const FiltroMapa().extrasAtivos, 0);
    expect(const FiltroMapa(categoria: 'saude', so24h: true).extrasAtivos, 2);
  });

  testWidgets('folha de filtros devolve a escolha', (tester) async {
    FiltroMapa? escolhido;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => escolhido = await mostrarFolhaFiltros(context, const FiltroMapa()),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Saúde'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ver no mapa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver no mapa'));
    await tester.pumpAndSettle();

    expect(escolhido?.categoria, 'saude');
  });
}
