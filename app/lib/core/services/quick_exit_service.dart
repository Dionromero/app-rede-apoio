import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Saída rápida: some com o app na hora, sem confirmação.
///
/// - Android: fecha e tira o app da lista de recentes (a miniatura não
///   mostra a última tela). Ver MainActivity.kt, canal `rede_apoio/sistema`.
/// - Web: troca a página por uma pesquisa comum, na mesma aba.
/// - Outras plataformas: fecha o app, se o sistema permitir.
abstract final class QuickExitService {
  static const _canal = MethodChannel('rede_apoio/sistema');

  /// Página neutra aberta no navegador (mesma da landing page).
  static final paginaNeutra = Uri.parse('https://www.google.com/search?q=previs%C3%A3o+do+tempo+curitiba');

  static Future<void> sair() async {
    HapticFeedback.mediumImpact();
    if (kIsWeb) {
      await launchUrl(paginaNeutra, webOnlyWindowName: '_self');
      return;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _canal.invokeMethod<bool>('sair');
        return;
      } on PlatformException {
        // cai no fechamento padrão
      } on MissingPluginException {
        // idem
      }
    }
    await SystemNavigator.pop();
  }
}
