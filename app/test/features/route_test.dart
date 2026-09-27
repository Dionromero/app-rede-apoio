import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:rede_apoio/core/widgets/category_tabs.dart';
import 'package:rede_apoio/core/widgets/pressable.dart';
import 'package:rede_apoio/features/support_network/data/route_service.dart';
import 'package:rede_apoio/features/support_network/domain/models/route_plan.dart';

void main() {
  group('RoutePlan', () {
    final json = {
      'modo': 'a_pe',
      'distancia_m': 3457,
      'duracao_s': 2489,
      'geometria': [
        [-25.4284, -49.2733],
        [-25.415, -49.26],
        [-25.40468353, -49.25013167],
      ],
      'passos': [
        {'instrucao': 'Siga para o norte', 'distancia_m': 120, 'duracao_s': 86, 'via': 'Rua XV'},
        {'instrucao': '', 'distancia_m': 0, 'duracao_s': 0, 'via': null},
      ],
      'atribuicao': '© openrouteservice.org',
    };

    test('lê a resposta da função route', () {
      final r = RoutePlan.fromJson(json);
      expect(r.modo, TravelMode.aPe);
      expect(r.pontos, hasLength(3));
      expect(r.pontos.first.latitude, -25.4284);
      expect(r.pontos.first.longitude, -49.2733);
      expect(r.passos, hasLength(1), reason: 'passos sem instrução são descartados');
      expect(r.passos.first.via, 'Rua XV');
    });

    test('formata duração e distância em português', () {
      expect(RoutePlan.formatarDuracao(20), 'menos de 1 min');
      expect(RoutePlan.formatarDuracao(2489), '41 min');
      expect(RoutePlan.formatarDuracao(3900), '1 h 05 min');
      expect(RoutePlan.formatarDuracao(7200), '2 h');
      expect(RoutePlan.formatarDistancia(448), '450 m');
      expect(RoutePlan.formatarDistancia(3457), '3,5 km');
      expect(RoutePlan.formatarDistancia(12400), '12 km');
    });

    test('calcula o horário de chegada', () {
      final r = RoutePlan.fromJson(json);
      expect(r.chegadaPrevista(DateTime(2026, 9, 27, 14, 0)), '14:41');
    });

    test('modo de transporte converte para a API e para o Google Maps', () {
      expect(TravelMode.fromApi('carro'), TravelMode.carro);
      expect(TravelMode.fromApi('outro'), TravelMode.aPe);
      expect(TravelMode.carro.googleMaps, 'driving');
      expect(TravelMode.aPe.googleMaps, 'walking');
    });
  });

  group('RouteService.traduzirErro', () {
    test('usa a mensagem enviada pela função', () {
      final e = RouteService.traduzirErro(429, {'erro': 'limite_do_servico', 'mensagem': 'Limite atingido.'});
      expect(e.codigo, 'limite_do_servico');
      expect(e.mensagem, 'Limite atingido.');
    });

    test('função não publicada (404) orienta a usar o GPS', () {
      final e = RouteService.traduzirErro(404, null);
      expect(e.codigo, 'rotas_indisponiveis');
      expect(e.mensagem, contains('GPS'));
    });

    test('sem Supabase, calcular falha com mensagem amigável', () async {
      RouteService.limparCache();
      await expectLater(
        RouteService.calcular(
          de: const LatLng(-25.43, -49.27),
          para: const LatLng(-25.40, -49.25),
          modo: TravelMode.aPe,
        ),
        throwsA(isA<RouteException>().having((e) => e.codigo, 'codigo', 'offline')),
      );
    });
  });

  group('Componentes', () {
    testWidgets('CategoryTabs troca a aba selecionada', (tester) async {
      var selecionado = 'todos';
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => CategoryTabs(
              itens: const [('todos', 'Todos'), ('saude', 'Saúde')],
              selecionado: selecionado,
              onSelecionar: (id) => setState(() => selecionado = id),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Saúde'));
      await tester.pumpAndSettle();
      expect(selecionado, 'saude');
    });

    testWidgets('Pressable chama onTap e ignora quando desativado', (tester) async {
      var toques = 0;
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            Pressable(onTap: () => toques++, child: const Text('ativo')),
            const Pressable(onTap: null, child: Text('inativo')),
          ],
        ),
      ));
      await tester.tap(find.text('ativo'));
      await tester.tap(find.text('inativo'));
      await tester.pumpAndSettle();
      expect(toques, 1);
    });
  });
}
