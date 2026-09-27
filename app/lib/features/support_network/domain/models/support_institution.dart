import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/text_normalizer.dart';

/// Representa um ponto de atendimento da rede de apoio (Delegacia, CRAS, CREAS, etc.).
class SupportInstitution {
  const SupportInstitution({
    required this.id,
    required this.name,
    required this.category,
    this.externalKey,
    this.subcategory,
    required this.address,
    this.district,
    required this.city,
    required this.state,
    this.zipCode,
    this.phone,
    this.phone2,
    this.email,
    this.website,
    this.openingHours,
    this.latitude,
    this.longitude,
    this.services = const [],
    this.targetAudience,
    this.verifiedAt,
    this.sourceName,
    this.sourceUrl,
    this.locationPrecision = 'exata',
    this.distanceKm,
  });

  final String id;
  final String? externalKey;
  final String name;
  final String category;
  final String? subcategory;
  final String address;
  final String? district;
  final String city;
  final String state;
  final String? zipCode;
  final String? phone;
  final String? phone2;
  final String? email;
  final String? website;
  final Map<String, dynamic>? openingHours;
  final double? latitude;
  final double? longitude;
  final List<String> services;
  final String? targetAudience;
  final DateTime? verifiedAt;
  final String? sourceName;
  final String? sourceUrl;

  /// 'exata' ou 'aproximada'. Coordenadas aproximadas não devem guiar rotas.
  final String locationPrecision;
  final double? distanceKm;

  /// Dias sem verificação a partir dos quais o dado é tratado como desatualizado.
  static const diasValidadeVerificacao = 180;

  /// Nomes legíveis dos serviços cadastrados no banco.
  static const _servicoLabels = {
    'acolhimento': 'Acolhimento',
    'atendimento_psicossocial': 'Apoio psicossocial',
    'atendimento_psicologico': 'Atendimento psicológico',
    'orientacao_juridica': 'Orientação jurídica',
    'defensoria_publica': 'Defensoria Pública',
    'juizado_violencia_domestica': 'Juizado de Violência Doméstica',
    'ministerio_publico': 'Ministério Público',
    'patrulha_maria_da_penha': 'Patrulha Maria da Penha',
    'alojamento_temporario': 'Alojamento temporário',
    'autonomia_economica': 'Autonomia econômica',
    'brinquedoteca': 'Brinquedoteca',
    'boletim_ocorrencia': 'Boletim de ocorrência',
    'medida_protetiva': 'Medida protetiva',
    'violencia_domestica': 'Violência doméstica',
    'violencia_sexual': 'Violência sexual',
    'atendimento_violencia_sexual': 'Atendimento a violência sexual',
    'atendimento_vitimas_violencia': 'Atendimento a vítimas de violência',
    'atendimento_infantil': 'Atendimento infantil',
    'urgencia': 'Urgência',
    'protecao_crianca_adolescente': 'Proteção à criança e ao adolescente',
    'crimes_ciberneticos': 'Crimes cibernéticos',
    'importunacao_sexual_online': 'Importunação sexual on-line',
    'cadastro_unico': 'CadÚnico',
    'beneficios_sociais': 'Benefícios sociais',
    'acompanhamento_familiar': 'Acompanhamento familiar',
    'encaminhamento_rede': 'Encaminhamento para a rede',
    'acompanhamento_psicossocial': 'Acompanhamento psicossocial',
    'atendimento_24h': 'Atendimento 24 horas',
    'flagrante': 'Registro de flagrante',
  };

  static String labelServico(String servico) {
    final conhecido = _servicoLabels[servico];
    if (conhecido != null) return conhecido;
    final texto = servico.replaceAll('_', ' ');
    return texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
  }

  List<String> get servicesLabels => services.map(labelServico).toList();

  /// Nome amigável da categoria para exibição no aplicativo.
  String get categoryLabel {
    switch (category.toLowerCase()) {
      case 'delegacia_mulher':
        return 'Delegacia da Mulher';
      case 'delegacia':
      case 'delegacia_comum':
        return 'Delegacia de Polícia Civil';
      case 'creas':
        return 'CREAS (Atendimento Especializado)';
      case 'cras':
        return 'CRAS (Assistência Social)';
      case 'defensoria':
      case 'defensoria_publica':
        return 'Defensoria Pública';
      case 'centro_referencia':
        return 'Centro de Referência da Mulher';
      case 'hospital':
        return 'Hospital';
      case 'upa':
        return 'UPA — Pronto Atendimento 24h';
      case 'ministerio_publico':
        return 'Ministério Público';
      case 'forum':
        return 'Vara / Fórum';
      case 'ong':
        return 'Organização de apoio';
      default:
        return 'Rede de Proteção';
    }
  }

  /// Cor temática do tipo de instituição.
  Color get themeColor {
    switch (category.toLowerCase()) {
      case 'delegacia_mulher':
      case 'delegacia':
      case 'delegacia_comum':
        return AppColors.wine;
      case 'defensoria':
      case 'defensoria_publica':
      case 'ministerio_publico':
      case 'forum':
        return AppColors.ink;
      case 'creas':
      case 'cras':
      case 'centro_referencia':
      case 'ong':
        return AppColors.moss; // acolhimento
      case 'hospital':
      case 'upa':
        return AppColors.emergency;
      default:
        return AppColors.ink;
    }
  }

  /// Cor suave para fundos de ícone ou badges.
  Color get softThemeColor {
    switch (category.toLowerCase()) {
      case 'delegacia_mulher':
      case 'delegacia':
      case 'delegacia_comum':
        return AppColors.wineSoft;
      case 'defensoria':
      case 'defensoria_publica':
      case 'ministerio_publico':
      case 'forum':
        return AppColors.inkSoft;
      case 'creas':
      case 'cras':
      case 'centro_referencia':
      case 'ong':
        return AppColors.mossSoft;
      case 'hospital':
      case 'upa':
        return AppColors.wineSoft;
      default:
        return AppColors.inkSoft;
    }
  }

  /// Ícone representativo da instituição.
  IconData get icon {
    switch (category.toLowerCase()) {
      case 'delegacia_mulher':
      case 'delegacia':
      case 'delegacia_comum':
        return Icons.local_police_rounded;
      case 'defensoria':
      case 'defensoria_publica':
      case 'ministerio_publico':
      case 'forum':
        return Icons.gavel_rounded;
      case 'creas':
      case 'cras':
      case 'centro_referencia':
      case 'ong':
        return Icons.favorite_rounded;
      case 'hospital':
      case 'upa':
        return Icons.local_hospital_rounded;
      default:
        return Icons.business_rounded;
    }
  }

  /// Indica se a instituição funciona 24 horas em todos os dias informados.
  bool get is24Hours {
    final horarios = openingHours;
    if (horarios == null || horarios.isEmpty) return false;
    return horarios.values.every(
      (v) => v?.toString().toLowerCase().contains('24h') ?? false,
    );
  }

  /// Resumo legível do horário de funcionamento.
  String get formattedOpeningHours {
    const semHorario = 'Horário não informado — ligue antes';
    final horarios = openingHours;
    if (horarios == null || horarios.isEmpty) return semHorario;
    if (is24Hours) return 'Atendimento 24 horas';

    const dias = ['seg', 'ter', 'qua', 'qui', 'sex', 'sab', 'dom'];
    const nomes = {
      'seg': 'Seg',
      'ter': 'Ter',
      'qua': 'Qua',
      'qui': 'Qui',
      'sex': 'Sex',
      'sab': 'Sáb',
      'dom': 'Dom',
    };

    // Agrupa dias consecutivos com o mesmo horário: "Seg a Sex: 08:00-17:00".
    final partes = <String>[];
    String? inicio;
    String? fim;
    String? atual;

    void fechaGrupo() {
      if (inicio == null || atual == null) return;
      final faixa = inicio == fim ? nomes[inicio]! : '${nomes[inicio]} a ${nomes[fim]}';
      partes.add('$faixa: $atual');
    }

    for (final dia in dias) {
      final valor = horarios[dia]?.toString();
      if (valor == null || valor.isEmpty) {
        fechaGrupo();
        inicio = null;
        atual = null;
      } else if (valor == atual) {
        fim = dia;
      } else {
        fechaGrupo();
        inicio = dia;
        fim = dia;
        atual = valor;
      }
    }
    fechaGrupo();

    return partes.isEmpty ? semHorario : partes.join(' • ');
  }

  /// Formata a distância para exibição (ex: "450 m" ou "2.3 km").
  String? get formattedDistance {
    if (distanceKm == null) return null;
    if (distanceKm! < 1.0) {
      final metros = (distanceKm! * 1000).round();
      return '$metros m';
    }
    return '${distanceKm!.toStringAsFixed(1)} km';
  }

  bool get hasApproximateLocation => locationPrecision == 'aproximada';

  /// O dado foi conferido com a fonte oficial dentro do prazo de validade.
  bool isVerified([DateTime? agora]) {
    final data = verifiedAt;
    if (data == null) return false;
    final referencia = agora ?? DateTime.now();
    return referencia.difference(data).inDays <= diasValidadeVerificacao;
  }

  /// Texto do selo de confiabilidade exibido no card e nos detalhes.
  String verificationLabel([DateTime? agora]) {
    final data = verifiedAt;
    if (data == null) return 'Dados a confirmar — ligue antes de ir';
    final local = data.toLocal();
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final texto = 'Verificado em $dd/$mm/${local.year}';
    return isVerified(agora) ? texto : '$texto — pode estar desatualizado';
  }

  /// Texto normalizado usado pela busca offline (mesmos campos do servidor).
  String get searchText => normalizarTexto([
        name,
        category,
        category.replaceAll('_', ' '),
        subcategory,
        address,
        district,
        city,
        targetAudience,
        services.join(' ').replaceAll('_', ' '),
        servicesLabels.join(' '),
        categoryLabel,
      ].whereType<String>().join(' '));

  /// Todos os termos precisam aparecer (mesma regra da RPC search_institutions).
  bool matchesTerms(List<String> termos) {
    if (termos.isEmpty) return true;
    final texto = searchText;
    return termos.every(texto.contains);
  }

  factory SupportInstitution.fromSupabase(Map<String, dynamic> json) {
    List<String> parsedServices = [];
    if (json['services'] is List) {
      parsedServices = (json['services'] as List).map((e) => e.toString()).toList();
    }

    Map<String, dynamic>? parsedHours;
    if (json['opening_hours'] is Map) {
      parsedHours = Map<String, dynamic>.from(json['opening_hours'] as Map);
    }

    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString());
    }

    String? parseString(dynamic value) {
      final texto = value?.toString().trim();
      return (texto == null || texto.isEmpty) ? null : texto;
    }

    return SupportInstitution(
      id: json['id']?.toString() ?? '',
      externalKey: parseString(json['external_key']),
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      subcategory: parseString(json['subcategory']),
      address: json['address']?.toString() ?? '',
      district: parseString(json['district']),
      city: json['city']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      zipCode: parseString(json['zip_code']),
      phone: parseString(json['phone']),
      phone2: parseString(json['phone2']),
      email: parseString(json['email']),
      website: parseString(json['website']),
      openingHours: parsedHours,
      latitude: parseDouble(json['latitude']),
      longitude: parseDouble(json['longitude']),
      services: parsedServices,
      targetAudience: parseString(json['target_audience']),
      verifiedAt: json['verified_at'] != null
          ? DateTime.tryParse(json['verified_at'].toString())
          : null,
      sourceName: parseString(json['source_name']),
      sourceUrl: parseString(json['source_url']),
      locationPrecision: parseString(json['location_precision']) ?? 'exata',
      distanceKm: parseDouble(json['distance_km']),
    );
  }
}
