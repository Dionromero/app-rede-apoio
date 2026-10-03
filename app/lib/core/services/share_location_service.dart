import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'geocoding_service.dart';
import 'location_service.dart';

/// Serviço para compartilhar localização via WhatsApp ou SMS.
///
/// O app prepara a mensagem com link do Google Maps e abre o WhatsApp
/// ou SMS. O envio final é confirmado pela usuária no próprio app de
/// mensagens — o Sussurro não controla o envio.
class ShareLocationService {
  const ShareLocationService._();

  /// Envia a localização atual via WhatsApp para o número informado.
  ///
  /// [telefone] deve estar no formato internacional sem '+' (ex: '5511999998888').
  /// [nomeContato] é usado apenas para personalizar a mensagem.
  ///
  /// Retorna um [ShareResult] indicando o resultado da operação.
  static Future<ShareResult> enviarViaWhatsApp({
    required String telefone,
    String? nomeContato,
    required BuildContext context,
  }) async {
    final posicao = await LocationService.obterPosicaoAtual();

    if (posicao == null) {
      return ShareResult.semLocalizacao;
    }

    final endereco = await GeocodingService.obterEndereco(
      posicao.latitude,
      posicao.longitude,
    );

    final linkMaps = LocationService.gerarLinkMaps(
      posicao.latitude,
      posicao.longitude,
    );

    final mensagem = _montarMensagem(linkMaps, endereco: endereco?.resumo);
    final mensagemCodificada = Uri.encodeComponent(mensagem);

    // Tentar abrir WhatsApp com número específico
    final whatsappUri = Uri.parse(
      'https://wa.me/$telefone?text=$mensagemCodificada',
    );

    try {
      if (await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        return ShareResult.sucesso;
      }
    } catch (_) {
      // WhatsApp não disponível, tentar fallback
    }

    return ShareResult.whatsappIndisponivel;
  }

  /// Envia a localização atual via SMS para o número informado.
  ///
  /// Usado como fallback quando o WhatsApp não está disponível.
  static Future<ShareResult> enviarViaSMS({
    required String telefone,
  }) async {
    final posicao = await LocationService.obterPosicaoAtual();

    if (posicao == null) {
      return ShareResult.semLocalizacao;
    }

    final endereco = await GeocodingService.obterEndereco(
      posicao.latitude,
      posicao.longitude,
    );

    final linkMaps = LocationService.gerarLinkMaps(
      posicao.latitude,
      posicao.longitude,
    );

    final mensagem = _montarMensagem(linkMaps, endereco: endereco?.resumo);
    final mensagemCodificada = Uri.encodeComponent(mensagem);

    final smsUri = Uri.parse('sms:$telefone?body=$mensagemCodificada');

    try {
      if (await launchUrl(smsUri)) {
        return ShareResult.sucesso;
      }
    } catch (_) {
      // SMS não disponível
    }

    return ShareResult.falhaGeral;
  }

  /// Tenta enviar via WhatsApp; se indisponível, tenta SMS.
  static Future<ShareResult> enviarComFallback({
    required String telefone,
    String? nomeContato,
    required BuildContext context,
  }) async {
    final resultado = await enviarViaWhatsApp(
      telefone: telefone,
      nomeContato: nomeContato,
      context: context,
    );

    if (resultado == ShareResult.whatsappIndisponivel) {
      return enviarViaSMS(telefone: telefone);
    }

    return resultado;
  }

  /// Abre o WhatsApp sem número definido (seletor de contatos).
  ///
  /// Útil quando não há contato de confiança cadastrado.
  static Future<ShareResult> enviarParaQualquerContato() async {
    final posicao = await LocationService.obterPosicaoAtual();

    if (posicao == null) {
      return ShareResult.semLocalizacao;
    }

    final endereco = await GeocodingService.obterEndereco(
      posicao.latitude,
      posicao.longitude,
    );

    final linkMaps = LocationService.gerarLinkMaps(
      posicao.latitude,
      posicao.longitude,
    );

    final mensagem = _montarMensagem(linkMaps, endereco: endereco?.resumo);
    final mensagemCodificada = Uri.encodeComponent(mensagem);

    final whatsappUri = Uri.parse(
      'https://wa.me/?text=$mensagemCodificada',
    );

    try {
      if (await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        return ShareResult.sucesso;
      }
    } catch (_) {
      // WhatsApp não disponível
    }

    return ShareResult.whatsappIndisponivel;
  }

  /// Obtém a posição e monta a mensagem. `null` se não houver localização.
  static Future<String?> prepararMensagem() async {
    final posicao = await LocationService.obterPosicaoAtual();
    if (posicao == null) return null;
    final endereco = await GeocodingService.obterEndereco(
      posicao.latitude,
      posicao.longitude,
    );
    return _montarMensagem(
      LocationService.gerarLinkMaps(posicao.latitude, posicao.longitude),
      endereco: endereco?.resumo,
    );
  }

  /// Abre o WhatsApp com a [mensagem]. Com [telefone] (formato '5541999998888'),
  /// já abre a conversa com a pessoa; sem ele, abre o seletor de contatos.
  static Future<ShareResult> abrirWhatsApp(String mensagem, {String? telefone}) async {
    final uri = Uri.parse('https://wa.me/${telefone ?? ''}?text=${Uri.encodeComponent(mensagem)}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return ShareResult.sucesso;
    } catch (_) {}
    return ShareResult.whatsappIndisponivel;
  }

  /// Abre o app de SMS com a [mensagem] para um ou mais [telefones]
  /// (o Android aceita vários destinatários separados por vírgula).
  static Future<ShareResult> abrirSms(String mensagem, List<String> telefones) async {
    final destino = telefones.map((t) => '+${t.replaceAll(RegExp(r'\D'), '')}').join(',');
    final uri = Uri.parse('sms:$destino?body=${Uri.encodeComponent(mensagem)}');
    try {
      if (await launchUrl(uri)) return ShareResult.sucesso;
    } catch (_) {}
    return ShareResult.falhaGeral;
  }

  static String _montarMensagem(String linkMaps, {String? endereco}) {
    if (endereco != null && endereco.trim().isNotEmpty) {
      return 'Preciso de ajuda. Estou perto de:\n📍 $endereco\n\nMinha localização no mapa:\n$linkMaps';
    }
    return 'Preciso de ajuda. Minha localização atual:\n$linkMaps';
  }
}

/// Resultado da tentativa de compartilhamento.
enum ShareResult {
  /// Mensagem preparada e app de envio foi aberto.
  sucesso,

  /// Não foi possível obter a localização (GPS, permissão ou timeout).
  semLocalizacao,

  /// WhatsApp não instalado ou não pode ser aberto.
  whatsappIndisponivel,

  /// Nenhum meio de envio disponível.
  falhaGeral,
}
