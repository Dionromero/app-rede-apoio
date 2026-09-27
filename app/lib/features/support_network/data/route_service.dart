import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/supabase_config.dart';
import '../domain/models/route_plan.dart';

/// Erro de rota com mensagem pronta para a usuária.
class RouteException implements Exception {
  const RouteException(this.codigo, this.mensagem);

  /// 'offline' | 'rotas_indisponiveis' | 'limite_do_servico' | 'muitas_requisicoes'
  /// | 'rota_nao_encontrada' | 'distancia_excedida' | 'desconhecido' ...
  final String codigo;
  final String mensagem;

  @override
  String toString() => 'RouteException($codigo): $mensagem';
}

/// Calcula rotas dentro do app pela Edge Function `route` do Supabase,
/// que consulta o OpenRouteService com a chave guardada no servidor.
///
/// A origem (posição da usuária) não é gravada em lugar nenhum.
/// Se a rota falhar, a interface deve oferecer "Abrir no GPS"
/// (`SupportNetworkService.abrirNoMapa`).
class RouteService {
  const RouteService._();

  /// Guarda as rotas já calculadas nesta sessão (evita repetir chamadas ao
  /// alternar "A pé" / "Carro").
  static final Map<String, RoutePlan> _cache = {};

  static String _chave(LatLng de, LatLng para, TravelMode modo) =>
      '${de.latitude.toStringAsFixed(4)},${de.longitude.toStringAsFixed(4)}'
      '>${para.latitude.toStringAsFixed(5)},${para.longitude.toStringAsFixed(5)}:${modo.api}';

  static Future<RoutePlan> calcular({
    required LatLng de,
    required LatLng para,
    required TravelMode modo,
  }) async {
    final chave = _chave(de, para, modo);
    final guardada = _cache[chave];
    if (guardada != null) return guardada;

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
