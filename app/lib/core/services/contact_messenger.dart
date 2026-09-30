import 'package:url_launcher/url_launcher.dart';

/// Abre WhatsApp ou SMS com uma mensagem pronta para um número.
///
/// O envio final é SEMPRE confirmado pela usuária no app de mensagens:
/// o Sussurro não envia nada sozinho.
class ContactMessenger {
  const ContactMessenger._();

  /// [numero] só com dígitos e DDI (ex.: '5541999998888').
  static Future<bool> abrirWhatsApp(String numero, String mensagem) async {
    final uri = Uri.parse('https://wa.me/$numero?text=${Uri.encodeComponent(mensagem)}');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  /// [numero] com ou sem '+' (ex.: '+5541999998888').
  static Future<bool> abrirSms(String numero, String mensagem) async {
    final uri = Uri(scheme: 'sms', path: numero, queryParameters: {'body': mensagem});
    try {
      return await launchUrl(uri);
    } catch (_) {
      return false;
    }
  }

  /// Tenta WhatsApp e, se não abrir, SMS.
  static Future<bool> abrirWhatsAppOuSms({
    required String numeroDigitos,
    required String mensagem,
  }) async {
    if (await abrirWhatsApp(numeroDigitos, mensagem)) return true;
    return abrirSms('+$numeroDigitos', mensagem);
  }

  static String mensagemLocalizacaoAtual(double latitude, double longitude) =>
      'Preciso de ajuda. Minha localização agora:\n'
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  static String mensagemAcompanhamento(String link, int minutos) =>
      'Preciso de ajuda. Estou compartilhando minha localização com você '
      'pelos próximos $minutos minutos:\n$link';
}
