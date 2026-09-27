import 'package:geolocator/geolocator.dart';

/// Serviço de localização responsável por obter coordenadas GPS.
///
/// Gerencia permissões, verifica disponibilidade do serviço de localização
/// e trata erros de GPS, bateria e permissões conforme exigido pelo projeto.
class LocationService {
  const LocationService._();

  /// Verifica se o serviço de localização está ativo e se as permissões
  /// foram concedidas. Retorna uma mensagem de erro ou `null` se tudo OK.
  static Future<String?> verificarPermissoes() async {
    try {
      // Verificar se o serviço de localização está ativo
      final servicoAtivo = await Geolocator.isLocationServiceEnabled();
      if (!servicoAtivo) {
        return 'O serviço de localização está desligado. '
            'Ative-o nas configurações do dispositivo.';
      }

      // Verificar permissão
      var permissao = await Geolocator.checkPermission();
      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
        if (permissao == LocationPermission.denied) {
          return 'A permissão de localização foi negada. '
              'Você pode permitir nas configurações.';
        }
      }

      if (permissao == LocationPermission.deniedForever) {
        return 'A permissão de localização foi bloqueada permanentemente. '
            'Acesse as configurações do aparelho para permitir.';
      }

      return null; // Tudo OK
    } catch (_) {
      return 'Serviço de localização indisponível.';
    }
  }

  /// Obtém a posição atual do dispositivo.
  ///
  /// Retorna `null` se não for possível obter a localização.
  /// Trata timeout e erros silenciosamente (o chamador deve oferecer
  /// alternativa à usuária).
  static Future<Position?> obterPosicaoAtual() async {
    final erro = await verificarPermissoes();
    if (erro != null) return null;

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // Timeout, GPS indisponível, etc.
      return null;
    }
  }

  /// Obtém a posição SOMENTE se a permissão já foi concedida antes.
  ///
  /// Não abre o pedido de permissão: use em telas que carregam sozinhas
  /// (ex.: mapa da Home). O pedido fica para quando a usuária tocar em
  /// "usar minha localização" ([obterPosicaoAtual]).
  static Future<Position?> obterPosicaoSeJaPermitido() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permissao = await Geolocator.checkPermission();
      if (permissao != LocationPermission.always &&
          permissao != LocationPermission.whileInUse) {
        return null;
      }
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Acima desta margem de erro (metros) a posição é tratada como aproximada:
  /// o mapa mostra o aviso e oferece "Ajustar no mapa". Acontece no
  /// navegador do computador (posição estimada por Wi-Fi ou IP) e com GPS
  /// fraco em ambientes fechados.
  static const precisaoAceitavelM = 300.0;

  static bool ehAproximada(Position p) => p.accuracy > precisaoAceitavelM;

  /// Posição escolhida pela usuária tocando no mapa (margem de erro zero).
  /// Fica só na memória do app, como a posição do GPS.
  static Position posicaoEscolhida(double latitude, double longitude) => Position(
        latitude: latitude,
        longitude: longitude,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );

  /// "±80 m", "±1,2 km", "±15 km".
  static String formatarPrecisao(double metros) {
    if (metros < 1000) return '±${(metros / 10).round() * 10} m';
    if (metros < 10000) return '±${(metros / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
    return '±${(metros / 1000).round()} km';
  }

  /// Gera a URL do Google Maps com as coordenadas fornecidas.
  static String gerarLinkMaps(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }
}
