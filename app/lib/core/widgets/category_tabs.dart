import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Abas de categoria em texto, com um "marcador" que desliza até a
/// aba escolhida. Substitui as pílulas com borda (visual de template).
class CategoryTabs extends StatelessWidget {
  const CategoryTabs({
    required this.itens,
    required this.selecionado,
    required this.onSelecionar,
    this.sobreMapa = false,
    super.key,
  });

  /// Pares (id, rótulo).
  final List<(String, String)> itens;
  final String selecionado;
  final ValueChanged<String> onSelecionar;

  /// Estilo com fundo, para usar por cima do mapa.
  final bool sobreMapa;

  @override
  Widget build(BuildContext context) {
    final lista = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: sobreMapa ? 6 : 0),
      child: Row(
        children: [
          for (final (id, rotulo) in itens)
            _Aba(
              rotulo: rotulo,
              ativa: id == selecionado,
              sobreMapa: sobreMapa,
              onTap: () {
                if (id == selecionado) return;
                HapticFeedback.selectionClick();
                onSelecionar(id);
              },
            ),
        ],
      ),
    );

    if (!sobreMapa) return lista;
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.paper.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.hairline),
        boxShadow: const [BoxShadow(color: AppColors.shadow, blurRadius: 12, offset: Offset(0, 4))],
      ),
      alignment: Alignment.centerLeft,
      child: ClipRRect(borderRadius: BorderRadius.circular(22), child: lista),
    );
  }
}

class _Aba extends StatelessWidget {
  const _Aba({
    required this.rotulo,
    required this.ativa,
    required this.sobreMapa,
    required this.onTap,
  });

  final String rotulo;
  final bool ativa;
  final bool sobreMapa;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: ativa,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: AppShape.medio,
          curve: AppShape.curva,
          margin: EdgeInsets.symmetric(horizontal: sobreMapa ? 2 : 0, vertical: sobreMapa ? 5 : 0),
          padding: EdgeInsets.symmetric(horizontal: 14, vertical: sobreMapa ? 6 : 10),
          decoration: BoxDecoration(
            color: ativa && sobreMapa ? AppColors.textPrimary : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedDefaultTextStyle(
                duration: AppShape.medio,
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 14.5,
                  fontWeight: ativa ? FontWeight.w700 : FontWeight.w400,
                  color: ativa
                      ? (sobreMapa ? Colors.white : AppColors.textPrimary)
                      : AppColors.textSecondary,
                ),
                child: Text(rotulo),
              ),
              if (!sobreMapa) ...[
                const SizedBox(height: 6),
                // Curva sem "mola": largura animada não pode passar de 0 (fica negativa).
                AnimatedContainer(
                  duration: AppShape.medio,
                  curve: AppShape.curva,
                  height: 3,
                  width: ativa ? 22 : 0,
                  decoration: BoxDecoration(
                    color: AppColors.wine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
