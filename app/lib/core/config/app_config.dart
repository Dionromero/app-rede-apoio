/// Configurações do app que não são segredo.
///
/// Valores que mudam por ambiente vêm de `--dart-define`, por exemplo:
/// `flutter run --dart-define=TRACKING_PAGE_URL=https://seusite.org/acompanhar`
class AppConfig {
  const AppConfig._();

  /// Localidade do piloto. Usada para pedir canais e guias da cidade.
  static const estadoPadrao = 'PR';
  static const cidadePadrao = 'Curitiba';

  /// Endereço da página web em que a pessoa de confiança acompanha a
  /// localização. O token vai depois do `#`, para não aparecer em logs:
  /// `https://seusite.org/acompanhar#t=<viewer_token>`.
  ///
  /// Enquanto estiver vazio, o compartilhamento ao vivo fica desativado
  /// (o app não pode enviar um link que não abre).
  static const trackingPageUrl = String.fromEnvironment('TRACKING_PAGE_URL');

  static bool get compartilhamentoAoVivoDisponivel => trackingPageUrl.isNotEmpty;

  /// Chave da API do Google Maps (Street View, Geocoding, etc.).
  /// Passada via `--dart-define=GOOGLE_MAPS_API_KEY=...`.
  /// Sem a chave, o app oferece o Street View 360° diretamente via link universal.
  static const googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get temGoogleMapsApiKey => googleMapsApiKey.isNotEmpty;

  /// Raio máximo da busca "perto de você" (km). Se não houver nada dentro
  /// dele, o app mostra os locais mais próximos e avisa.
  static const raioBuscaKm = 20.0;

  /// Intervalo entre envios de posição durante o compartilhamento ao vivo.
  static const intervaloEnvioLocalizacao = Duration(seconds: 15);

  /// Durações oferecidas à usuária (minutos). O servidor aceita de 5 a 60.
  static const duracoesCompartilhamento = [15, 30, 60];
}
