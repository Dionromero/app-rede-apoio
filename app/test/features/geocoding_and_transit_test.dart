import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rede_apoio/api.dart';

void main() {
  group('GeocodingService', () {
    setUp(() {
      GeocodingService.limparCache();
    });

    test('obterEndereco formata endereço via fallback Mock HTTP', () async {
      final mockClient = MockClient((request) async {
        if (request.url.host == 'nominatim.openstreetmap.org') {
          return http.Response(
            jsonEncode({
              'display_name': 'Rua Marechal Deodoro, 100, Centro, Curitiba, Paraná, Brasil',
              'address': {
                'road': 'Rua Marechal Deodoro',
                'house_number': '100',
                'suburb': 'Centro',
                'city': 'Curitiba',
                'state': 'Paraná',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final endereco = await GeocodingService.obterEndereco(
        -25.4284,
        -49.2733,
        httpClient: mockClient,
      );

      expect(endereco, isNotNull);
      expect(endereco!.logradouro, 'Rua Marechal Deodoro');
      expect(endereco.numero, '100');
      expect(endereco.bairro, 'Centro');
      expect(endereco.cidade, 'Curitiba');
      expect(endereco.resumo, 'Rua Marechal Deodoro, 100 · Centro · Curitiba');
    });

    test('obterEndereco lida com erro de rede retornando null', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Erro interno', 500);
      });

      final endereco = await GeocodingService.obterEndereco(
        -25.4284,
        -49.2733,
        httpClient: mockClient,
      );

      expect(endereco, isNull);
    });
  });

  group('TravelMode & Transit', () {
    test('TravelMode possui onibus com transit no googleMaps', () {
      expect(TravelMode.onibus.api, 'onibus');
      expect(TravelMode.onibus.rotulo, 'Ônibus');
      expect(TravelMode.onibus.googleMaps, 'transit');
      expect(TravelMode.fromApi('onibus'), TravelMode.onibus);
    });

    test('RouteService.decodificarPolyline converte string codificada em LatLng', () {
      // Polyline simples conhecida: _p~iF~ps|U_ulLnnqC_mqNvxq`@
      const encoded = '_p~iF~ps|U_ulLnnqC_mqNvxq`@';
      final pontos = RouteService.decodificarPolyline(encoded);
      expect(pontos.length, 3);
      expect(pontos[0].latitude, closeTo(38.5, 0.1));
      expect(pontos[0].longitude, closeTo(-120.2, 0.1));
    });

    test('RouteStep cria passo de transporte público com dados da linha', () {
      const step = RouteStep(
        instrucao: 'Pegue o ônibus 203 - Santa Cândida',
        distanciaM: 3500,
        duracaoS: 720,
        linhaTransit: '203 - Santa Cândida',
        pontoEmbarque: 'Tubo Rui Barbosa',
        pontoDesembarque: 'Tubo CIC',
        numParadas: 6,
        isTransit: true,
      );

      expect(step.isTransit, isTrue);
      expect(step.linhaTransit, '203 - Santa Cândida');
      expect(step.numParadas, 6);
      expect(step.pontoEmbarque, 'Tubo Rui Barbosa');
    });
  });
}
