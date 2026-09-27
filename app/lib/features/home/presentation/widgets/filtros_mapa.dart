import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/pressable.dart';
import '../../../support_network/domain/models/support_institution.dart';
import '../../../support_network/presentation/pages/support_network_page.dart';

/// Filtros do mapa da Home. Imutável: cada mudança cria um novo valor.
@immutable
class FiltroMapa {
  const FiltroMapa({
    this.categoria = 'todos',
    this.soProximos = true,
    this.quantidade = 5,
    this.so24h = false,
  });

  /// Id de [SupportNetworkPage.categoriasFiltro].
  final String categoria;

  /// Mostrar só os [quantidade] locais mais perto da usuária.
  final bool soProximos;
  final int quantidade;
  final bool so24h;

  static const opcoesQuantidade = [3, 5, 10];

  /// Quantos filtros da folha "Filtros" estão diferentes do padrão.
  int get extrasAtivos => (categoria != 'todos' ? 1 : 0) + (so24h ? 1 : 0);

  FiltroMapa copyWith({String? categoria, bool? soProximos, int? quantidade, bool? so24h}) => FiltroMapa(
        categoria: categoria ?? this.categoria,
        soProximos: soProximos ?? this.soProximos,
        quantidade: quantidade ?? this.quantidade,
        so24h: so24h ?? this.so24h,
      );

  /// Aplica os filtros. "Mais próximos" só vale se houver posição.
  List<SupportInstitution> aplicar(List<SupportInstitution> todas, {Position? posicao}) {
    final categorias = SupportNetworkPage.categoriasFiltro
        .firstWhere((c) => c.id == categoria, orElse: () => SupportNetworkPage.categoriasFiltro.first)
        .categorias;
    var lista = todas.where((i) {
      if (categorias.isNotEmpty && !categorias.contains(i.category)) return false;
      if (so24h && !i.is24Hours) return false;
      return true;
    }).toList();

    if (soProximos && posicao != null) {
      double distancia(SupportInstitution i) {
        if (i.latitude == null || i.longitude == null) return double.infinity;
        return Geolocator.distanceBetween(posicao.latitude, posicao.longitude, i.latitude!, i.longitude!);
      }

      lista.sort((a, b) => distancia(a).compareTo(distancia(b)));
      lista = lista.take(quantidade).toList();
    }
    return lista;
  }
}

/// Dois botões acima do mapa: "Mais próximos" (liga/desliga) e "Filtros".
class BarraFiltrosMapa extends StatelessWidget {
  const BarraFiltrosMapa({
    required this.filtro,
    required this.temPosicao,
    required this.onProximos,
    required this.onFiltros,
    this.carregandoLocalizacao = false,
    super.key,
  });

  final FiltroMapa filtro;
  final bool temPosicao;
  final VoidCallback onProximos;
  final VoidCallback onFiltros;
  final bool carregandoLocalizacao;

  @override
  Widget build(BuildContext context) {
    final extras = filtro.extrasAtivos;
    final nomeCategoria = SupportNetworkPage.categoriasFiltro
        .firstWhere((c) => c.id == filtro.categoria, orElse: () => SupportNetworkPage.categoriasFiltro.first)
        .label;
    return Row(
      children: [
        _Pilula(
          icone: Icons.near_me_outlined,
          rotulo: 'Mais próximos',
          ativo: filtro.soProximos && temPosicao,
          carregando: carregandoLocalizacao,
          onTap: onProximos,
        ),
        const SizedBox(width: AppSpacing.xs),
        _Pilula(
          icone: Icons.tune_rounded,
          rotulo: extras == 0 ? 'Filtros' : (filtro.categoria != 'todos' ? nomeCategoria : 'Filtros'),
          contador: extras,
          ativo: extras > 0,
          onTap: onFiltros,
        ),
      ],
    );
  }
}

class _Pilula extends StatelessWidget {
  const _Pilula({
    required this.icone,
    required this.rotulo,
    required this.ativo,
    required this.onTap,
    this.contador = 0,
    this.carregando = false,
  });

  final IconData icone;
  final String rotulo;
  final bool ativo;
  final VoidCallback onTap;
  final int contador;
  final bool carregando;

  @override
  Widget build(BuildContext context) {
    final corTexto = ativo ? AppColors.paper : AppColors.textPrimary;
    return Semantics(
      button: true,
      toggled: ativo,
      label: contador > 0 ? '$rotulo, $contador filtros ativos' : rotulo,
      child: ExcludeSemantics(
        child: Pressable(
          onTap: carregando ? null : onTap,
          child: AnimatedContainer(
            duration: AppShape.medio,
            curve: AppShape.curva,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: ativo ? AppColors.ink : AppColors.paper,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ativo ? AppColors.ink : AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (carregando)
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: corTexto),
                  )
                else
                  Icon(icone, size: 18, color: corTexto),
                const SizedBox(width: 8),
                Text(rotulo, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: corTexto)),
                if (contador > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(color: AppColors.wine, shape: BoxShape.circle),
                    child: Text(
                      '$contador',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Folha "Filtros": tipo de atendimento, quantidade e 24 horas.
/// Devolve o novo filtro, ou `null` se a usuária fechar sem aplicar.
Future<FiltroMapa?> mostrarFolhaFiltros(BuildContext context, FiltroMapa atual) {
  return showModalBottomSheet<FiltroMapa>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.paper,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppShape.radiusLg)),
    ),
    builder: (_) => _FolhaFiltros(inicial: atual),
  );
}

class _FolhaFiltros extends StatefulWidget {
  const _FolhaFiltros({required this.inicial});

  final FiltroMapa inicial;

  @override
  State<_FolhaFiltros> createState() => _FolhaFiltrosState();
}

class _FolhaFiltrosState extends State<_FolhaFiltros> {
  late FiltroMapa _f = widget.inicial;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.screen, 0, AppSpacing.screen, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filtrar o mapa', style: AppFonts.serif(size: 24, peso: 600)),
            const SizedBox(height: AppSpacing.lg),
            Text('Tipo de atendimento', style: t.titleSmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            for (final c in SupportNetworkPage.categoriasFiltro)
              _OpcaoCategoria(
                icone: c.icon,
                rotulo: c.label,
                selecionada: _f.categoria == c.id,
                onTap: () => setState(() => _f = _f.copyWith(categoria: c.id)),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text('Em "Mais próximos", mostrar', style: t.titleSmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: AppColors.ink,
                selectedForegroundColor: AppColors.paper,
                minimumSize: const Size(0, 44),
              ),
              segments: [
                for (final q in FiltroMapa.opcoesQuantidade) ButtonSegment(value: q, label: Text('$q locais')),
              ],
              selected: {_f.quantidade},
              onSelectionChanged: (s) => setState(() => _f = _f.copyWith(quantidade: s.first)),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _f.so24h,
              activeTrackColor: AppColors.ink,
              title: const Text('Só atendimento 24 horas', style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text('Para quando precisar de ajuda agora, a qualquer hora.'),
              onChanged: (v) => setState(() => _f = _f.copyWith(so24h: v)),
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(
                      () => _f = FiltroMapa(soProximos: _f.soProximos, quantidade: _f.quantidade),
                    ),
                    style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52)),
                    child: const Text('Limpar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, _f),
                    style: FilledButton.styleFrom(minimumSize: const Size(0, 52)),
                    child: const Text('Ver no mapa'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OpcaoCategoria extends StatelessWidget {
  const _OpcaoCategoria({
    required this.icone,
    required this.rotulo,
    required this.selecionada,
    required this.onTap,
  });

  final IconData icone;
  final String rotulo;
  final bool selecionada;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selecionada,
      button: true,
      child: Pressable(
        onTap: onTap,
        escala: 0.99,
        child: AnimatedContainer(
          duration: AppShape.rapido,
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selecionada ? AppColors.inkSoft : Colors.transparent,
            borderRadius: BorderRadius.circular(AppShape.radiusSm),
            border: Border.all(color: selecionada ? AppColors.ink : AppColors.hairline),
          ),
          child: Row(
            children: [
              Icon(icone, size: 20, color: selecionada ? AppColors.ink : AppColors.textSecondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rotulo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selecionada ? FontWeight.w700 : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (selecionada) const Icon(Icons.check_rounded, size: 20, color: AppColors.ink),
            ],
          ),
        ),
      ),
    );
  }
}
