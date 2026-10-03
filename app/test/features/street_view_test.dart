import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rede_apoio/features/support_network/data/street_view_service.dart';
import 'package:rede_apoio/features/support_network/domain/models/support_institution.dart';
import 'package:rede_apoio/features/support_network/presentation/widgets/street_view_card.dart';

void main() {
  const instituicaoExata = SupportInstitution(
    id: '1',
    name: 'Casa da Mulher Brasileira',
    category: 'centro_referencia',
    address: 'Av. Paraná, 870',
    city: 'Curitiba',
    state: 'PR',
    latitude: -25.4047,
    longitude: -49.2502,
    locationPrecision: 'exata',
  );

  const instituicaoAproximada = SupportInstitution(
    id: '2',
    name: 'Hospital Pequeno Príncipe',
    category: 'hospital',
    address: 'Rua Desembargador Motta, 1070',
    city: 'Curitiba',
    state: 'PR',
    latitude: -25.4412,
    longitude: -49.2789,
    locationPrecision: 'aproximada',
  );

  group('StreetViewService', () {
    test('monta a URL universal de panorama 360° sem precisar de chave', () {
      final url = StreetViewService.urlPanorama360(
        latitude: -25.4284,
        longitude: -49.2733,
      );

      expect(url, contains('https://www.google.com/maps/@?api=1&map_action=pano'));
      expect(url, contains('viewpoint=-25.428400,-49.273300'));
    });

    test('sem chave de API configurada, urlImagemEstatica retorna null', () {
      final url = StreetViewService.urlImagemEstatica(
        latitude: -25.4284,
        longitude: -49.2733,
        chaveApi: '',
      );

      expect(url, isNull);
    });

    test('com chave fornecida, monta a URL da Google Static Street View API', () {
      final url = StreetViewService.urlImagemEstatica(
        latitude: -25.4284,
        longitude: -49.2733,
        chaveApi: 'CHAVE_TESTE_GOOGLE',
        largura: 600,
        altura: 300,
      );

      expect(url, isNotNull);
      expect(url, startsWith('https://maps.googleapis.com/maps/api/streetview'));
      expect(url, contains('location=-25.428400,-49.273300'));
      expect(url, contains('key=CHAVE_TESTE_GOOGLE'));
      expect(url, contains('size=600x300'));
    });
  });

  group('StreetViewCard Widget', () {
    testWidgets('sem chave de API, exibe card informativo com botão de visão 360°', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreetViewCard(
              instituicao: instituicaoExata,
              chaveApiOverride: '',
            ),
          ),
        ),
      );

      expect(find.text('Reconhecer fachada no Street View'), findsOneWidget);
      expect(find.textContaining('Veja a entrada e a rua em 360°'), findsOneWidget);
      expect(find.byIcon(Icons.streetview_rounded), findsOneWidget);
    });

    testWidgets('quando coordenada é aproximada, avisa no card', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreetViewCard(
              instituicao: instituicaoAproximada,
              chaveApiOverride: '',
            ),
          ),
        ),
      );

      expect(find.textContaining('Ponto aproximado: procure pela placa'), findsOneWidget);
    });
  });
}
