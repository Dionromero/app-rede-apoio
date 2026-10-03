import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/config/supabase_config.dart';
import '../domain/models/route_plan.dart';

/// Erro de rota com mensagem pronta para a usuária.
class RouteException implements Exception {
  const RouteException(this.codigo, this.mensagem);

  /// 'offline' | 'rotas_indisponiveis' | 'limite_do_servico' | 'muitas_requisicoes'
  /// | 'rota_nao_encontrada' | 'distancia_excedida' | 'desconhecido' | 'onibus_sem_chave' ...
  final String codigo;
  final String mensagem;

  @override
  String toString() => 'RouteException($codigo): $mensagem';
}

/// Calcula rotas dentro do app pela Edge Function `route` do Supabase
/// (para rotas a pé e de carro) ou via Google Directions API (para transporte público / ônibus).
class RouteService {
  const RouteService._();

  /// Guarda as rotas já calculadas nesta sessão (evita repetir chamadas).
  static final Map<String, RoutePlan> _cache = {};

  static String _chave(LatLng de, LatLng para, TravelMode modo) =>
      '${de.latitude.toStringAsFixed(4)},${de.longitude.toStringAsFixed(4)}'
      '>${para.latitude.toStringAsFixed(5)},${para.longitude.toStringAsFixed(5)}:${modo.api}';

  static Future<RoutePlan> calcular({
    required LatLng de,
    required LatLng para,
    required TravelMode modo,
    http.Client? httpClient,
  }) async {
    final chave = _chave(de, para, modo);
    final guardada = _cache[chave];
    if (guardada != null) return guardada;

    // Transporte público (Ônibus / Linhas da URBS de Curitiba)
    if (modo == TravelMode.onibus) {
      if (!AppConfig.temGoogleMapsApiKey) {
        throw const RouteException(
          'onibus_sem_chave',
          'Para ver as linhas de ônibus e horários em tempo real, use "Abrir no GPS do celular".',
        );
      }
      final planoTransit = await _calcularGoogleTransit(de, para, httpClient: httpClient);
      _cache[chave] = planoTransit;
      return planoTransit;
    }

    final client = SupabaseConfig.client;
    if (client == null) {
      throw const RouteException('offline', 'Sem conexão para calcular a rota. Use "Abrir no GPS".');
    }

    try {
      final resposta = await client.functions.invoke(
        'route',
        body: {
          'de': {'lat': de.latitude, 'lng': de.longitude},
          'para': {'lat': para.latitude, 'lng': para.longitude},
          'modo': modo.api,
        },
      ).timeout(const Duration(seconds: 15));

      final dados = resposta.data;
      if (dados is! Map) {
        throw const RouteException('desconhecido', 'Resposta inesperada do serviço de rotas.');
      }
      final plano = RoutePlan.fromJson(Map<String, dynamic>.from(dados));
      if (plano.pontos.length < 2) {
        throw const RouteException('rota_nao_encontrada', 'Não encontramos um caminho até este local.');
      }
      _cache[chave] = plano;
      return plano;
    } on RouteException {
      rethrow;
    } on FunctionException catch (e) {
      throw traduzirErro(e.status, e.details);
    } catch (e) {
      debugPrint('Falha ao calcular rota: $e');
      throw const RouteException('offline', 'Não foi possível calcular a rota agora. Use "Abrir no GPS".');
    }
  }

  /// Consulta a Google Directions API com mode=transit para ônibus e trens.
  static Future<RoutePlan> _calcularGoogleTransit(
    LatLng de,
    LatLng para, {
    http.Client? httpClient,
  }) async {
    const key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) {
      throw const RouteException(
        'onibus_sem_chave',
        'Para consultar linhas de ônibus em tempo real, use "Abrir no GPS do celular".',
      );
    }

    final client = httpClient ?? http.Client();
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        {
          'origin': '${de.latitude},${de.longitude}',
          'destination': '${para.latitude},${para.longitude}',
          'mode': 'transit',
          'language': 'pt-BR',
          'key': key,
        },
      );

      final res = await client.get(uri).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) {
        throw const RouteException('offline', 'Não foi possível buscar as linhas de ônibus agora. Use "Abrir no GPS".');
      }

      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map) {
        throw const RouteException('desconhecido', 'Resposta inesperada do serviço de rotas.');
      }

      final status = json['status']?.toString();
      if (status == 'ZERO_RESULTS') {
        throw const RouteException(
          'rota_nao_encontrada',
          'Nenhuma linha de transporte público direta encontrada para este trajeto.',
        );
      }
      if (status != 'OK') {
        throw const RouteException('desconhecido', 'Não foi possível calcular a rota de ônibus.');
      }

      final routes = json['routes'] as List? ?? [];
      if (routes.isEmpty) {
        throw const RouteException('rota_nao_encontrada', 'Nenhuma rota encontrada.');
      }

      final primeiraRota = routes.first as Map<String, dynamic>;
      final overviewPolyline = primeiraRota['overview_polyline']?['points'] as String? ?? '';
      final pontos = decodificarPolyline(overviewPolyline);

      final legs = primeiraRota['legs'] as List? ?? [];
      final primeiraPerna = legs.isNotEmpty ? (legs.first as Map<String, dynamic>) : <String, dynamic>{};
      final distanciaM = (primeiraPerna['distance']?['value'] as num?)?.round() ?? 0;
      final duracaoS = (primeiraPerna['duration']?['value'] as num?)?.round() ?? 0;

      final rawSteps = primeiraPerna['steps'] as List? ?? [];
      final passos = <RouteStep>[];

      for (final s in rawSteps) {
        if (s is! Map) continue;
        final modoStep = s['travel_mode']?.toString();
        final rawInstrucao = s['html_instructions']?.toString() ?? '';
        final instrucaoLimpa = _removerHtml(rawInstrucao);
        final stepDistM = (s['distance']?['value'] as num?)?.round() ?? 0;
        final stepDurS = (s['duration']?['value'] as num?)?.round() ?? 0;

        if (modoStep == 'TRANSIT') {
          final transit = s['transit_details'] as Map<String, dynamic>?;
          final line = transit?['line'] as Map<String, dynamic>?;
          final shortName = line?['short_name'] as String?;
          final lineName = line?['name'] as String?;
          final linhaCompleta = shortName != null && lineName != null
              ? '$shortName ($lineName)'
              : (shortName ?? lineName ?? 'Ônibus');

          final depStop = transit?['departure_stop']?['name'] as String?;
          final arrStop = transit?['arrival_stop']?['name'] as String?;
          final numStops = (transit?['num_stops'] as num?)?.round();

          passos.add(RouteStep(
            instrucao: 'Pegue o ônibus $linhaCompleta${depStop != null ? ' em $depStop' : ''}',
            distanciaM: stepDistM,
            duracaoS: stepDurS,
            linhaTransit: linhaCompleta,
            pontoEmbarque: depStop,
            pontoDesembarque: arrStop,
            numParadas: numStops,
            isTransit: true,
          ));
        } else {
          passos.add(RouteStep(
            instrucao: instrucaoLimpa.isNotEmpty ? instrucaoLimpa : 'Caminhe até o destino',
            distanciaM: stepDistM,
            duracaoS: stepDurS,
            isTransit: false,
          ));
        }
      }

      return RoutePlan(
        modo: TravelMode.onibus,
        distanciaM: distanciaM,
        duracaoS: duracaoS,
        pontos: pontos.isNotEmpty ? pontos : [de, para],
        passos: passos,
        atribuicao: 'Dados do transporte público: Google Directions · URBS Curitiba',
      );
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// Decodifica polylines comprimidas retornadas pela Google Directions API.
  static List<LatLng> decodificarPolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return points;
  }

  static String _removerHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Converte o erro da função em mensagem para a usuária.
  @visibleForTesting
  static RouteException traduzirErro(int status, dynamic detalhes) {
    if (detalhes is Map && detalhes['mensagem'] is String) {
      return RouteException(detalhes['erro']?.toString() ?? 'desconhecido', detalhes['mensagem'] as String);
    }
    if (status == 404) {
      return const RouteException('rotas_indisponiveis', 'O cálculo de rotas ainda não foi publicado. Use "Abrir no GPS".');
    }
    if (status == 429) {
      return const RouteException('limite_do_servico', 'Muitas rotas agora. Use "Abrir no GPS".');
    }
    return const RouteException('desconhecido', 'Não foi possível calcular a rota agora. Use "Abrir no GPS".');
  }

  @visibleForTesting
  static void limparCache() => _cache.clear();
}
