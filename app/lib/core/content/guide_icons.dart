import 'package:flutter/material.dart';

import 'app_content.dart';

/// Ícone de linha de cada guia. Substitui os emojis que vinham do banco.
///
/// O banco guarda uma chave lógica em `guides.icon` (ex.: 'alerta'); o app
/// decide o desenho. Guias sem chave conhecida caem no ícone da categoria.
abstract final class GuideIcons {
  static const _porChave = <String, IconData>{
    'alerta': Icons.emergency_outlined,
    'bussola': Icons.explore_outlined,
    'documento': Icons.description_outlined,
    'escudo': Icons.shield_outlined,
    'balanca': Icons.balance_outlined,
    'carteira': Icons.account_balance_wallet_outlined,
    'celular': Icons.phonelink_lock_outlined,
  };

  /// Compatibilidade com bases antigas que ainda têm emoji em `icon`.
  static const _porSlug = <String, String>{
    'emergencia': 'alerta',
    'plano-de-seguranca': 'bussola',
    'boletim-de-ocorrencia': 'documento',
    'medida-protetiva': 'escudo',
    'lei-maria-da-penha': 'balanca',
    'apoio-financeiro': 'carteira',
    'seguranca-digital': 'celular',
  };

  static const _porCategoria = <String, IconData>{
    'emergencia': Icons.emergency_outlined,
    'seguranca': Icons.shield_outlined,
    'direitos': Icons.balance_outlined,
    'financeiro': Icons.account_balance_wallet_outlined,
  };

  static IconData de(Guide guia) =>
      _porChave[guia.icon] ??
      _porChave[_porSlug[guia.slug]] ??
      _porCategoria[guia.category] ??
      Icons.menu_book_outlined;
}
