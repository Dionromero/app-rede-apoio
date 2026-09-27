import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Modo discreto: troca o ícone e o nome do app na tela inicial por um
/// disfarce ("Anotações", com ícone de bloco de notas).
///
/// Só existe no Android, onde a troca é feita com `activity-alias`
/// (ver AndroidManifest.xml e MainActivity.kt). A escolha fica no próprio
/// sistema: nada vai para o servidor.
abstract final class DiscreetModeService {
  static const _canal = MethodChannel('rede_apoio/modo_discreto');

  /// Nome que aparece na tela inicial com o modo discreto ligado.
  static const nomeDisfarce = 'Anotações';

  static bool get suportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> ativo() async {
    if (!suportado) return false;
    try {
      return await _canal.invokeMethod<bool>('ativo') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Liga ou desliga. Retorna `true` se o sistema aceitou a troca.
  static Future<bool> definir(bool ativar) async {
    if (!suportado) return false;
    try {
      return await _canal.invokeMethod<bool>('definir', {'ativo': ativar}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
