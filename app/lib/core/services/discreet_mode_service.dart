import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Um ícone possível para o app na tela inicial.
@immutable
class Disfarce {
  const Disfarce({required this.atalho, required this.nome, required this.imagem});

  /// Nome do activity-alias no AndroidManifest.xml.
  final String atalho;

  /// Nome que aparece embaixo do ícone na tela inicial.
  final String nome;
  final String imagem;

  bool get ehPadrao => atalho == DiscreetModeService.padrao.atalho;
}

/// Modo discreto: troca o ícone e o nome do app na tela inicial por um
/// disfarce comum (calculadora, anotações, treinos, receitas).
///
/// Só existe no Android, onde a troca é feita com `activity-alias`
/// (ver AndroidManifest.xml e MainActivity.kt). A escolha fica no próprio
/// sistema: nada vai para o servidor.
abstract final class DiscreetModeService {
  static const _canal = MethodChannel('rede_apoio/modo_discreto');

  static const padrao = Disfarce(
    atalho: 'AtalhoPadrao',
    nome: 'Sussurro',
    imagem: 'assets/brand/icone-192.png',
  );

  /// Opções de disfarce, na ordem em que aparecem na tela.
  static const disfarces = [
    Disfarce(atalho: 'AtalhoCalculadora', nome: 'Calculadora', imagem: 'assets/brand/icone-calculadora-192.png'),
    Disfarce(atalho: 'AtalhoDiscreto', nome: 'Anotações', imagem: 'assets/brand/icone-discreto-192.png'),
    Disfarce(atalho: 'AtalhoTreinos', nome: 'Treinos', imagem: 'assets/brand/icone-treinos-192.png'),
    Disfarce(atalho: 'AtalhoReceitas', nome: 'Receitas', imagem: 'assets/brand/icone-receitas-192.png'),
  ];

  static const todos = [padrao, ...disfarces];

  static bool get suportado => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Disfarce porAtalho(String? atalho) =>
      todos.firstWhere((d) => d.atalho == atalho, orElse: () => padrao);

  /// Ícone em uso agora.
  static Future<Disfarce> atual() async {
    if (!suportado) return padrao;
    try {
      return porAtalho(await _canal.invokeMethod<String>('atual'));
    } on PlatformException {
      return padrao;
    } on MissingPluginException {
      return padrao;
    }
  }

  /// Troca o ícone. Retorna `true` se o sistema aceitou.
  static Future<bool> definir(Disfarce disfarce) async {
    if (!suportado) return false;
    try {
      return await _canal.invokeMethod<bool>('definir', {'atalho': disfarce.atalho}) ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
