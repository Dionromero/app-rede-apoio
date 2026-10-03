import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/app_config.dart';

/// Serviço auxiliar para integração com o Google Street View.
///
/// Permite à usuária reconhecer a fachada e a entrada do local antes de ir,
/// aumentando a sensação de segurança e reduzindo desorientação.
class StreetViewService {
  const StreetViewService._();

  /// Monta a URL da imagem estática da fachada via Google Street View Static API.
  /// Retorna `null` se não houver chave de API configurada.
  static String? urlImagemEstatica({
    required double latitude,
    required double longitude,
    int largura = 600,
    int altura = 320,
    int fov = 90,
    int heading = 0,
    int pitch = 0,
    String? chaveApi,
  }) {
    final chave = chaveApi ?? AppConfig.googleMapsApiKey;
    if (chave.isEmpty) return null;

    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    return 'https://maps.googleapis.com/maps/api/streetview'
        '?size=${largura}x$altura'
        '&location=$lat,$lng'
        '&fov=$fov'
        '&heading=$heading'
        '&pitch=$pitch'
        '&key=$chave';
  }

  /// Monta a URL universal do Google Maps para abrir a visão panorâmica 360°
  /// do Street View no ponto indicado.
  /// Funciona tanto no app nativo do Google Maps quanto no navegador, gratuitamente e sem chave.
  static String urlPanorama360({
    required double latitude,
    required double longitude,
  }) {
    final lat = latitude.toStringAsFixed(6);
    final lng = longitude.toStringAsFixed(6);
    return 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lng';
  }

  /// Abre a visão 360° do Street View no Google Maps ou navegador externo.
  static Future<bool> abrirNoStreetView({
    required double latitude,
    required double longitude,
  }) async {
    final urlStr = urlPanorama360(latitude: latitude, longitude: longitude);
    final uri = Uri.parse(urlStr);
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
