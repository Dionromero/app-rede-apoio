import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';

/// Resultado legível de geocodificação reversa (coordenadas -> endereço).
class EnderecoLegivel {
  const EnderecoLegivel({
    required this.enderecoCompleto,
    this.logradouro,
    this.numero,
    this.bairro,
    this.cidade,
    this.estado,
  });

  /// Endereço completo formatado (ex: "Rua XV de Novembro, 123 - Centro, Curitiba - PR").
  final String enderecoCompleto;

  /// Nome da via (ex: "Rua XV de Novembro").
  final String? logradouro;

  /// Número predial aproximado (ex: "123").
  final String? numero;

  /// Bairro (ex: "Centro").
  final String? bairro;

  /// Cidade (ex: "Curitiba").
  final String? cidade;

  /// Estado (ex: "PR").
  final String? estado;

  /// Resumo curto para cards e mensagens (ex: "Rua XV de Novembro, 123 · Centro, Curitiba").
  String get resumo {
    final partes = <String>[];
    if (logradouro != null) {
      if (numero != null) {
        partes.add('$logradouro, $numero');
      } else {
        partes.add(logradouro!);
      }
    }
    if (bairro != null) {
      partes.add(bairro!);
    }
    if (cidade != null) {
      partes.add(cidade!);
    }
    if (partes.isEmpty) return enderecoCompleto;
    return partes.join(' · ');
  }

  @override
  String toString() => enderecoCompleto;
}

/// Serviço de geocodificação reversa usando Google Geocoding API,
/// com fallback aberto (Nominatim / OSM) quando não há chave configurada.
class GeocodingService {
  const GeocodingService._();

  static final Map<String, EnderecoLegivel> _cache = {};

  static String _chaveCache(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';

  /// Obtém o endereço legível para as coordenadas dadas.
  /// Retorna `null` em caso de erro de conexão ou endereço não encontrado.
  static Future<EnderecoLegivel?> obterEndereco(
    double latitude,
    double longitude, {
    http.Client? httpClient,
  }) async {
    final chave = _chaveCache(latitude, longitude);
    if (_cache.containsKey(chave)) {
      return _cache[chave];
    }

    final client = httpClient ?? http.Client();
    try {
      EnderecoLegivel? resultado;

      // 1. Tentar Google Geocoding API se a chave estiver configurada
      if (AppConfig.temGoogleMapsApiKey) {
        resultado = await _consultarGoogle(latitude, longitude, client);
      }

      // 2. Se não houver chave ou Google falhar, tentar fallback aberto
      resultado ??= await _consultarFallback(latitude, longitude, client);

      if (resultado != null) {
        _cache[chave] = resultado;
      }
      return resultado;
    } catch (e) {
      debugPrint('Erro ao obter endereço para ($latitude, $longitude): $e');
      return null;
    } finally {
      if (httpClient == null) {
        client.close();
      }
    }
  }

  /// Consulta a Google Geocoding API oficial.
  static Future<EnderecoLegivel?> _consultarGoogle(
    double lat,
    double lng,
    http.Client client,
  ) async {
    const key = AppConfig.googleMapsApiKey;
    if (key.isEmpty) return null;

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/geocode/json',
      {
        'latlng': '$lat,$lng',
        'language': 'pt-BR',
        'key': key,
      },
    );

    final res = await client.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return null;

    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map || json['status'] != 'OK') return null;

    final results = json['results'] as List?;
    if (results == null || results.isEmpty) return null;

    final primeiro = results.first as Map<String, dynamic>;
    final enderecoFormatado = primeiro['formatted_address'] as String? ?? '';
    final components = primeiro['address_components'] as List? ?? [];

    String? logradouro;
    String? numero;
    String? bairro;
    String? cidade;
    String? estado;

    for (final c in components) {
      if (c is! Map) continue;
      final types = List<String>.from(c['types'] as List? ?? []);
      final longName = c['long_name'] as String?;
      final shortName = c['short_name'] as String?;

      if (types.contains('route')) {
        logradouro = longName;
      } else if (types.contains('street_number')) {
        numero = longName;
      } else if (types.contains('sublocality_level_1') || types.contains('sublocality')) {
        bairro = longName;
      } else if (types.contains('administrative_area_level_2')) {
        cidade = longName;
      } else if (types.contains('administrative_area_level_1')) {
        estado = shortName;
      }
    }

    return EnderecoLegivel(
      enderecoCompleto: enderecoFormatado,
      logradouro: logradouro,
      numero: numero,
      bairro: bairro,
      cidade: cidade,
      estado: estado,
    );
  }

  /// Fallback aberto (OpenStreetMap Nominatim) para rodar mesmo sem chave de API.
  static Future<EnderecoLegivel?> _consultarFallback(
    double lat,
    double lng,
    http.Client client,
  ) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      {
        'format': 'json',
        'lat': '$lat',
        'lon': '$lng',
        'zoom': '18',
        'addressdetails': '1',
      },
    );

    final res = await client.get(
      uri,
      headers: {'User-Agent': 'SussurroApp/1.0 (apoio.mulher.curitiba)'},
    ).timeout(const Duration(seconds: 8));

    if (res.statusCode != 200) return null;

    final json = jsonDecode(utf8.decode(res.bodyBytes));
    if (json is! Map) return null;

    final displayName = json['display_name'] as String? ?? '';
    final address = json['address'] as Map<String, dynamic>? ?? {};

    return EnderecoLegivel(
      enderecoCompleto: displayName,
      logradouro: address['road'] as String?,
      numero: address['house_number'] as String?,
      bairro: address['suburb'] as String? ?? address['neighbourhood'] as String?,
      cidade: address['city'] as String? ?? address['town'] as String? ?? address['municipality'] as String?,
      estado: address['state'] as String?,
    );
  }

  @visibleForTesting
  static void limparCache() => _cache.clear();
}
