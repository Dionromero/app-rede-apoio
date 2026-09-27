import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/supabase_config.dart';
import '../../../../core/utils/text_normalizer.dart';
import '../domain/models/support_institution.dart';

/// Resultado de uma busca na rede de apoio.
class ResultadoBusca {
  const ResultadoBusca({
    required this.instituicoes,
    required this.offline,
    this.foraDoRaio = false,
  });

  final List<SupportInstitution> instituicoes;

  /// `true` quando não havia nada dentro do raio pedido e a lista mostra
  /// os locais mais próximos, mesmo mais distantes.
  final bool foraDoRaio;

  /// `true` quando os dados vieram da lista local de contingência
  /// (sem internet, Supabase indisponível ou erro na consulta).
  final bool offline;
}

/// Serviço de busca de pontos de apoio (Supabase) e ações de contato.
///
/// A busca acontece no servidor (RPC `search_institutions`), sobre a base
/// curada. Se não houver conexão, usa uma lista local mínima e verificada,
/// aplicando as mesmas regras de filtro (regras de segurança 1 e 5 do README).
class SupportNetworkService {
  const SupportNetworkService._();

  /// Cidade-piloto atual. Usada apenas para textos da interface; a busca
  /// não filtra por cidade para que a expansão não exija mudança no app.
  static const cidadePiloto = 'Curitiba';

  /// O mapa mostra todos os locais do raio (a base tem ~90 em Curitiba).
  static const _maxResultados = 150;

  /// Busca instituições por texto, categorias e proximidade.
  ///
  /// - [texto]: nome, bairro, serviço ou público (sem diferenciar acentos).
  /// - [categorias]: lista de categorias do banco; vazia = todas.
  /// - [lat]/[lng]: quando informados, ordena por distância.
  /// - [raioKm]: com posição, limita aos locais até essa distância. Se não
  ///   houver nenhum, repete sem limite e marca [ResultadoBusca.foraDoRaio].
  static Future<ResultadoBusca> buscarInstituicoes({
    String? texto,
    List<String> categorias = const [],
    double? lat,
    double? lng,
    double? raioKm,
  }) async {
    final comRaio = raioKm != null && lat != null && lng != null;
    final resultado = await _buscar(texto, categorias, lat, lng, comRaio ? raioKm : null);
    if (!comRaio || resultado.instituicoes.isNotEmpty) return resultado;

    final semLimite = await _buscar(texto, categorias, lat, lng, null);
    return ResultadoBusca(
      instituicoes: semLimite.instituicoes,
      offline: semLimite.offline,
      foraDoRaio: semLimite.instituicoes.isNotEmpty,
    );
  }

  static Future<ResultadoBusca> _buscar(
    String? texto,
    List<String> categorias,
    double? lat,
    double? lng,
    double? raioKm,
  ) async {
    final client = SupabaseConfig.client;
    final termo = texto?.trim() ?? '';

    if (client != null) {
      try {
        final response = await client
            .rpc(
              'search_institutions',
              params: {
                'q': termo.isEmpty ? null : termo,
                'lat': lat,
                'lng': lng,
                'filter_categories': categorias.isEmpty ? null : categorias,
                'radius_meters': raioKm == null ? null : (raioKm * 1000).round(),
                'max_results': _maxResultados,
              },
            )
            .timeout(const Duration(seconds: 8));

        if (response is List) {
          final itens = response
              .map((item) => SupportInstitution.fromSupabase(
                    Map<String, dynamic>.from(item as Map),
                  ))
              .toList();
          return ResultadoBusca(instituicoes: itens, offline: false);
        }
      } catch (e) {
        debugPrint('Erro na busca de instituições: $e. Usando contingência local.');
      }
    }

    return ResultadoBusca(
      instituicoes: filtrarLocalmente(
        obterInstituicoesContingencia(),
        texto: termo,
        categorias: categorias,
        lat: lat,
        lng: lng,
      ).where((i) => raioKm == null || i.distanceKm == null || i.distanceKm! <= raioKm).toList(),
      offline: true,
    );
  }

  /// Aplica localmente as mesmas regras da RPC `search_institutions`.
  @visibleForTesting
  static List<SupportInstitution> filtrarLocalmente(
    List<SupportInstitution> lista, {
    String? texto,
    List<String> categorias = const [],
    double? lat,
    double? lng,
  }) {
    final termos = termosDeBusca(texto);
    final filtradas = lista
        .where((i) => categorias.isEmpty || categorias.contains(i.category))
        .where((i) => i.matchesTerms(termos))
        .map((i) => _comDistancia(i, lat, lng))
        .toList();

    filtradas.sort((a, b) {
      final da = a.distanceKm;
      final db = b.distanceKm;
      if (da != null && db != null && da != db) return da.compareTo(db);
      return normalizarTexto(a.name).compareTo(normalizarTexto(b.name));
    });
    return filtradas;
  }

  static SupportInstitution _comDistancia(SupportInstitution i, double? lat, double? lng) {
    if (lat == null || lng == null || i.latitude == null || i.longitude == null) {
      return i;
    }
    return SupportInstitution(
      id: i.id,
      externalKey: i.externalKey,
      name: i.name,
      category: i.category,
      subcategory: i.subcategory,
      address: i.address,
      district: i.district,
      city: i.city,
      state: i.state,
      zipCode: i.zipCode,
      phone: i.phone,
      phone2: i.phone2,
      email: i.email,
      website: i.website,
      openingHours: i.openingHours,
      latitude: i.latitude,
      longitude: i.longitude,
      services: i.services,
      targetAudience: i.targetAudience,
      verifiedAt: i.verifiedAt,
      sourceName: i.sourceName,
      sourceUrl: i.sourceUrl,
      locationPrecision: i.locationPrecision,
      distanceKm: _distanciaKm(lat, lng, i.latitude!, i.longitude!),
    );
  }

  /// Distância em linha reta (fórmula de Haversine), arredondada a 2 casas.
  static double _distanciaKm(double lat1, double lng1, double lat2, double lng2) {
    const raioTerraKm = 6371.0;
    double rad(double g) => g * math.pi / 180;
    final dLat = rad(lat2 - lat1);
    final dLng = rad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.sin(dLng / 2) * math.sin(dLng / 2);
    final km = raioTerraKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return (km * 100).roundToDouble() / 100;
  }

  /// Inicia discagem para o telefone da instituição.
  static Future<bool> ligar(String telefone) async {
    final sanitizado = telefone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitizado);
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Abre o aplicativo de mapas com a rota até a instituição.
  ///
  /// Se a coordenada for aproximada, usa o endereço para não levar a
  /// usuária a um ponto errado.
  static Future<bool> abrirNoMapa(SupportInstitution instituicao) async {
    final Uri uri;
    if (!instituicao.hasApproximateLocation &&
        instituicao.latitude != null &&
        instituicao.longitude != null) {
      uri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&destination=${instituicao.latitude},${instituicao.longitude}',
      );
    } else {
      final destino = Uri.encodeComponent(
        '${instituicao.address}, ${instituicao.city} - ${instituicao.state}',
      );
      uri = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$destino');
    }

    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Abre a página oficial usada como fonte do cadastro.
  static Future<bool> abrirFonte(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// Lista mínima para uso sem internet — piloto Curitiba.
  ///
  /// Contém somente registros conferidos com fonte oficial em 24/09/2026
  /// (espelho de backend/supabase/04_seed_curitiba.sql). Ao alterar a base,
  /// atualize esta lista também.
  static List<SupportInstitution> obterInstituicoesContingencia() {
    final verificadoEm = DateTime.utc(2026, 9, 24);
    const h24 = {
      'seg': '24h', 'ter': '24h', 'qua': '24h', 'qui': '24h',
      'sex': '24h', 'sab': '24h', 'dom': '24h',
    };
    const fontePrefeitura =
        'https://mulhereigualdade.curitiba.pr.gov.br/conteudo/rede-de-atencao-as-mulheres-em-situacao-de-violencias/12';
    const fonteTjpr = 'https://www.tjpr.jus.br/web/cevid/onde-procurar-ajuda';

    return [
      SupportInstitution(
        id: 'cwb-casa-mulher-brasileira',
        externalKey: 'cwb-casa-mulher-brasileira',
        name: 'Casa da Mulher Brasileira de Curitiba',
        category: 'centro_referencia',
        subcategory: 'Centro de Referência de Atendimento à Mulher (CRAM)',
        address: 'Av. Paraná, 870 - Cabral',
        district: 'Cabral',
        city: 'Curitiba',
        state: 'PR',
        zipCode: '80035-130',
        phone: '(41) 3221-2701',
        phone2: '(41) 3221-2710',
        email: 'cmb@curitiba.pr.gov.br',
        openingHours: h24,
        latitude: -25.40468353,
        longitude: -49.25013167,
        services: const [
          'acolhimento', 'atendimento_psicossocial', 'orientacao_juridica',
          'defensoria_publica', 'juizado_violencia_domestica', 'ministerio_publico',
          'patrulha_maria_da_penha', 'alojamento_temporario', 'autonomia_economica',
          'brinquedoteca',
        ],
        targetAudience: 'Mulheres em situação de violência doméstica e familiar',
        verifiedAt: verificadoEm,
        sourceName: 'Prefeitura de Curitiba — Portal Locais',
        sourceUrl:
            'https://locais.curitiba.pr.gov.br/centro-de-referencia-de-atendimento-a-mulher-casa-da-mulher-brasileira/2117',
      ),
      SupportInstitution(
        id: 'cwb-delegacia-mulher',
        externalKey: 'cwb-delegacia-mulher',
        name: 'Delegacia da Mulher de Curitiba',
        category: 'delegacia_mulher',
        subcategory: 'Funciona dentro da Casa da Mulher Brasileira',
        address: 'Av. Paraná, 870 - Cabral',
        district: 'Cabral',
        city: 'Curitiba',
        state: 'PR',
        zipCode: '80035-130',
        phone: '(41) 3221-2742',
        phone2: '(41) 3221-2745',
        openingHours: h24,
        latitude: -25.40468353,
        longitude: -49.25013167,
        services: const [
          'boletim_ocorrencia', 'medida_protetiva', 'violencia_domestica', 'violencia_sexual',
        ],
        targetAudience: 'Mulheres em situação de violência doméstica, familiar e sexual',
        verifiedAt: verificadoEm,
        sourceName: 'Prefeitura de Curitiba — Secretaria da Mulher',
        sourceUrl: fontePrefeitura,
      ),
      SupportInstitution(
        id: 'cwb-hc-ufpr',
        externalKey: 'cwb-hc-ufpr',
        name: 'Complexo Hospital de Clínicas da UFPR',
        category: 'hospital',
        subcategory: 'Referência em violência sexual',
        address: 'Rua General Carneiro, 181 - Alto da Glória',
        district: 'Alto da Glória',
        city: 'Curitiba',
        state: 'PR',
        zipCode: '80060-150',
        phone: '(41) 3360-1800',
        openingHours: h24,
        latitude: -25.42422697,
        longitude: -49.26215085,
        services: const ['atendimento_violencia_sexual', 'urgencia'],
        targetAudience: 'Mulheres a partir de 12 anos, incluindo mulheres trans e travestis',
        verifiedAt: verificadoEm,
        sourceName: 'TJPR — CEVID, Onde procurar ajuda',
        sourceUrl: fonteTjpr,
      ),
      SupportInstitution(
        id: 'cwb-evangelico-mackenzie',
        externalKey: 'cwb-evangelico-mackenzie',
        name: 'Hospital Universitário Evangélico Mackenzie',
        category: 'hospital',
        subcategory: 'Referência em violência sexual',
        address: 'Alameda Augusto Stellfeld, 1908 - Bigorrilho',
        district: 'Bigorrilho',
        city: 'Curitiba',
        state: 'PR',
        zipCode: '80730-150',
        phone: '(41) 3240-5000',
        openingHours: h24,
        latitude: -25.4296,
        longitude: -49.2870,
        locationPrecision: 'aproximada',
        services: const ['atendimento_violencia_sexual', 'urgencia'],
        targetAudience: 'Mulheres a partir de 12 anos',
        verifiedAt: verificadoEm,
        sourceName: 'TJPR — CEVID, Onde procurar ajuda',
        sourceUrl: fonteTjpr,
      ),
      SupportInstitution(
        id: 'cwb-pequeno-principe',
        externalKey: 'cwb-pequeno-principe',
        name: 'Hospital Pequeno Príncipe',
        category: 'hospital',
        subcategory: 'Referência em violência sexual contra crianças',
        address: 'Rua Desembargador Motta, 1070 - Água Verde',
        district: 'Água Verde',
        city: 'Curitiba',
        state: 'PR',
        zipCode: '80250-060',
        phone: '(41) 3310-1010',
        openingHours: h24,
        latitude: -25.4440,
        longitude: -49.2775,
        locationPrecision: 'aproximada',
        services: const ['atendimento_violencia_sexual', 'atendimento_infantil'],
        targetAudience: 'Crianças (até 11 ou 12 anos — as fontes divergem)',
        verifiedAt: verificadoEm,
        sourceName: 'TJPR — CEVID, Onde procurar ajuda',
        sourceUrl: fonteTjpr,
      ),
    ];
  }
}
