import 'package:latlong2/latlong.dart' show LatLng;

/// Meio de transporte da rota calculada no app.
enum TravelMode {
  aPe('a_pe', 'A pé', 'walking'),
  carro('carro', 'Carro', 'driving'),
  onibus('onibus', 'Ônibus', 'transit');

  const TravelMode(this.api, this.rotulo, this.googleMaps);

  /// Valor enviado à função `route`.
  final String api;
  final String rotulo;

  /// Valor de `travelmode` no link do Google Maps (navegação externa).
  final String googleMaps;

  static TravelMode fromApi(String? v) =>
      TravelMode.values.firstWhere((m) => m.api == v, orElse: () => TravelMode.aPe);
}

/// Um passo da rota ("Vire à direita na Rua XV" ou "Pegue o ônibus 203").
class RouteStep {
  const RouteStep({
    required this.instrucao,
    required this.distanciaM,
    required this.duracaoS,
    this.via,
    this.linhaTransit,
    this.pontoEmbarque,
    this.pontoDesembarque,
    this.numParadas,
    this.isTransit = false,
  });

  final String instrucao;
  final int distanciaM;
  final int duracaoS;
  final String? via;
  final String? linhaTransit;
  final String? pontoEmbarque;
  final String? pontoDesembarque;
  final int? numParadas;
  final bool isTransit;

  factory RouteStep.fromJson(Map<String, dynamic> json) => RouteStep(
        instrucao: json['instrucao']?.toString() ?? '',
        distanciaM: (json['distancia_m'] as num?)?.round() ?? 0,
        duracaoS: (json['duracao_s'] as num?)?.round() ?? 0,
        via: json['via']?.toString(),
        linhaTransit: json['linha_transit']?.toString(),
        pontoEmbarque: json['ponto_embarque']?.toString(),
        pontoDesembarque: json['ponto_desembarque']?.toString(),
        numParadas: (json['num_paradas'] as num?)?.round(),
        isTransit: json['is_transit'] == true,
      );
}

/// Rota calculada pela função `route` (OpenRouteService).
class RoutePlan {
  const RoutePlan({
    required this.modo,
    required this.distanciaM,
    required this.duracaoS,
    required this.pontos,
    required this.passos,
    this.atribuicao = '© openrouteservice.org · © OpenStreetMap contributors',
  });

  final TravelMode modo;
  final int distanciaM;
  final int duracaoS;
  final List<LatLng> pontos;
  final List<RouteStep> passos;
  final String atribuicao;

  factory RoutePlan.fromJson(Map<String, dynamic> json) {
    final geometria = (json['geometria'] as List? ?? const [])
        .map((p) => p as List)
        .where((p) => p.length >= 2)
        .map((p) => LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()))
        .toList();
    final passos = (json['passos'] as List? ?? const [])
        .map((p) => RouteStep.fromJson(Map<String, dynamic>.from(p as Map)))
        .where((p) => p.instrucao.isNotEmpty)
        .toList();
    return RoutePlan(
      modo: TravelMode.fromApi(json['modo']?.toString()),
      distanciaM: (json['distancia_m'] as num?)?.round() ?? 0,
      duracaoS: (json['duracao_s'] as num?)?.round() ?? 0,
      pontos: geometria,
      passos: passos,
      atribuicao: json['atribuicao']?.toString() ??
          '© openrouteservice.org · © OpenStreetMap contributors',
    );
  }

  /// "8 min", "1 h 05 min".
  static String formatarDuracao(int segundos) {
    final minutos = (segundos / 60).round();
    if (minutos < 1) return 'menos de 1 min';
    if (minutos < 60) return '$minutos min';
    final h = minutos ~/ 60;
    final m = minutos % 60;
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')} min';
  }

  /// "450 m", "3,4 km".
  static String formatarDistancia(int metros) {
    if (metros < 1000) return '${(metros / 10).round() * 10} m';
    final km = metros / 1000;
    return '${km.toStringAsFixed(km < 10 ? 1 : 0).replaceAll('.', ',')} km';
  }

  String get duracaoFormatada => formatarDuracao(duracaoS);
  String get distanciaFormatada => formatarDistancia(distanciaM);

  /// Horário estimado de chegada, a partir de [agora].
  String chegadaPrevista([DateTime? agora]) {
    final t = (agora ?? DateTime.now()).add(Duration(seconds: duracaoS));
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}
